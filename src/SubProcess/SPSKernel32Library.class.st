Class {
	#name : 'SPSKernel32Library',
	#superclass : 'FFILibrary',
	#category : 'SubProcess'
}

{ #category : #'accessing - platform' }
SPSKernel32Library >> win32LibraryName [

	^ 'kernel32.dll'
]

{ #category : #'private - primitives' }
SPSKernel32Library >> waitForSingleObject: aHandle [

	"Non-blocking wait on a Windows process/event handle: answers immediately whether the
	 object is signalled. WAIT_OBJECT_0 (0) means the process has exited, WAIT_TIMEOUT (258)
	 means it is still running. Passed the process handle from GSubprocess>>getIdentifier on
	 Windows. Only meaningful on Windows."

	^ self ffiCall: #(long WaitForSingleObject (void *aHandle, long 0))
]
