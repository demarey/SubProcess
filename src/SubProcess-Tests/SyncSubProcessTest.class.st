Class {
	#name : #SyncSubProcessTest,
	#superclass : #TestCase,
	#instVars : [
		'process'
	],
	#category : #'SubProcess-Tests'
}

{ #category : #configuring }
SyncSubProcessTest >> isRunningOnWindows [

	^ OSPlatform current isWindows
]

{ #category : #running }
SyncSubProcessTest >> tearDown [

	process ifNotNil: [ process terminate ].
	super tearDown.
]

{ #category : #tests }
SyncSubProcessTest >> testRunningANonExistingCommand [
	
	process := SPSProcessConfiguration new
		command: 'non_exisiting_command';
		arguments: #('foo' 'bar');
		sync.
	
	self
		should: [ process run ]
		raise: SPSError
		withExceptionDo: [ :error |
			self 
				assert: (error messageText includesSubstring: 'No such file or directory')
				description: 'Expecting "No Such file ..." but got ', error messageText.
		].
	
	self assert: process isComplete.
	self deny: process isSuccess.
	self assert: process stdErr isEmpty.
	self assert: process stdOut isEmpty.
	self assert: process exitCode isNil
]

{ #category : #tests }
SyncSubProcessTest >> testRunningBasicCommand [
	
	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].
	process := SPSProcessConfiguration new
		command: '/bin/ls';
		sync.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process stdErr isEmpty.
	self deny: process stdOut isEmpty.

]

{ #category : #tests }
SyncSubProcessTest >> testRunningBasicCommandOnWindows [
	
	| output |
	
	self isRunningOnWindows ifFalse: [ self skip: 'skipping windows test'].
	process := SPSProcessConfiguration new
		command: 'C:\Windows\System32\systeminfo.exe';
		sync.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process stdErr isEmpty.
	self deny: process stdOut isEmpty.
	output := process stdOut.
	self assert: (output includesSubstring: 'Microsoft Windows').
]

{ #category : #tests }
SyncSubProcessTest >> testRunningCommandInGivenWorkingDirectory [
	
	| dir |
	dir := Smalltalk imagePath asFileReference parent / 'pharo-local'.
	process := SPSProcessConfiguration new
		workingDirectory: dir;
		command: '/bin/ls';
		sync.
	OSPlatform current isWindows 
		ifTrue: [ process
						windowsShellCommand;
						addArgument: 'dir' ]	.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process exitCode equals: 0.
	self assert: process stdErr isEmpty.
	self assert: (process stdOut includesSubstring: 'ombu-sessions').

]
