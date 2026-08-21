Extension { #name : 'LibC' }

{ #category : '*SubProcess' }
LibC >> kill: anIntegerPid signal: anIntegerSignal [

	^ self ffiCall: #(int kill(int anIntegerPid, int anIntegerSignal))
]
