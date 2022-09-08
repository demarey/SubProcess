Class {
	#name : #SyncSubProcessTest,
	#superclass : #TestCase,
	#instVars : [
		'process'
	],
	#category : #'SubProcess-Tests'
}

{ #category : #configuring }
SyncSubProcessTest >> listDirectoryCommand [

	^ OSPlatform current isWindows 
		ifTrue: [ 'dir' ]
		ifFalse: [ '/bin/ls' ]
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
	
	process := SPSProcess new
		command: self listDirectoryCommand.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process stdErr isEmpty.
	self deny: process stdOut isEmpty.

]

{ #category : #tests }
SyncSubProcessTest >> testRunningCommandInGivenWorkingDirectory [
	
	| dir |
	dir := Smalltalk imagePath asFileReference parent / 'pharo-local'.
	process := SPSProcess new
		workingDirectory: dir;
		command: self listDirectoryCommand.
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process exitCode equals: 0.
	self assert: process stdErr isEmpty.
	self assert: (process stdOut includesSubstring: 'ombu-sessions').

]
