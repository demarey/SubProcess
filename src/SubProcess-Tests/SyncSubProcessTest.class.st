Class {
	#name : #SyncSubProcessTest,
	#superclass : #TestCase,
	#instVars : [
		'process'
	],
	#category : #'SubProcess-Tests'
}

{ #category : #running }
SyncSubProcessTest >> tearDown [

	process ifNotNil: [ process terminate ].
	super tearDown.
]

{ #category : #tests }
SyncSubProcessTest >> testRunningANonExistingCommand [
	
	process := SPSProcess new
		command: '/foo/bar';
		arguments: #('/').
	
	self
		should: [ process run ]
		raise: SPSError.
	
	self assert: process isComplete.
	self deny: process isSuccess.
	self deny: process stdErr isEmpty.
	self assert: process stdOut isEmpty.
]

{ #category : #tests }
SyncSubProcessTest >> testRunningBasicCommand [
	
	process := SPSProcess new
		command: '/bin/ls';
		arguments: #('/').
	
	process run.
	
	self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process stdErr isEmpty.
	self deny: process stdOut isEmpty.
]
