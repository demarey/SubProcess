"scratch-win-test/stdin_echo_ffi.st
================================================================================
Raw FFI port of scratch-win-test/gprocess_stdin.c (parent side).

Usage:
    <pharo> --headless <image> stdin_echo_ffi.st <echo-child-path>

It spawns <echo-child-path> --child-echo, writes the payload to the child's
stdin pipe, closes the stdin pipe (which delivers EOF), waits for the child
(g_subprocess_wait_check), reads all of the child's stdout, then asserts the
child echoed exactly the payload back, mirroring the C parent in
gprocess_stdin.c step by step.

Only raw libgio FFI calls (g_subprocess_*, g_output_stream_*, g_input_stream_*,
g_object_unref) are used. No gtk-bindings wrapper classes (GSubprocess /
GOutputStream / GInputStream) are referenced. We rely on the loaded Glib
baseline only for the library handle (GLibIOLibrary) and the GErrorHolder /
GError FFI plumbing.

Prints:
    PASS echo="<payload>" exit=<status>
or
    FAIL <reason> echo="<bytes>" exit=<status> successful=<0|1>
then a trailing marker line and quits the VM.

This file is a Pharo fileIn: code chunks are delimited by a "!" on its own
line, and each chunk is parsed/evaluated in order once the previous one has
run. That lets the class be created before its methods are compiled.
================================================================================
"

"Load the Glib baseline so libgio resolves (GLibIOLibrary) and the GError/FFI
 helper classes exist. No wrapper-class logic is used below. The gtk-bindings
 tonel source path is taken from $GTK_BINDINGS_SRC if set, else a default."
| gtkSrc |
gtkSrc := OSEnvironment current at: 'GTK_BINDINGS_SRC'
	ifAbsent: [ '/Users/demarey/dev/rmod/gtk-bindings/src' ].
Metacello new
	baseline: 'Glib';
	repository: 'tonel://' , gtkSrc;
	onConflict: [ :exx | exx useIncoming ];
	load: 'GIO-standalone'.
!

