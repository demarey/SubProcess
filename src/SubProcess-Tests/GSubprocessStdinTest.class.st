Class {
	#name : #GSubprocessStdinTest,
	#superclass : #TestCase,
	#pools : [
		'GObjectTypes'
	],
	#category : #'SubProcess-Tests'
}

{ #category : #tests }
GSubprocessStdinTest >> skipIfRunningOnWindows [

	self isRunningOnWindows
		ifTrue: [ self skip: 'Windows gtk-bindings stdin pipe streams are not pollable; closing/terminating them blocks. See experiments/gprocess-stdin.' ]
]

{ #category : #helpers }
GSubprocessStdinTest >> isRunningOnWindows [

	^ OSPlatform current isWindows
]

{ #category : #helpers }
GSubprocessStdinTest >> echoChildArgumentSpec [

	"Answer {command. arguments} that echo stdin to stdout on any platform.
	 Mirrors the reference C experiment (experiments/gprocess-stdin) which stays
	 cross-platform by not depending on unix-only `cat`."

	self isRunningOnWindows
		ifTrue: [ ^ { 'C:\Windows\System32\cmd.exe'. { '/C'. 'more' } } ]
		ifFalse: [ ^ { '/bin/cat'. #() } ]
]

{ #category : #helpers }
GSubprocessStdinTest >> newSubprocessEchoingStdin [

	| launcher errorHolder sub spec command args |
	spec := self echoChildArgumentSpec.
	command := spec first.
	args := spec second.
	errorHolder := GErrorHolder new.
	launcher := GSubprocessLauncher newWithFlags: 0.
	launcher setStdinPipe; setStdoutPipe; setStderrPipe.
	sub := launcher
		spawn: command
		arguments: args
		error: errorHolder.
	launcher release.
	^ sub
]

{ #category : #helpers }
GSubprocessStdinTest >> runInBackgroundWithin: aDuration step: stepBlock do: aBlock [

	"Run aBlock in a background worker process. If the worker has not finished
	 before aDuration elapses, fail the test (so a stuck child cannot hang the
	 whole CI job for its default 30-minutes timeout). stepBlock answers a string
	 describing the furthest step reached, used only when reporting a timeout.
	 Pharo13's threaded FFI means a blocking FFI call only stalls this worker, not
	 the whole VM, so the test is guaranteed to complete."

	| deadline workerDone result |
	result := nil.
	workerDone := false.
	[
		[ result := aBlock value ]
			on: Exception
			do: [ :e | result := e ].
		workerDone := true
	] forkAt: Processor userBackgroundPriority.
	deadline := DateAndTime now + aDuration.
	[ workerDone or: [ DateAndTime now > deadline ] ]
		whileFalse: [ (100 milliSeconds) asDelay wait ].
	workerDone
		ifTrue: [
			(result isKindOf: Exception) ifTrue: [ result signal ] ifFalse: [ ^ result ] ]
		ifFalse: [
			self
				fail: 'GSubprocessStdinTest timed out after ' , aDuration asString
					, ' (furthest step: ' , (stepBlock value) , ') on '
					, OSPlatform current name ]
]

{ #category : #tests }
GSubprocessStdinTest >> testStdinNotClosedDoesNotExit [

	"Documents that closing the stdin pipe is what delivers EOF so the child can
	 finish: while we keep stdin open the echo child must remain running.
	 Kept unix-only: on Windows the non-pollable gtk-bindings pipe streams make the
	 close/terminate cleanup block, and the no-close semantics are already proven by
	 the cross-platform C experiment."

	self skipIfRunningOnWindows.
	self
		runInBackgroundWithin: 10 seconds
		step: [ 'spawned' ]
		do: [
			| sub stdinPipe |
			sub := self newSubprocessEchoingStdin.
			self assert: sub notNil description: 'spawn failed'.
			stdinPipe := sub stdinPipe.
			stdinPipe writeFlush: 'keep me open'.
			[ (500 milliSeconds) asDelay wait.
			self assert: sub pid ~= 0 description: 'child exited though stdin was not closed' ]
				ensure: [
					[ stdinPipe close ] on: Error do: [  ].
					[ sub forceExit ] on: Error do: [  ].
					sub release ] ]
]

{ #category : #tests }
GSubprocessStdinTest >> testStdinRoundTrip [

	"Write to the child's stdin pipe, close it (EOF), wait, then read the echo.
	 Mirrors the reference C experiment exactly. Runs on all platforms (the core
	 result); bounded so a Windows hang fails fast instead of stalling CI."

	| successful roundTripped |
	self
		runInBackgroundWithin: 20 seconds
		step: [ 'running' ]
		do: [
			| sub stdinPipe stdoutPipe out decoded |
			sub := self newSubprocessEchoingStdin.
			self assert: sub notNil description: 'spawn failed'.
			stdinPipe := sub stdinPipe.
			stdinPipe writeFlush: 'hello stdin'.
			stdinPipe close.
			sub wait.
			successful := sub successful.
			stdoutPipe := sub stdoutPipe.
			out := ByteArray new writeStream.
			stdoutPipe readAllInto: out.
			decoded := (out contents) decodeWith: 'utf8'.
			self assert: successful description: 'child did not exit successfully'.
			self
				assert: (decoded includesSubstring: 'hello stdin')
				description: 'stdout echo missing'.
			roundTripped := true.
			sub release ].
	self assert: roundTripped description: 'stdin round-trip did not complete'
]
