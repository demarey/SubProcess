"
I allow to spawn child OS processes.
Child processes can be run 
- synchroneously: execution will be blocked until the child process completion) 
- or asynchroneously: execution will resume immediately after the child process is spawn, not waiting its termination. In this case, you can provide a callback if you need to do some actions after the child process is completed.
"
Class {
	#name : #SPSProcess,
	#superclass : #Object,
	#instVars : [
		'command',
		'arguments',
		'isComplete',
		'stdOut',
		'stdErr',
		'isSuccess',
		'error',
		'exitCode',
		'workingDirectory'
	],
	#pools : [
		'GSpawnFlags'
	],
	#category : #SubProcess
}

{ #category : #'api - accessing' }
SPSProcess >> arguments [

	^ arguments ifNil: #()
]

{ #category : #'api - configuring' }
SPSProcess >> arguments: aCollection [ 
	
	arguments := aCollection
]

{ #category : #'api - accessing' }
SPSProcess >> command [

	^ command
]

{ #category : #'api - configuring' }
SPSProcess >> command: aString [ 
	
	command := aString
]

{ #category : #'api - accessing' }
SPSProcess >> error [

	^ error
]

{ #category : #private }
SPSProcess >> errorMessage: message errorCode: errorCode domainString: domainString [ 
	
	error := SPSError
		message: message
		code: errorCode 
		domainString: domainString
		
]

{ #category : #'api - accessing' }
SPSProcess >> exitCode [

	^ exitCode
]

{ #category : #private }
SPSProcess >> exitCode: anInteger [

	exitCode := anInteger
	
	
]

{ #category : #'api - testing' }
SPSProcess >> isComplete [
	
	^ isComplete
]

{ #category : #'api - testing' }
SPSProcess >> isExitCodeSuccess [
	
	^ self exitCode = 0
]

{ #category : #'api - testing' }
SPSProcess >> isSuccess [
	
	^ isSuccess
]

{ #category : #'api - running' }
SPSProcess >> run [

	self runSync.
	self isSuccess ifFalse: [ self error signal ]
]

{ #category : #private }
SPSProcess >> runSync [

	GIOSyncProcess
		spawn: self command
		arguments: self arguments
		workingDirectory: workingDirectory
		flags: G_SPAWN_DEFAULT
		processInfo: self.
		
	isComplete := true.
]

{ #category : #'api - accessing' }
SPSProcess >> stdErr [

	^ stdErr ifNil: [ '' ]
]

{ #category : #private }
SPSProcess >> stdErr: aString [ 
	
	stdErr := aString
]

{ #category : #'api - accessing' }
SPSProcess >> stdOut [

	^ stdOut ifNil: [ '' ]
]

{ #category : #private }
SPSProcess >> stdOut: aString [ 
	
	stdOut := aString
]

{ #category : #private }
SPSProcess >> success: aBoolean [ 

	isSuccess := aBoolean
]

{ #category : #'api - running' }
SPSProcess >> terminate [
	
	self flag: 'TODO'
]

{ #category : #'api - configuring' }
SPSProcess >> workingDirectory: aFileReference [ 
	
	workingDirectory := aFileReference.
]
