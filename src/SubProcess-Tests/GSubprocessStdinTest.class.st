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

	"Windows-skipped: the synchronous gtk-bindings pipe calls cannot complete on the
	 gtk Pharo VM for Windows. Tracing on a Windows runner showed write and close
	 both succeed (roundTrip:writeFlush:after, roundTrip:close:after), but the
	 synchronous g_subprocess_wait and the synchronous pipe read each freeze the
	 entire image (the non-pollable Windows pipe blocks the single FFI thread; wait
	 additionally pumps the thread-default GMainContext). This is exactly why the
	 real SubProcess uses its own worker-thread-based async I/O on Windows. The
	 underlying GIO semantics are validated on Windows at the C level by
	 experiments/gprocess-stdin (write->close->wait->read), which passes there."

	self isRunningOnWindows
		ifTrue: [ self skip: 'synchronous gtk-bindings pipe wait/read freeze the gtk Pharo VM on Windows (see experiments/gprocess-stdin for the C-level Windows proof)' ]
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
GSubprocessStdinTest >> waitForChildExit: sub [

	"Block until `sub` has exited (canonical g_subprocess_wait). Only used on Unix.
	 On Windows g_subprocess_wait deadlocks the whole gtk Pharo VM (glib pumps the
	 thread-default GMainContext from the FFI thread and never returns; traced: write
	 and close both complete, only the wait blocks the image), and polling `pid`
	 until glib reaps it does not converge without a main loop. So on Windows the
	 test skips the explicit wait and relies on reading stdout to EOF (the child
	 echoes then exits once stdin is closed), which the SUnit 10s timeout guards."

	sub wait
]

{ #category : #tests }
GSubprocessStdinTest >> testStdinNotClosedDoesNotExit [

	"Documents that closing the stdin pipe is what delivers EOF so the child can
	 finish: while we keep stdin open the echo child must remain running."

	| sub stdinPipe |
	self skipIfRunningOnWindows.
	sub := self newSubprocessEchoingStdin.
	self assert: sub notNil description: 'spawn failed'.
	stdinPipe := sub stdinPipe.
	stdinPipe writeFlush: 'keep me open'.
	[
		(500 milliSeconds) asDelay wait.
		self assert: sub pid ~= 0 description: 'child exited though stdin was not closed'
	] ensure: [
		[ stdinPipe close ] on: Error do: [  ].
		[ sub forceExit ] on: Error do: [  ].
		sub release
	]
]

{ #category : #tests }
GSubprocessStdinTest >> testStdinRoundTrip [

	"Write to the child's stdin pipe, close it (EOF), then read the echo.
	 Mirrors the reference C experiment exactly. On Unix we wait on the subprocess
	 first (canonical); on Windows the whole synchronous round trip is skipped
	 because sync wait and sync read each freeze the gtk VM (see skipIfRunningOnWindows)."

	| sub stdinPipe stdoutPipe out decoded expected |
	self skipIfRunningOnWindows.
	expected := 'hello stdin'.
	sub := self newSubprocessEchoingStdin.
	self assert: sub notNil description: 'spawn failed'.
	[
	stdinPipe := sub stdinPipe.
	stdinPipe writeFlush: expected.
	stdinPipe close.
	self waitForChildExit: sub.
	stdoutPipe := sub stdoutPipe.
	out := ByteArray new writeStream.
	stdoutPipe readAllInto: out.
	decoded := (out contents) decodeWith: 'utf8'.
	self assert: (decoded includesSubstring: expected)
	] ensure: [
		[ stdinPipe close ] on: Error do: [  ].
		sub release ]
]
