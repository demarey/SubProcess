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

	"Windows-skipped: writing to / closing a GSubprocess stdin pipe through the
	 gtk-bindings on Windows blocks the entire VM (g_pollable_input_stream_can_poll
	 assertion fires; the call never returns even from a background worker). The
	 underlying GIO semantics are nonetheless proven on Windows by the reference C
	 experiment under experiments/gprocess-stdin, which passes there."

	self isRunningOnWindows
		ifTrue: [ self skip: 'gtk-bindings stdin pipes block the whole VM on Windows; see experiments/gprocess-stdin' ]
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

	"Write to the child's stdin pipe, close it (EOF), wait, then read the echo.
	 Mirrors the reference C experiment exactly."

	| sub stdinPipe stdoutPipe out decoded expected |
	self skipIfRunningOnWindows.
	expected := 'hello stdin'.
	sub := self newSubprocessEchoingStdin.
	self assert: sub notNil description: 'spawn failed'.
	[
		stdinPipe := sub stdinPipe.
		stdinPipe writeFlush: expected.
		stdinPipe close.
		sub wait.
		self assert: sub successful description: 'child did not exit successfully'.
		stdoutPipe := sub stdoutPipe.
		out := ByteArray new writeStream.
		stdoutPipe readAllInto: out.
		decoded := (out contents) decodeWith: 'utf8'.
		self assert: (decoded includesSubstring: expected)
	] ensure: [
		[ stdinPipe close ] on: Error do: [  ].
		sub release
	]
]
