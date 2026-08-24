"
I allow to spawn child OS processes asynchroneously:
execution will resume immediately after the child process is spawn, not waiting its termination.
You can provide a callback if you need to do some actions after the child process is completed.

The process lifecycle is managed in the background: a worker iterates the GLib default main
context so the child-watch callback is dispatched, recording the exit code and notifying
completion. Output can be read through the raw channels (streaming), consumed line-by-line
with a callback (`outputLineDo:`), and/or collected into `stdOut`/`stdErr` when auto-collection
is enabled. Before completion is announced, the output listeners are drained to EOF so the
collected output is complete.

I use `SPSProcessConfiguration` to configure myself.
"
Class {
	#name : #SPSAsyncProcess,
	#superclass : #SPSAbstractProcess,
	#instVars : [
		'process',
		'exitCode',
		'completionSemaphore',
		'drainSemaphore',
		'completionBlock',
		'outputLineBlock',
		'stdOutCollector',
		'stdErrCollector',
		'stdOutListener',
		'stdErrListener',
		'watchWorker',
		'wasTerminated',
		'processContext',
		'cleanupLock'
	],
	#pools : [
		'GSpawnFlags'
	],
	#category : #SubProcess
}

	{ #category : 'private - accessing' }
SPSAsyncProcess >> completionSemaphore [

	^ completionSemaphore ifNil: [ completionSemaphore := Semaphore new ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> shouldCollectOutput [

	^ self configuration shouldCollectOutput
]

	{ #category : 'private - output' }
SPSAsyncProcess >> configureOutputReading [

	self outputsBeingRead ifTrue: [ self startOutputListeners ]
]

	{ #category : 'private - accessing' }
SPSAsyncProcess >> drainSemaphore [

	^ drainSemaphore ifNil: [ drainSemaphore := Semaphore new ]
]

	{ #category : 'private - output' }
SPSAsyncProcess >> emitOutputLine: aLine [

	self outputLineBlock ifNotNil: [ self outputLineBlock value: aLine ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> exitCode [

	"Answer the exit code of the child process, or nil if the process has not
	 completed yet or did not exit normally."

	^ exitCode
]

	{ #category : 'private - lifecycle' }
SPSAsyncProcess >> ensureEngine [

	GEngine isRunning ifFalse: [ GEngine ensureRunning ]
]

	{ #category : 'private - output' }
SPSAsyncProcess >> installDrainWatches [

	"Each output listener signals the drain semaphore once it reaches EOF. We then wait
	 for these signals before closing the process so collected output is not truncated."

	drainSemaphore := Semaphore new.
	stdOutListener ifNotNil: [ stdOutListener whenTerminatedDo: [ self drainSemaphore signal ] ].
	stdErrListener ifNotNil: [ stdErrListener whenTerminatedDo: [ self drainSemaphore signal ] ]
]

{ #category : 'private - output' }
SPSAsyncProcess >> newOutputListener: aChannel collector: stdCollector [

	^ aChannel
		newReadLineListener: ('subprocess-output-{1}' format: { aChannel identityHash })
		action: [ :aLine |
			| lineWithoutTerminator |
			lineWithoutTerminator := self stripLineTerminator: aLine.
			stdCollector ifNotNil: [ stdCollector nextPutAll: lineWithoutTerminator; cr ].
			self emitOutputLine: lineWithoutTerminator ]
]

	{ #category : 'private - output' }
SPSAsyncProcess >> stripLineTerminator: aLine [

	"g_io_channel_read_line keeps the terminator, so remove any trailing CR/LF."

	| lineWithoutTerminator |
	lineWithoutTerminator := aLine.
	[ lineWithoutTerminator notEmpty and: [ (lineWithoutTerminator last = Character cr) or: [ lineWithoutTerminator last = Character lf ] ] ]
		whileTrue: [ lineWithoutTerminator := lineWithoutTerminator allButLast ].
	^ lineWithoutTerminator
]

	{ #category : 'private - lifecycle' }
SPSAsyncProcess >> announceCompleted [

	completionBlock ifNotNil: [ completionBlock value: self ]
]

{ #category : 'private - lifecycle' }
SPSAsyncProcess >> beCompleted: waitStatus [

	self cleanupLock critical: [
		self isComplete ifTrue: [ ^ self ].
		exitCode := GIOProcess decodeExitCodeFromWaitStatus: waitStatus.
		self finalizeCleanupDraining: true ].
	self announceCompleted
]

{ #category : 'private - lifecycle' }
SPSAsyncProcess >> cleanupLock [

	^ cleanupLock ifNil: [ cleanupLock := Mutex new ]
]

{ #category : 'private - lifecycle' }
SPSAsyncProcess >> finalizeCleanupDraining: shouldDrain [

	"Run exactly once, guarded by #cleanupLock, to stop output reading, detach the child watch
	 and close the process. Both #terminate and #beCompleted: funnel here so the cleanup never
	 runs concurrently: previously the two threads competed for the single drainSemaphore
	 (producing a spurious 'timed out while draining') and raced the one-shot child watch
	 (producing a GLib-CRITICAL 'Source ID ... was not found').
	 Output is drained (up to EOF) only on the normal-completion path; on #terminate the child
	 is killed and its remaining output is irrelevant, and waiting for EOF is unreliable on
	 Windows where the spawn helper holds the pipe write-ends."

	shouldDrain ifTrue: [ self outputsBeingRead ifTrue: [ self waitForOutputDrain ] ].
	self stopOutputListeners.
	process removeChildWatch.
	process close.
	completionSemaphore signal.
	isComplete := true
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> outputLineBlock [

	^ outputLineBlock
]

{ #category : #'api - configuring' }
SPSAsyncProcess >> outputLineDo: aBlock [

	"Evaluate aBlock with each output line (stdout and stderr) as it is produced, without
	 buffering the whole output. Useful for processes producing a large amount of output."

	outputLineBlock := aBlock.
	^ self
]

	{ #category : 'private - output' }
SPSAsyncProcess >> outputsBeingRead [

	^ self shouldCollectOutput or: [ self outputLineBlock notNil ]
]

{ #category : #'api - running' }
SPSAsyncProcess >> run [

	completionSemaphore := Semaphore new.
	process := GIOPipedProcess
		spawn: self configuration command
		arguments: self configuration arguments
		workingDirectory: (self configuration workingDirectory ifNotNil: [ :wd | wd fullName ])
		flags: G_SPAWN_DO_NOT_REAP_CHILD.
	self ensureEngine.
	processContext := GMainContext new.
	self configureOutputReading.
	self watchCompletion
]

{ #category : #'api - running' }
SPSAsyncProcess >> runAndWaitTimeOut: aDuration [

	"Run the process and wait at most aDuration for its completion.
	 Answer true if it timed out, false if it completed within the delay."

	| timedOut |
	self run.
	self completionSemaphore waitTimeoutMilliseconds: aDuration asMilliSeconds.
	timedOut := self isComplete not.
	timedOut ifTrue: [ self terminate ].
	^ timedOut
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdErr [

	^ stdErrCollector ifNil: [ '' ] ifNotNil: [ stdErrCollector contents ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdErrChannel [

	^ process errChannel
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdInChannel [

	^ process inChannel
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> pid [

	^ process pid
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdOut [

	^ stdOutCollector ifNil: [ '' ] ifNotNil: [ stdOutCollector contents ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdOutChannel [

	^ process outChannel
]

	{ #category : 'private - output' }
SPSAsyncProcess >> startOutputListeners [

	stdOutListener := self
		newOutputListener: self stdOutChannel
		collector: (self shouldCollectOutput
			ifTrue: [ stdOutCollector := WriteStream on: String new ]
			ifFalse: [ nil ]).
	stdErrListener := self
		newOutputListener: self stdErrChannel
		collector: (self shouldCollectOutput
			ifTrue: [ stdErrCollector := WriteStream on: String new ]
			ifFalse: [ nil ]).
	"Subscribe to the EOF announcements BEFORE starting the listeners, otherwise a fast
	 child may reach EOF and announce before we register, and the drain watch is missed."
	self installDrainWatches.
	stdOutListener start.
	stdErrListener start
]

	{ #category : 'private - output' }
SPSAsyncProcess >> stopOutputListeners [

	stdOutListener ifNotNil: [ stdOutListener stop. stdOutListener := nil ].
	stdErrListener ifNotNil: [ stdErrListener stop. stdErrListener := nil ]
]

{ #category : #'api - running' }
SPSAsyncProcess >> terminate [

	self cleanupLock critical: [
		self isComplete ifTrue: [ ^ self ].
		wasTerminated := true.
		SPSProcessControl terminatePid: process pid.
		self finalizeCleanupDraining: false ].
	self announceCompleted
]

	{ #category : 'private - output' }
SPSAsyncProcess >> waitForOutputDrain [

	"Let the output listeners drain the remaining bytes (up to EOF) before we close the
	 process, so the collected/streamed output is not truncated. We use a FIXED timeout of
	 5 seconds per channel so a stuck child can never hang completion forever; if it expires
	 we give up draining and proceed. NOTE: Semaphore >> waitTimeoutMilliseconds: answers true
	 when the timeout expires, false on signal."

	2 timesRepeat: [
		(self drainSemaphore waitTimeoutMilliseconds: 5000)
			ifTrue: [ ^ self ] ]
]

{ #category : #'api - testing' }
SPSAsyncProcess >> isSpawnSuccess [

	"True if the child process was spawned/launched without error. Since a spawn failure makes
	 #run raise an error, this answers true as soon as the process exists (after a successful #run)."

	^ process notNil
]

{ #category : #'api - testing' }
SPSAsyncProcess >> wasTerminated [

	"True if the child program was killed on user request via #terminate (usually because of a
	 timeout). Answers the reason why the process finished, to be used along with #isComplete:
	 - isComplete = true and wasTerminated = false means the child exited by itself,
	 - isComplete = true and wasTerminated = true means it was killed by the caller."
	
	^ wasTerminated ifNil: [ false ]
]

{ #category : #'api - events' }
SPSAsyncProcess >> whenCompletedDo: aBlock [

	"When the process completes its execution, evaluate aBlock with the process as argument.
	 The process completes only once and supports a single subscriber: a later call replaces
	 the previously registered block."

	completionBlock := aBlock
]

	{ #category : 'private - lifecycle' }
SPSAsyncProcess >> watchCompletion [

	"Watch for child exit on the DEDICATED private GMainContext created in #run, iterated
	 only by this watchWorker.

	 Design decision: on Windows the child GPid is an OS process HANDLE and GLib's child
	 watch polls it through g_poll. The shared default context is also iterated concurrently
	 by other threads (e.g. the GTK main loop) and g_poll runs without the context lock, so
	 closing the handle (in #beCompleted or #terminate) while another thread is
	 mid-WaitForMultipleObjectsEx on it yields 'WaitForMultipleObjectsEx failed: the handle
	 is invalid' warnings. GLib's GSubprocess avoids this by attaching its child watch to a
	 single-threaded worker context (g_child_watch_source_new + g_source_attach, see
	 gio/gsubprocess.c); we mirror that with a per-process private context, and g_spawn_close_pid
	 stays in #beCompleted as GLib documents."

	process
		watch: [ :waitStatus | self beCompleted: waitStatus ]
		in: processContext.
	watchWorker := [
		[ self isComplete ]
			whileFalse: [
				processContext iteration: false.
				(1 milliSecond) asDelay wait ] ]
		forkAt: Processor userBackgroundPriority
		named: 'SubProcess-completion-watch'
]
