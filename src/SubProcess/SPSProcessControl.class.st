"
I terminate a spawned child OS process in a platform-appropriate way:
- SIGKILL on Unix,
- TerminateProcess (kernel32) on Windows.

Used by SPSAsyncProcess >> terminate.
"
Class {
	#name : 'SPSProcessControl',
	#superclass : 'Object',
	#category : #SubProcess
}

{ #category : 'library path' }
SPSProcessControl class >> ffiLibraryName [

	^ SPSKernel32Library
]

{ #category : 'terminating' }
SPSProcessControl class >> terminatePid: aPid [

	OSPlatform current isWindows
		ifTrue: [ self new terminateWindowsPid: aPid ]
		ifFalse: [ LibC uniqueInstance kill: aPid signal: 9 ]
]

{ #category : 'private' }
SPSProcessControl >> closeHandle: aHandle [

	^ self ffiCall: #(int CloseHandle(void *aHandle))
]

{ #category : 'library path' }
SPSProcessControl >> ffiLibraryName [

	^ SPSKernel32Library
]

{ #category : 'private' }
SPSProcessControl >> openProcessAccess: anAccess inherit: aBoolean pid: aPid [

	^ self ffiCall: #(void *OpenProcess(uint anAccess, uchar aBoolean, uint aPid))
]

{ #category : 'private' }
SPSProcessControl >> processTerminateAccess [

	^ 16r1
]

{ #category : 'private' }
SPSProcessControl >> terminateProcessHandle: aHandle exitCode: anExitCode [

	^ self ffiCall: #(int TerminateProcess(void *aHandle, uint anExitCode))
]

{ #category : 'private' }
SPSProcessControl >> terminateWindowsPid: aPid [

	| handle |
	handle := self openProcessAccess: self processTerminateAccess inherit: false pid: aPid.
	handle isNull ifTrue: [ ^ self ].
	[ self terminateProcessHandle: handle exitCode: 1 ]
		ensure: [ self closeHandle: handle ]
]
