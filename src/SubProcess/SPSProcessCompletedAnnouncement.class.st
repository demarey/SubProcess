"
I am announced when an asynchroneous child process completes its execution.
I carry the completed process.
"
Class {
	#name : #SPSProcessCompletedAnnouncement,
	#superclass : #Announcement,
	#instVars : [
		'process'
	],
	#category : #SubProcess
}

{ #category : #'instance creation' }
SPSProcessCompletedAnnouncement class >> process: aProcess [

	^ self new
		process: aProcess;
		yourself
]

{ #category : #accessing }
SPSProcessCompletedAnnouncement >> process [

	^ process
]

{ #category : #accessing }
SPSProcessCompletedAnnouncement >> process: aProcess [

	process := aProcess
]
