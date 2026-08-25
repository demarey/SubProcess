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
SPSKernel32Library >> closeHandle: aHandle [

	^ self ffiCall: #(long CloseHandle (void *aHandle))
]

{ #category : #'private - primitives' }
SPSKernel32Library >> openProcess: desiredAccess processId: aPid [

	"Open an existing process object. Answers NULL (nil) if the process cannot be opened,
	 typically because it no longer exists."

	^ self ffiCall: #(void *OpenProcess (long desiredAccess, long 0, long aPid))
]

{ #category : #'private - primitives' }
SPSKernel32Library >> waitForSingleObject: aHandle [

	"Non-blocking wait on a Windows process/event handle: answers immediately whether the
	 object is signalled. WAIT_OBJECT_0 (0) means the process has exited, WAIT_TIMEOUT (258)
	 means it is still running. Passed the process handle from GSubprocess>>getIdentifier on
	 Windows. Only meaningful on Windows."

	^ self ffiCall: #(long WaitForSingleObject (void *aHandle, long 0))
]
