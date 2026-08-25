"
I allow to spawn child OS processes synchroneously. 
Execution will be blocked until the child process completion.

I use SPSProcessConfiguration to configure myself.
"
Class {
	#name : #SPSProcess,
	#superclass : #SPSAbstractProcess,
	#instVars : [
		'process',
		'stdOut',
		'stdErr',
		'isSpawnSuccess',
		'error',
		'exitCode'
	],
	#pools : [
		'GObjectTypes'
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
SPSProcess >> isSpawnSuccess [
	
	^ isSpawnSuccess
]

{ #category : #'api - running' }
SPSProcess >> run [

	| launcher errorHolder sub |
	errorHolder := GErrorHolder new.
	launcher := GSubprocessLauncher newWithFlags: 0.
	launcher setStdoutPipe; setStderrPipe.
	self configuration workingDirectory
		ifNotNil: [ :wd | launcher setCwd: wd fullName ].
	sub := launcher
		spawn: self configuration command
		arguments: self configuration arguments
		error: errorHolder.
	launcher release.
	sub ifNil: [
		isComplete := true.
		isSpawnSuccess := false.
		exitCode := nil.
		self installError: errorHolder.
		self error signal.
		^ self ].

	process := sub.
	isSpawnSuccess := true.
	self collectOutput.
	isComplete := true
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
SPSProcess >> isSpawnSuccess: aBoolean [ 

	isSpawnSuccess := aBoolean
]

{ #category : #private }
SPSProcess >> installError: errorHolder [
	| err h |
	h := ExternalAddress
		fromAddress: ((errorHolder instVarNamed: #data) unsignedLongLongAt: 1).
	err := GError fromHandle: h.
	[ self
		errorMessage: err messageString utf8Decoded
		errorCode: err code
		domainString: err domainString ]
		ensure: [ err free ]
]

{ #category : #private }
SPSProcess >> collectOutput [
	"Wait for completion, then read stdout and stderr to EOF. Reading after the child has
	 exited is safe (its write ends are closed, so we reach EOF without blocking forever) and
	 avoids forked readers that would contend for the single-threaded FFI."

	| outCollector errCollector |
	[ process wait ] on: Error do: [  ].
	outCollector := WriteStream on: ByteArray new.
	errCollector := WriteStream on: ByteArray new.
	[ process stdoutPipe readAllInto: outCollector ] on: Error do: [  ].
	[ process stderrPipe readAllInto: errCollector ] on: Error do: [  ].
	[ process stdoutPipe close ] on: Error do: [  ].
	[ process stderrPipe close ] on: Error do: [  ].
	self stdOut: outCollector contents.
	self stdErr: errCollector contents.
	exitCode := process exitStatus.
	[ process release ] on: Error do: [  ].
	process := nil
]

{ #category : #'api - running' }
SPSProcess >> terminate [
	
	self flag: 'TODO process kill'
]
