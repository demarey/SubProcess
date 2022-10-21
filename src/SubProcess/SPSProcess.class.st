"
I allow to spawn child OS processes synchroneously. 
Execution will be blocked until the child process completion.

I use SPSProcessConfiguration to configure myself.
"
Class {
	#name : #SPSProcess,
	#superclass : #SPSAbstractProcess,
	#instVars : [
		'stdOut',
		'stdErr',
		'isSuccess',
		'error',
		'exitCode'
	],
	#pools : [
		'GSpawnFlags'
	],
	#category : #SubProcess
}

{ #category : #'api - accessing' }
SPSProcess >> error [

	^ error
]

{ #category : #private }
SPSProcess >> errorMessage: message errorCode: errorCode domainString: domainString [ 
	
	error := SPSError
		message: (message decodeWith: self configuration encoding)
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
SPSProcess >> isSuccess [
	
	^ isSuccess
]

{ #category : #'api - running' }
SPSProcess >> run [

	GIOSyncProcess
		spawn: self configuration command
		arguments: self configuration arguments
		workingDirectory: self configuration workingDirectory
		flags: G_SPAWN_DEFAULT
		processInfo: self.
		
	isComplete := true.
	self isSuccess ifFalse: [ self error signal ]
]

{ #category : #'api - accessing' }
SPSProcess >> stdErr [

	^ stdErr ifNil: [ '' ]
]

{ #category : #private }
SPSProcess >> stdErr: aByteArray [ 
	
	stdErr := aByteArray ifNotNil: [ aByteArray decodeWith: self configuration encoding ].
]

{ #category : #'api - accessing' }
SPSProcess >> stdOut [

	^ stdOut ifNil: [ '' ]
]

{ #category : #private }
SPSProcess >> stdOut: aByteArray [
	
	stdOut := aByteArray ifNotNil: [ aByteArray decodeWith: self configuration encoding ].
]

{ #category : #private }
SPSProcess >> success: aBoolean [ 

	isSuccess := aBoolean
]

{ #category : #'api - running' }
SPSProcess >> terminate [
	
	self notYetImplemented.
]
