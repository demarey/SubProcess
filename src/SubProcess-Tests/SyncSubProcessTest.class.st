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
	
	process := SPSProcess new
		command: 'non_exisiting_command';
		arguments: #('foo' 'bar').
	
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
	process := SPSProcess new
		command: '/bin/ls'.
	
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
	process := SPSProcess new
		command: 'C:\Windows\System32\processinfo.exe'.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process stdErr isEmpty.
	self deny: process stdOut isEmpty.
	output := process stdOut decodeWith: 'cp-850'.
	self assert: (output includesSubstring: 'Microsoft Windows').
]

{ #category : #tests }
SyncSubProcessTest >> testRunningCommandInGivenWorkingDirectory [
	
	| dir |
	dir := Smalltalk imagePath asFileReference parent / 'pharo-local'.
	process := SPSProcess new
		workingDirectory: dir;
		command: '/bin/ls'.
	OSPlatform current isWindows 
		ifTrue: [ process
						command: self windowsShellCommand;
						arguments: #('dir') ]	.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process exitCode equals: 0.
	self assert: process stdErr isEmpty.
	self assert: (process stdOut includesSubstring: 'ombu-sessions').

]

{ #category : #accessing }
SyncSubProcessTest >> windowsShellCommand [

	^ 'C:\Windows\System32\cmd.exe'
]
