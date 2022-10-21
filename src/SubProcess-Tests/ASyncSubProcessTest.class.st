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

{ #category : #tests }
ASyncSubProcessTest >> testRunningBasicCommand [
	| out |
	
	self isRunningOnWindows ifTrue: [ self skip: 'skipping unix test'].

	process := SPSProcessConfiguration new
		command: '/bin/ls';
		async.
	
	process run.
	
	"self assert: process isComplete.
	self assert: process isSuccess.
	self assert: process isExitCodeSuccess.
	self assert: process stdErr isEmpty."
	out := process stdOutChannel readLine.
	self deny: out isEmpty.

]
