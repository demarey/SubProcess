"
I allow to spawn child OS processes asynchroneously: 
execution will resume immediately after the child process is spawn, not waiting its termination. 
You can provide a callback if you need to do some actions after the child process is completed.

I use `SPSProcessConfiguration` to configure myself.
"
Class {
	#name : #SPSAsyncProcess,
	#superclass : #SPSAbstractProcess,
	#instVars : [
		'process'
	],
	#pools : [
		'GSpawnFlags'
	],
	#category : #SubProcess
}

{ #category : #private }
SPSAsyncProcess >> beCompleted [

	isComplete := true.
	process close.
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> exitCode [

	self notYetImplemented
]

{ #category : #'api - running' }
SPSAsyncProcess >> run [

	process := GIOPipedProcess
		spawn: self configuration command
		arguments: self configuration arguments
		workingDirectory: self configuration workingDirectory
		flags: G_SPAWN_DEFAULT.
]

{ #category : #'api - running' }
SPSAsyncProcess >> runAndWaitTimeOut: aDuration [

	self notYetImplemented.
	
	"GLib.timeout_add_seconds(timeout_s, self._timeout_callback)"
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdErrChannel [

	^ process errChannel
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdInChannel [

	^ process inChannel
]

{ #category : #'api - accessing' }
SPSAsyncProcess >> stdOutChannel [

	^ process outChannel
]

{ #category : #'api - running' }
SPSAsyncProcess >> terminate [
	
	process close.
	self flag: 'TODO process kill'
]
