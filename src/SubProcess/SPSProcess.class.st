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
		'workingDirectory',
		'encoding'
	],
	#pools : [
		'GSpawnFlags'
	],
	#category : #SubProcess
}

{ #category : #'api - configuring' }
SPSProcess >> addArgument: aString [ 
	
	arguments 
		ifNil: [ arguments := OrderedCollection with: aString ]
		ifNotNil: [ arguments add: aString ]
]

{ #category : #'api - configuring' }
SPSProcess >> addArguments: aCollection [ 
	
	arguments 
		ifNil: [ arguments := OrderedCollection withAll: aCollection ]
		ifNotNil: [ arguments addAll: aCollection ]
]

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

{ #category : #'api - configuring' }
SPSProcess >> encoding: anEncoding [
	"anEncoding will be used to decode the received Strings, using a specified encoding.
	anEncoding is either a ZnCharacterEncoder instance or an identifier for one."

	encoding := anEncoding
]

{ #category : #'api - accessing' }
SPSProcess >> error [

	^ error
]

{ #category : #private }
SPSProcess >> errorMessage: message errorCode: errorCode domainString: domainString [ 
	
	error := SPSError
		message: (message decodeWith: encoding)
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

{ #category : #initialization }
SPSProcess >> initialize [

	super initialize.
	"This is just a default encoding. Especially on windows, you could need to set the correct encoding"
	encoding := OSPlatform current isWindows
		ifTrue: [ 'cp-850' ]
		ifFalse: [ 'utf8' ].
	 
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
SPSProcess >> stdErr: aByteArray [ 
	
	stdErr := aByteArray ifNotNil: [ aByteArray decodeWith: encoding ].
]

{ #category : #'api - accessing' }
SPSProcess >> stdOut [

	^ stdOut ifNil: [ '' ]
]

{ #category : #private }
SPSProcess >> stdOut: aByteArray [
	
	stdOut := aByteArray ifNotNil: [ aByteArray decodeWith: encoding ].
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
SPSProcess >> windowsShellCommand [

	command := 'C:\Windows\System32\cmd.exe'.
	arguments 
		ifNil: [ self addArgument: '/C' ]
		ifNotNil: [ arguments addFirst: '/C' ].
]

{ #category : #'api - configuring' }
SPSProcess >> workingDirectory: aFileReference [ 
	
	workingDirectory := aFileReference.
]
