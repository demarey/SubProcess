"
I am an FFI library wrapper for the Windows kernel32 library, used to forcefully terminate
a spawned child process (TerminateProcess). Only used on Windows.
"
Class {
	#name : 'SPSKernel32Library',
	#superclass : 'FFILibrary',
	#category : #SubProcess
}

{ #category : 'library path' }
SPSKernel32Library >> macLibraryName [

	^ 'kernel32'
]

{ #category : 'library path' }
SPSKernel32Library >> unix64LibraryName [

	"Not used on Unix; kernel32 is Windows-only."
	^ 'kernel32'
]

{ #category : 'library path' }
SPSKernel32Library >> win32LibraryName [

	^ FFIWindowsLibraryFinder findLibrary: 'kernel32.dll'
]
