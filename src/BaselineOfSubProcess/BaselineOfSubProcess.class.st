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
			spec baseline: 'Glib' with: [ 
				spec 
					repository: 'github://pharo-spec/gtk-bindings/src';
					loads: 'GIO-standalone' ].
		
			spec
				package: 'SubProcess';
				package: 'SubProcess-Tests' with: [ spec requires: #('SubProcess' 'Glib') ];
				group: 'default' with: #('SubProcess-Tests').
		].
]