Object subclass: #XpStdinFFI instanceVariableNames: '' classVariableNames: '' poolDictionaries: 'GObjectTypes' category: 'Xp-Scratch'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessLauncherNew: flags
		^ self ffiCall: #(void * g_subprocess_launcher_new (gint flags)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessLauncherSpawnv: launcher argv: argv error: error
		^ self ffiCall: #(void * g_subprocess_launcher_spawnv (
			void *launcher,
			"const gchar * const *"void *argv,
			"GError **"GErrorHolder error)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetStdinPipe: sub
		^ self ffiCall: #(void * g_subprocess_get_stdin_pipe (void *sub)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetStdoutPipe: sub
		^ self ffiCall: #(void * g_subprocess_get_stdout_pipe (void *sub)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gOutputStreamWriteAll: stream buffer: buffer count: count bytesWritten: bytesWritten cancellable: cancellable error: error
		^ self ffiCall: #(gboolean g_output_stream_write_all (
			void *stream,
			"const gchar *"void *buffer,
			gsize count,
			"gsize *"void *bytesWritten,
			"GCancellable *"gpointer cancellable,
			"GError **"GErrorHolder error)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gOutputStreamClose: stream cancellable: cancellable error: error
		^ self ffiCall: #(gboolean g_output_stream_close (
			void *stream,
			"GCancellable *"gpointer cancellable,
			"GError **"GErrorHolder error)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessWaitCheck: sub cancellable: cancellable error: error
		^ self ffiCall: #(gboolean g_subprocess_wait_check (
			void *sub,
			"GCancellable *"gpointer cancellable,
			"GError **"GErrorHolder error)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gInputStreamRead: stream buffer: buffer count: count cancellable: cancellable error: error
		^ self ffiCall: #(gssize g_input_stream_read (
			void *stream,
			gchar *buffer,
			gsize count,
			"GCancellable *"gpointer cancellable,
			"GError **"GErrorHolder error)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetSuccessful: sub
		^ self ffiCall: #(gboolean g_subprocess_get_successful (void *sub)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetExitStatus: sub
		^ self ffiCall: #(gint g_subprocess_get_exit_status (void *sub)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gObjectUnref: handle
		self ffiCall: #(void g_object_unref (void *handle)) module: GLibIOLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'errorMessage: holder
		| handle err |
		handle := holder value.
		(handle isNil or: [ handle isNull ]) ifTrue: [ ^ ''unknown'' ].
		err := GError fromHandle: handle.
		^ err messageString'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'writeAll: stream bytes: aByteArray
		| count bytesWritten error ok |
		count := aByteArray size.
		bytesWritten := FFISizeT newBuffer.
		error := GErrorHolder new.
		ok := self gOutputStreamWriteAll: stream buffer: aByteArray count: count
				bytesWritten: bytesWritten cancellable: ExternalAddress null error: error.
		ok ifFalse: [ self error: ''write failed: '' , (self errorMessage: error) ]'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'readAll: stream
		| out error buf n |
		out := WriteStream on: ByteArray new.
		error := GErrorHolder new.
		buf := ByteArray new: 4096.
		[ n := self gInputStreamRead: stream buffer: buf count: 4096
				cancellable: ExternalAddress null error: error.
		  n <= 0 ifTrue: [ ^ out contents ].
		  out nextPutAll: (buf first: n) ] repeat'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'runEchoRoundTrip: childPath
		"Ports run_parent() from gprocess_stdin.c. Prints PASS or FAIL."
		| payload flags launcher argv sub stdinPipe stdoutPipe
		  successful echoed exitCode reason |

		payload := ''hello stdin'' asByteArray.
		flags := 1 | 4 | 16. "STDIN_PIPE | STDOUT_PIPE | STDERR_PIPE"
		launcher := self gSubprocessLauncherNew: flags.
		argv := ExternalAddress arrayOfStringsFrom: { childPath. ''--child-echo'' }.
		sub := nil. stdinPipe := nil. stdoutPipe := nil.
		successful := false. exitCode := -1. echoed := ByteArray new.
		reason := ''ok''.
		[
			sub := self gSubprocessLauncherSpawnv: launcher argv: argv error: GErrorHolder new.
			(sub isNil or: [ sub isNull ])
				ifTrue: [ reason := ''spawn failed'' ]
				ifFalse: [
					stdinPipe := self gSubprocessGetStdinPipe: sub.
					[ self writeAll: stdinPipe bytes: payload ]
						on: Error do: [ :e | reason := ''write: '' , e messageText ].
					self gOutputStreamClose: stdinPipe cancellable: ExternalAddress null error: GErrorHolder new.
					self gSubprocessWaitCheck: sub cancellable: ExternalAddress null error: GErrorHolder new.
					successful := self gSubprocessGetSuccessful: sub.
					exitCode := self gSubprocessGetExitStatus: sub.
					stdoutPipe := self gSubprocessGetStdoutPipe: sub.
					echoed := self readAll: stdoutPipe.
					reason := (echoed = payload and: [ successful ]) ifTrue: [ ''ok'' ] ifFalse: [ ''mismatch'' ] ] ]
		ensure: [
			sub ifNotNil: [ (sub isNull not) ifTrue: [ self gObjectUnref: sub ] ].
			argv freeArrayOfStrings.
			self gObjectUnref: launcher ].

		"NOTE: g_subprocess_get_stdin_pipe / get_stdout_pipe return (transfer none),
		 so the pipes are owned by the subprocess and must NOT be unrefd here -
		 the subprocess unref above releases them."

		reason = ''ok''
			ifTrue: [ Stdio stdout
					nextPutAll: ''PASS echo=''; nextPutAll: echoed asString; nextPutAll: '' exit='';
					nextPutAll: exitCode asString; cr ]
			ifFalse: [ Stdio stdout
					nextPutAll: ''FAIL ''; nextPutAll: reason;
					nextPutAll: '' echo=''; nextPutAll: echoed asString;
					nextPutAll: '' exit=''; nextPutAll: exitCode asString;
					nextPutAll: '' successful=''; nextPutAll: (successful ifTrue: [ 1 ] ifFalse: [ 0 ]) asString; cr ]'
	classified: 'private'.
!

"RUN"
| ffi childPath |
childPath := Smalltalk arguments first.
ffi := (Smalltalk classNamed: 'XpStdinFFI') new.
ffi runEchoRoundTrip: childPath.
Stdio stdout nextPutAll: 'SCRATCHDONE'; cr; flush.
Smalltalk quitPrimitive.
!
