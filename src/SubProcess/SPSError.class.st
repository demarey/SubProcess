"
Error that can be returned when SPSProcess run fails.
"
Class {
	#name : #SPSError,
	#superclass : #Error,
	#instVars : [
		'errorCode',
		'domainString'
	],
	#category : #SubProcess
}

{ #category : #'instance creation' }
SPSError class >> message: message code: errorCode domainString: domainString [ 

	^ self new
		messageText: message;
		code: errorCode;
		domainString: domainString 
]

{ #category : #accessing }
SPSError >> code: anInteger [ 
	
	errorCode := anInteger 
]

{ #category : #accessing }
SPSError >> domainString: aString [ 
	
	domainString := aString
]
