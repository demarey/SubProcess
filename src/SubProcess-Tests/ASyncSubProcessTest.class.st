Class {
	#name : #ASyncSubProcessTest,
	#superclass : #TestCase,
	#instVars : [
		'process'
	],
	#category : #'SubProcess-Tests'
}

{ #category : #testing }
ASyncSubProcessTest >> isRunningOnWindows [

	^ OSPlatform current isWindows
]

{ #category : #running }
ASyncSubProcessTest >> tearDown [

	process ifNotNil: [ process terminate ].
	super tearDown.
]

{ #category : #'helpers - waiting' }
ASyncSubProcessTest >> waitForCompletionOf: anAsyncProcess [

	| deadline |
	deadline := DateAndTime now + 10 seconds.
	[ anAsyncProcess isComplete or: [ DateAndTime now > deadline ] ]
		whileFalse: [ (50 milliSeconds) asDelay wait ].
	^ anAsyncProcess isComplete
]

{ #category : #tests }
ASyncSubProcessTest >> testAutoCollectedOutput [
	| out |

	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	process := (SPSProcessConfiguration new
		command: '/bin/sh';
		arguments: #('-c' 'echo hello');
		async) collectOutput.
	
	process run.
	
	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process isExitCodeSuccess.
	out := process stdOut.
	self assert: (out includesSubstring: 'hello').
]

{ #category : #tests }
ASyncSubProcessTest >> testAutoCollectedLargeOutput [
	| out |

	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	process := (SPSProcessConfiguration new
		command: '/bin/sh';
		arguments: #('-c' 'seq 1 50000');
		async) collectOutput.

	process run.

	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process isExitCodeSuccess.
	out := process stdOut.
	self assert: (out occurrencesOf: Character cr) >= 50000.
	self assert: (out includesSubstring: '50000').
]

{ #category : #tests }
ASyncSubProcessTest >> testCompletion [
	
	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	process := SPSProcessConfiguration new
		command: '/bin/sh';
		arguments: #('-c' 'exit 42');
		async.
	
	process run.
	
	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process exitCode equals: 42.
	self deny: process isExitCodeSuccess.
]

{ #category : #tests }
ASyncSubProcessTest >> testCompletionCallback [
	| completed exit |
	
	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	completed := false.
	exit := nil.
	process := SPSProcessConfiguration new
		command: '/bin/sh';
		arguments: #('-c' 'exit 0');
		async.
	process whenCompletedDo: [ :aProcess |
		completed := true.
		exit := aProcess exitCode ].
	
	process run.
	
	self assert: (self waitForCompletionOf: process).
	self assert: completed.
	self assert: exit equals: 0.
]

{ #category : #tests }
ASyncSubProcessTest >> testRunningBasicCommand [
	| out |
	
	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].

	process := SPSProcessConfiguration new
		command: '/bin/ls';
		async.
	
	process run.
	
	out := process stdOutChannel readLine.
	self deny: out isEmpty.

]

{ #category : #tests }
ASyncSubProcessTest >> testStreamingOutputCallback [
	| lines deadline |

	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	lines := OrderedCollection new.
	process := SPSProcessConfiguration new
		command: '/bin/sh';
		arguments: #('-c' 'seq 1 10');
		async.
	process outputLineDo: [ :aLine | lines add: aLine ].

	process run.

	self assert: (self waitForCompletionOf: process).
	deadline := DateAndTime now + 5 seconds.
	[ lines size >= 10 or: [ DateAndTime now > deadline ] ]
		whileFalse: [ (20 milliSeconds) asDelay wait ].
	self assert: lines size >= 10.
	self assert: (lines includes: '10').
]

{ #category : #tests }
ASyncSubProcessTest >> testTerminate [

	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	process := SPSProcessConfiguration new
		command: '/bin/sleep';
		arguments: #('30');
		async.
	
	process run.
	self deny: process isComplete.
	process terminate.
	
	self assert: process isComplete.
	self assert: process wasTerminated.
]

{ #category : #tests }
ASyncSubProcessTest >> testTimeOut [

	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	process := SPSProcessConfiguration new
		command: '/bin/sleep';
		arguments: #('30');
		async.
	
	self assert: (process runAndWaitTimeOut: 1 second).
	self assert: process isComplete.
	self assert: process wasTerminated.
]
