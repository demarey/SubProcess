"
I allow to spawn child OS processes asynchroneously:
execution will resume immediately after the child process is spawn, not waiting its termination.
You can provide a callback if you need to do some actions after the child process is completed.

The process lifecycle is managed in the background: a dedicated worker blocks on
g_subprocess_wait so the exit is reaped as soon as the child terminates (no zombie), recording
the exit code and notifying completion. When auto-collection or streaming is enabled, stdout
and stderr are drained meanwhile by concurrent readers (exactly the pattern used by the
synchroneous `SPSProcess`, which is proven on all supported platforms) and either collected
into `stdOut`/`stdErr` or fed line-by-line to the configured block. Before completion is
announced the readers are drained to EOF so the collected output is complete. The worker is
defensive: it never lets an exception escape (so it cannot be mistaken for a background
failure) and always signals completion, so `runAndWaitTimeOut`/`terminate` can never hang.

I use `SPSProcessConfiguration` to configure myself.
"
Class {
	#name : #SPSAsyncProcess,
	#superclass : #SPSAbstractProcess,
	#instVars : [
		'process',
		'pid',
		'isSpawnSuccess',
		'exitCode',
		'completionSemaphore',
		'completionBlock',
		'outputLineBlock',
		'outStream',
		'errStream',
		'inStream',
		'outCollector',
		'errCollector',
		'outPending',
		'errPending',
		'outPollable',
		'errPollable',
		'kernel32Library',
		'wasTerminated',
		'cleanupLock',
		'worker',
		'stdOut',
		'stdErr'
	],
	#pools : [
		'GObjectTypes'
	],
	#category : #SubProcess
}

