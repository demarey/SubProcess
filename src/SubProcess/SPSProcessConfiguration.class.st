"
I represent a Process configuration.
You can configure:
- the encoding to decode process outputs
- the working directory
- the command itself
- and the command arguments
"
Class {
	#name : #SPSProcessConfiguration,
	#superclass : #Object,
	#instVars : [
		'command',
		'arguments',
		'workingDirectory',
		'encoding'
	],
	#pools : [
		'GSpawnFlags'
	],
	#category : #SubProcess
}

{ #category : #examples }
SPSProcessConfiguration class >> example [

	(self new
		command: '/bin/ls';
		sync) run
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> addArgument: aString [ 
	
	arguments 
		ifNil: [ arguments := OrderedCollection with: aString ]
		ifNotNil: [ arguments add: aString ]
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> addArguments: aCollection [ 
	
	arguments 
		ifNil: [ arguments := OrderedCollection withAll: aCollection ]
		ifNotNil: [ arguments addAll: aCollection ]
]

{ #category : #'api - accessing' }
SPSProcessConfiguration >> arguments [

	^ arguments ifNil: [ #() ]
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> arguments: aCollection [ 
	
	arguments := aCollection
]

{ #category : #'api - running' }
SPSProcessConfiguration >> async [

	^  SPSAsyncProcess withConfiguration: self
]

{ #category : #'api - accessing' }
SPSProcessConfiguration >> command [

	^ command
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> command: aString [ 
	
	command := aString
]

{ #category : #'api - accessing' }
SPSProcessConfiguration >> encoding [ 

	^ encoding
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> encoding: anEncoding [
	"anEncoding will be used to decode the received Strings, using a specified encoding.
	anEncoding is either a ZnCharacterEncoder instance or an identifier for one."

	encoding := anEncoding
]

{ #category : #initialization }
SPSProcessConfiguration >> initialize [

	super initialize.
	"This is just a default encoding. Especially on windows, you could need to set the correct encoding"
	encoding := OSPlatform current isWindows
		ifTrue: [ 'cp-850' ]
		ifFalse: [ 'utf8' ].
	 
]

{ #category : #'api - running' }
SPSProcessConfiguration >> sync [

	^  SPSProcess withConfiguration: self
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> windowsShellCommand [

	command := 'C:\Windows\System32\cmd.exe'.
	arguments 
		ifNil: [ self addArgument: '/C' ]
		ifNotNil: [ arguments addFirst: '/C' ].
]

{ #category : #'api - accessing' }
SPSProcessConfiguration >> workingDirectory [ 

	^ workingDirectory
]

{ #category : #'api - configuring' }
SPSProcessConfiguration >> workingDirectory: aFileReference [ 
	
	workingDirectory := aFileReference.
]
