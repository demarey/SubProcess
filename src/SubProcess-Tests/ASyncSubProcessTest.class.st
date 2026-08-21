Class {
	#name : #ASyncSubProcessTest,
	#superclass : #TestCase,
	#instVars : [
		'process'
	],
	#category : #'SubProcess-Tests'
}

{ #category : #testing }
ASyncSubProcessTest >> skipIfRunningOnWindows [

	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test']
]

{ #category : #testing }
ASyncSubProcessTest >> isRunningOnWindows [

	^ OSPlatform current isWindows
]

{ #category : #running }
ASyncSubProcessTest >> tearDown [

	process ifNotNil: [ process terminate ].
	super tearDown.
]

{ #category : #'helpers - building' }
ASyncSubProcessTest >> newProcessConfigurationForDirectoryListing [

	"Answer a configuration producing a non-empty directory listing."

	self isRunningOnWindows
		ifTrue: [ ^ self newProcessConfigurationWithShellCommand: 'dir' ].
	^ SPSProcessConfiguration new
		command: '/bin/ls';
		arguments: #();
		yourself
]

{ #category : #'helpers - building' }
ASyncSubProcessTest >> newProcessConfigurationForLongRunningProcess [

	"Answer a configuration for a process that stays alive for a long time."

	self isRunningOnWindows
		ifTrue: [ ^ self newProcessConfigurationWithShellCommand: 'powershell -Command "Start-Sleep -Seconds 30"' ].
	^ SPSProcessConfiguration new
		command: '/bin/sleep';
		arguments: { '30' };
		yourself
]

{ #category : #'helpers - building' }
ASyncSubProcessTest >> newProcessConfigurationProducingLines: anInteger [

	"Answer a configuration emitting exactly anInteger lines of output."

	self isRunningOnWindows
		ifTrue: [ ^ self newProcessConfigurationWithShellCommand: ('for /L %i in (1,1,{1}) do @echo %i' format: { anInteger }) ].
	^ self newProcessConfigurationWithShellCommand: ('seq 1 {1}' format: { anInteger })
]

{ #category : #'helpers - building' }
ASyncSubProcessTest >> newProcessConfigurationWithShellCommand: anExpression [

	"Answer a configuration running anExpression through the platform's shell."

	| config |
	config := SPSProcessConfiguration new.
	self isRunningOnWindows
		ifTrue: [ config command: 'C:\Windows\System32\cmd.exe'; addArgument: '/C'; addArgument: anExpression ]
		ifFalse: [ config command: '/bin/sh'; arguments: { '-c'. anExpression } ].
	^ config
]

{ #category : #'helpers - waiting' }
ASyncSubProcessTest >> waitFor: aBlock within: aDuration [

	"Poll every 20ms until aBlock answers true or aDuration elapses.
	 Answer whether aBlock answered true before the deadline."

	| deadline |
	deadline := DateAndTime now + aDuration.
	[ aBlock value or: [ DateAndTime now > deadline ] ]
		whileFalse: [ (20 milliSeconds) asDelay wait ].
	^ aBlock value
]

{ #category : #'helpers - waiting' }
ASyncSubProcessTest >> waitForCompletionOf: anAsyncProcess [

	^ self waitFor: [ anAsyncProcess isComplete ] within: 10 seconds
]

{ #category : #tests }
ASyncSubProcessTest >> testAutoCollectedOutput [
	| out |

	process := (self newProcessConfigurationWithShellCommand: 'echo hello')
		collectsOutput;
		async.
	
	process run.
	
	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process isExitSuccess.
	out := process stdOut.
	self assert: (out includesSubstring: 'hello').
]

{ #category : #tests }
ASyncSubProcessTest >> testAutoCollectedLargeOutput [
	| out |

	self skipIfRunningOnWindows.
	process := (self newProcessConfigurationWithShellCommand: 'seq 1 50000')
		collectsOutput;
		async.

	process run.

	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process isExitSuccess.
	out := process stdOut.
	self assert: (out occurrencesOf: Character cr) >= 50000.
	self assert: (out includesSubstring: '50000').
]

{ #category : #tests }
ASyncSubProcessTest >> testCompletion [
	
	process := (self newProcessConfigurationWithShellCommand: 'exit 42') async.
	
	process run.
	
	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process exitCode equals: 42.
	self deny: process isExitSuccess.
]

{ #category : #tests }
ASyncSubProcessTest >> testCompletionCallback [
	| completed exit |
	
	completed := false.
	exit := nil.
	process := (self newProcessConfigurationWithShellCommand: 'exit 0') async.
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
	
	process := self newProcessConfigurationForDirectoryListing async.
	
	process run.
	
	out := process stdOutChannel readLine.
	self deny: out isEmpty.

]

{ #category : #tests }
ASyncSubProcessTest >> testStreamingOutputCallback [
	| lines |

	lines := OrderedCollection new.
	process := (self newProcessConfigurationProducingLines: 10) async.
	process outputLineDo: [ :aLine | lines add: aLine ].

	process run.

	self assert: (self waitForCompletionOf: process).
	self assert: (self waitFor: [ lines size >= 10 ] within: 5 seconds).
	self assert: (lines includes: '10').
]

{ #category : #tests }
ASyncSubProcessTest >> testTerminate [

	process := self newProcessConfigurationForLongRunningProcess async.
	
	process run.
	self deny: process isComplete.
	process terminate.
	
	self assert: process isComplete.
	self assert: process wasTerminated.
]

{ #category : #tests }
ASyncSubProcessTest >> testTimeOut [

	process := self newProcessConfigurationForLongRunningProcess async.
	
	self assert: (process runAndWaitTimeOut: 1 second).
	self assert: process isComplete.
	self assert: process wasTerminated.
]