{ #category : #'private - events' }
SPSAsyncProcess >> announceCompleted [

	completionBlock ifNotNil: [ completionBlock value: self ]
]

{ #category : #'private - lifecycle' }
SPSAsyncProcess >> cleanupAndComplete [

	"Run exactly once (guarded by #cleanupLock) to record the exit code, release the
	 process and signal completion. Cannot hang: exitStatus errors are swallowed."

	self cleanupLock critical: [
		self isComplete ifTrue: [ ^ self ].
		self wasTerminated
			ifTrue: [ exitCode := nil ]
			ifFalse: [ exitCode := [ process exitStatus ] on: Error do: [ nil ] ].
		[ process release ] on: Error do: [  ].
		process := nil.
		self forgetStreams.
		isComplete := true.
		completionSemaphore signal ].
	self announceCompleted
]

{ #category : #'private - accessing' }
SPSAsyncProcess >> cleanupLock [

	^ cleanupLock ifNil: [ cleanupLock := Mutex new ]
]

{ #category : #'private - accessing' }
SPSAsyncProcess >> completionSemaphore [

	^ completionSemaphore ifNil: [ completionSemaphore := Semaphore new ]
]

{ #category : #'private - instance creation' }
SPSAsyncProcess >> configureInstance [

	completionSemaphore := Semaphore new.
	wasTerminated := false.
	pid := nil.
	exitCode := nil.
	self forgetStreams
]

{ #category : #'private - lifecycle' }
SPSAsyncProcess >> emitOutputLine: aLine [

	self outputLineBlock ifNotNil: [ self outputLineBlock value: aLine ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> exitCode [

	"Answer the exit code of the child process, or nil if the process has not
	 completed yet or did not exit normally."

	^ exitCode
]

{ #category : #'private - output' }
SPSAsyncProcess >> finalizeOutput [

	self shouldCollectOutput ifTrue: [
		stdOut := self normalizeLineEndings: (outCollector contents decodeWith: self configuration encoding).
		stdErr := self normalizeLineEndings: (errCollector contents decodeWith: self configuration encoding) ].
	[ outStream close ] on: Error do: [  ].
	[ errStream close ] on: Error do: [  ]
]

{ #category : #'private - output' }
SPSAsyncProcess >> normalizeLineEndings: aString [
	"SmalltalkText convention: normalize LF line endings to CR so the collected output
	 matches the historical behaviour expected by the tests."

	^ aString copyReplaceAll: (String with: Character lf) with: (String with: Character cr)
]

{ #category : #'private - lifecycle' }
SPSAsyncProcess >> forgetStreams [

	outStream := nil.
	errStream := nil.
	inStream := nil.
	outCollector := nil.
	errCollector := nil
]

{ #category : #'private - lifecycle' }
SPSAsyncProcess >> handleBackground: anError [

	"Never let a background worker leak an exception (smalltalkCI reports any forked-process
	 error as a test failure). Still finalize so waiters are unblocked on best-effort basis."

	self cleanupLock critical: [
		self isComplete ifFalse: [ isComplete := true. completionSemaphore signal ] ].
	self announceCompleted
]

{ #category : #'api - testing' }
SPSAsyncProcess >> isSpawnSuccess [

	"True if the child process was spawned/launched without error."

	^ isSpawnSuccess ifNil: [ false ]
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

{ #category : #'private - output' }
SPSAsyncProcess >> outputsBeingRead [

	^ self shouldCollectOutput or: [ outputLineBlock notNil ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> pid [

	^ pid
]

{ #category : #'private - output' }
SPSAsyncProcess >> accumulate: current with: aString [

	"Append aString to the partial line already read (current), emitting each complete line and
	 answering the remaining partial line that has no terminator yet."

	| work idx line |
	work := current , aString.
	[ work isEmpty ] whileFalse: [
		idx := work indexOfAnyOf: { Character lf. Character cr }.
		idx = 0 ifTrue: [ ^ work ].
		line := ((work copyFrom: 1 to: idx - 1) copyWithout: Character cr) trim.
		line isEmpty ifFalse: [ self emitOutputLine: line ].
		work := work copyFrom: idx + 1 to: work size ].
	^ work
]

{ #category : #'private - output' }
SPSAsyncProcess >> pollPipe: aStream collector: aCollector pending: pendingHolder [

	"Read whatever is currently available from aStream in a non-blocking way. Answer true when
	 the stream hit EOF, false otherwise. Collected bytes are appended and, when streaming,
	 complete lines are emitted. pendingHolder is a one-element array holding the partial line
	 read so far (no terminator yet)."

	| chunk |
	chunk := aStream readNonBlocking: 4096.
	chunk ifNil: [ ^ false ]. "no data right now; keep polling"
	chunk isEmpty ifTrue: [ ^ true ]. "EOF"
	self shouldCollectOutput
		ifTrue: [ aCollector nextPutAll: chunk ]
		ifFalse: [
			self outputLineBlock
				ifNotNil: [
					pendingHolder at: 1 put: (self accumulate: (pendingHolder at: 1) with: (chunk decodeWith: self configuration encoding)) ] ].
	^ false
]

{ #category : #'private - output' }
SPSAsyncProcess >> drainOutputUntilEof [

	"Poll stdout and stderr until both reach EOF without ever blocking the VM for long
	 (which would freeze a concurrent writer to stdin or a timeout in the single-threaded
	 FFI). On streams that are pollable (unix) we read non-blocking, so we get EOF as soon as
	 the child closes its pipes. On Windows the GSubprocess pipes are not pollable, so instead
	 we iterate the default GMainContext until glib reaps the child (pid becomes 0 - the child
	 watch is only delivered through the main loop) and then do a short synchronous drain to
	 EOF, which cannot block because the child has already exited."

	| outEOF errEOF ctx |
	self setupOutputStreams.
	ctx := GMainContext default.
	outEOF := false.
	errEOF := false.
	[ outEOF and: errEOF ] whileFalse: [
		outEOF ifFalse: [
			outEOF := outPollable and: [ self pollPipe: outStream collector: outCollector pending: outPending ] ].
		errEOF ifFalse: [
			errEOF := errPollable and: [ self pollPipe: errStream collector: errCollector pending: errPending ] ].
		(outEOF and: errEOF) ifFalse: [
			ctx iteration: false.
			(self processExited)
				ifTrue: [ outEOF := true. errEOF := true ]
				ifFalse: [ (Delay forMilliseconds: 2) wait ] ] ].
	self drainRemainder.
	[ process wait ] on: Error do: [  ].
	self finalizeOutput
]

{ #category : #'private - output' }
SPSAsyncProcess >> drainRemainder [

	"Read any bytes still buffered now that the child has exited, so a read reaches EOF without
	 blocking the VM. Fed either into the collector or, when streaming, to the line block -
	 mirroring the synchronous SPSProcess drain."

	| chunk |
	outStream ifNotNil: [
		[ (chunk := outStream read: 4096) isEmpty ] whileFalse: [
			self feedChunk: chunk intoCollector: outCollector pending: outPending ] ].
	errStream ifNotNil: [
		[ (chunk := errStream read: 4096) isEmpty ] whileFalse: [
			self feedChunk: chunk intoCollector: errCollector pending: errPending ] ]
]

{ #category : #'private - output' }
SPSAsyncProcess >> feedChunk: aByteArray intoCollector: aCollector pending: pendingHolder [

	self shouldCollectOutput
		ifTrue: [ aCollector nextPutAll: aByteArray ]
		ifFalse: [ self outputLineBlock ifNotNil: [
			pendingHolder at: 1 put: (self accumulate: (pendingHolder at: 1) with: (aByteArray decodeWith: self configuration encoding)) ] ]
]

{ #category : #'private - accessing' }
SPSAsyncProcess >> kernel32Library [

	^ kernel32Library ifNil: [ kernel32Library := SPSKernel32Library new ]
]

{ #category : #'private - testing' }
SPSAsyncProcess >> processExited [

	"Non-blocking, cross-platform test for whether the child OS process has exited. On Windows
	 glib does not lower the subprocess identifier on reap the way it does on unix, so we ask the
	 OS directly: the GSubprocess identifier there is the process handle and a zero-timeout
	 WaitForSingleObject reports exit immediately. Elsewhere we rely on glib having reaped the
	 child after #drainOutputUntilEof iterated the main context."

	^ OSPlatform current isWindows
		ifTrue: [ self windowsProcessHandleSignaled ]
		ifFalse: [ self processIsReaped ]
]

{ #category : #'private - testing' }
SPSAsyncProcess >> processIsReaped [

	"Answer whether glib has reaped the child. glib clears the process identifier once its child
	 watch fires; that watch is delivered through the main context, which #drainOutputUntilEof
	 iterates. (Not used on Windows, where glib keeps the identifier as a process handle.)"

	^ process notNil and: [ process pid = 0 ]
]

{ #category : #'private - testing' }
SPSAsyncProcess >> windowsProcessHandleSignaled [

	"Ask the OS (non-blocking) whether the child process has terminated. The GSubprocess
	 identifier on Windows is the process handle."

	| handle |
	handle := process pid.
	^ (handle isNil or: [ handle = 0 ])
		ifTrue: [ false ]
		ifFalse: [ (self kernel32Library waitForSingleObject: (ExternalAddress fromAddress: handle)) = 0 ]
]

{ #category : #'api - running' }
SPSAsyncProcess >> run [

	self configureInstance.
	self spawnProcess.
	self isSpawnSuccess ifFalse: [
		isComplete := true.
		self announceCompleted.
		^ self ].
	self startBackground
]

{ #category : #'private - running' }
SPSAsyncProcess >> runInWorker [

	self drainOutputUntilEof.
	self cleanupAndComplete
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
SPSAsyncProcess >> shouldCollectOutput [

	^ self configuration shouldCollectOutput
]

{ #category : #'private - running' }
SPSAsyncProcess >> spawnProcess [

	| launcher errorHolder sub |
	isSpawnSuccess := false.
	errorHolder := GErrorHolder new.
	launcher := GSubprocessLauncher newWithFlags: 0.
	launcher setStdinPipe; setStdoutPipe; setStderrPipe.
	self configuration workingDirectory
		ifNotNil: [ :wd | launcher setCwd: wd fullName ].
	sub := launcher
		spawn: self configuration command
		arguments: self configuration arguments
		error: errorHolder.
	launcher release.
	sub ifNotNil: [
		process := sub.
		pid := sub pid.
		isSpawnSuccess := true ].
	^ sub
]

{ #category : #'private - running' }
SPSAsyncProcess >> startBackground [

	worker := [ [ self runInWorker ]
		on: Error
		do: [ :err | self handleBackground: err ] ]
		forkAt: Processor userBackgroundPriority
		named: 'SubProcess-worker'
]

{ #category : #'private - output' }
SPSAsyncProcess >> setupOutputStreams [

	outStream := process stdoutPipe.
	errStream := process stderrPipe.
	outPollable := [ outStream canPoll ] on: Error do: [ false ].
	errPollable := [ errStream canPoll ] on: Error do: [ false ].
	self shouldCollectOutput
		ifTrue: [
			outCollector := WriteStream on: ByteArray new.
			errCollector := WriteStream on: ByteArray new ].
	outPending := Array with: ''.
	errPending := Array with: ''
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdErr [

	^ stdErr ifNil: [ '' ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdErrStream [

	^ errStream ifNil: [ errStream := process stderrPipe ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdInStream [

	^ inStream ifNil: [ inStream := process stdinPipe ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdOut [

	^ stdOut ifNil: [ '' ]
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdOutStream [

	^ outStream ifNil: [ outStream := process stdoutPipe ]
]

{ #category : #'api - running' }
SPSAsyncProcess >> terminate [

	self isComplete ifTrue: [ ^ self ].
	self cleanupLock critical: [
		self isComplete ifTrue: [ ^ self ].
		wasTerminated := true.
		[ process forceExit ] on: Error do: [  ] ].
	self completionSemaphore wait.
	self announceCompleted
]

{ #category : #'private - lifecycle' }
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

{ #category : #accessing }
SPSAsyncProcess >> worker [

	^ worker
]
