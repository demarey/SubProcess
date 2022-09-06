Class {
	#name : #BaselineOfSubProcess,
	#superclass : #BaselineOf,
	#category : #BaselineOfSubProcess
}

{ #category : #baselines }
BaselineOfSubProcess >> baseline: spec [
	<baseline>

	spec
		for: #common
		do: [ 
			spec baseline: 'GlibStandaloneEngine' with: [ 
				spec repository: 'github://pharo-spec/gtk-bindings/src' ].
		
			spec
				package: 'SubProcess';
				package: 'SubProcess-Tests' with: [ spec requires: #('SubProcess' 'GlibStandaloneEngine') ];
				group: 'default' with: #('SubProcess-Tests').
		].
]
