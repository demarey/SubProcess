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

{ #category : #'helpers - leak' }
ASyncSubProcessTest >> pidIsReaped: aPid [
	"Answers whether the child process identified by aPid has already been reaped (no zombie).
	 POSIX-only: a non-blocking waitpid answering -1 (ECHILD) means the process is gone/reaped."

	| status |
	status := FFIInt32 newBuffer.
	^ (LibC uniqueInstance waitpid: aPid status: status options: 1) == -1
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

	process := (self newProcessConfigurationProducingLines: 50000)
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

{ #category : #tests }
ASyncSubProcessTest >> testWriteToStdin [
	| text command |

	text := 'hello stdin'.
	command := self isRunningOnWindows
		ifTrue: [ 'more' ]
		ifFalse: [ 'cat' ].
	process := (self newProcessConfigurationWithShellCommand: command)
		collectsOutput;
		async.
	process run.
	process stdInChannel writeFlush: text.
	self isRunningOnWindows
		ifTrue: [ process stdInChannel writeFlush: (String with: (Character codePoint: 26)) ].
	process stdInChannel shutDown: true.

	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process isExitSuccess.
	self assert: (process stdOut includesSubstring: text).
]

{ #category : #tests }
ASyncSubProcessTest >> testWorkingDirectory [
	| dir invocation |

	dir := FileLocator temp / (self class name , '-test-' , UUID new asString).
	dir ensureCreateDirectory.
	[
		invocation := self isRunningOnWindows
			ifTrue: [ 'cd' ]
			ifFalse: [ 'pwd' ].
		process := (self newProcessConfigurationWithShellCommand: invocation)
			workingDirectory: dir;
			collectsOutput;
			async.
		process run.

		self assert: (self waitForCompletionOf: process).
		self assert: process isComplete.
		self assert: process isExitSuccess.
		self assert: (process stdOut includesSubstring: dir fullName)
	] ensure: [ dir ensureDeleteAll ]
]

{ #category : #tests }
ASyncSubProcessTest >> testShellPipe [
	| invocation |

	invocation := self isRunningOnWindows
		ifTrue: [ 'echo hello | findstr hello' ]
		ifFalse: [ 'echo hello | grep hello' ].
	process := (self newProcessConfigurationWithShellCommand: invocation)
		collectsOutput;
		async.
	process run.

	self assert: (self waitForCompletionOf: process).
	self assert: process isComplete.
	self assert: process isExitSuccess.
	self assert: (process stdOut includesSubstring: 'hello').
]

{ #category : #tests }
ASyncSubProcessTest >> testNonAsciiArgument [
	| dir config |

	self skipIfRunningOnWindows.
	dir := FileLocator temp / (self class name , '-éoï-' , UUID new asString).
	dir ensureCreateDirectory.
	[
		(dir / 'ok.txt') ensureCreateFile.
		self isRunningOnWindows
			ifTrue: [ config := self newProcessConfigurationWithShellCommand: 'dir /b "' , dir fullName , '"' ]
			ifFalse: [ config := SPSProcessConfiguration new
				command: '/bin/ls';
				arguments: { dir fullName } ].
		process := config collectsOutput; async.
		process run.

		self assert: (self waitForCompletionOf: process).
		self assert: process isComplete.
		self assert: process isExitSuccess.
		self assert: (process stdOut includesSubstring: 'ok.txt')
	] ensure: [ dir ensureDeleteAll ]
]

{ #category : #'tests - leak' }
ASyncSubProcessTest >> testAsyncLeavesNoZombie [
	| pid |

	self skipIfRunningOnWindows.
	process := (self newProcessConfigurationWithShellCommand: 'exit 0') async.
	process run.

	self assert: (self waitForCompletionOf: process).
	pid := process pid.
	self assert: (self pidIsReaped: pid).
]

{ #category : #'tests - leak' }
ASyncSubProcessTest >> testAsyncTerminateLeavesNoZombie [
	| pid |

	self skipIfRunningOnWindows.
	process := self newProcessConfigurationForLongRunningProcess async.
	process run.
	pid := process pid.
	process terminate.

	self assert: process isComplete.
	self assert: (self waitFor: [ self pidIsReaped: pid ] within: 5 seconds).
]

