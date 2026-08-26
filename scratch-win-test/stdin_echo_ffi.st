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
g_object_unref) are used. The file is fully self-contained: it defines its own
FFILibrary subclass bound to libgio (XpGioLibrary) and uses only the atomic C
types that plain Pharo FFI understands (void*, int, size_t, long), so it does
NOT need the Gtk/GObject pool variables, GErrorHolder/GError helper classes or
the gtk-bindings baseline at all.

Default Pharo (non-threaded) FFI is used, so there is no dependency on the
Gtk threaded-FII engine either.

Prints:
    PASS echo=<payload> exit=<status>
or
    FAIL <reason> echo=<bytes> exit=<status> successful=<0|1>
then a trailing marker line and quits the VM.

This file is a Pharo fileIn: code chunks are delimited by a "!" on its own
line, and each chunk is parsed/evaluated in order once the previous one has
run. That lets the library/class be created before its methods are compiled.
================================================================================
"

"FFILibrary subclass bound to libgio-2.0 (kept dependency-free)."
FFILibrary subclass: #XpGioLibrary
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Xp-Scratch'.
!

(Smalltalk classNamed: 'XpGioLibrary') compile:
	'macLibraryName
		^ FFIMacLibraryFinder findAnyLibrary: #(''libgio-2.0.dylib'' ''libgio-2.0.0.dylib'')'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpGioLibrary') compile:
	'unix64LibraryName
		^ FFIUnix64LibraryFinder findAnyLibrary: #(''libgio-2.0.so'' ''libgio-2.0.so.0'')'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpGioLibrary') compile:
	'win32LibraryName
		^ FFIWindowsLibraryFinder findAnyLibrary: #(''libgio-2.0-0.dll'' ''libgio-2.0.dll'')'
	classified: 'private'.
!

Object subclass: #XpStdinFFI instanceVariableNames: '' classVariableNames: '' poolDictionaries: '' category: 'Xp-Scratch'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessLauncherNew: flags
		^ self ffiCall: #(void * g_subprocess_launcher_new (int flags)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessLauncherSpawnv: launcher argv: argv error: error
		^ self ffiCall: #(void * g_subprocess_launcher_spawnv (
			void *launcher,
			void *argv,
			void *error)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetStdinPipe: sub
		^ self ffiCall: #(void * g_subprocess_get_stdin_pipe (void *sub)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetStdoutPipe: sub
		^ self ffiCall: #(void * g_subprocess_get_stdout_pipe (void *sub)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetSuccessful: sub
		^ self ffiCall: #(int g_subprocess_get_successful (void *sub)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessGetExitStatus: sub
		^ self ffiCall: #(int g_subprocess_get_exit_status (void *sub)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gSubprocessWaitCheck: sub cancellable: cancellable error: error
		^ self ffiCall: #(int g_subprocess_wait_check (
			void *sub,
			void *cancellable,
			void *error)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gOutputStreamWriteAll: stream buffer: buffer count: count bytesWritten: bytesWritten cancellable: cancellable error: error
		^ self ffiCall: #(int g_output_stream_write_all (
			void *stream,
			void *buffer,
			size_t count,
			void *bytesWritten,
			void *cancellable,
			void *error)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gOutputStreamClose: stream cancellable: cancellable error: error
		^ self ffiCall: #(int g_output_stream_close (
			void *stream,
			void *cancellable,
			void *error)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gInputStreamRead: stream buffer: buffer count: count cancellable: cancellable error: error
		^ self ffiCall: #(long g_input_stream_read (
			void *stream,
			void *buffer,
			size_t count,
			void *cancellable,
			void *error)) module: XpGioLibrary'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'gObjectUnref: handle
		self ffiCall: #(void g_object_unref (void *handle)) module: XpGioLibrary'
	classified: 'private'.
!

"Storage for a GError* written by libgio when a call fails. We never dereference
 it (the example expects success), but a writable buffer keeps failing calls
 from crashing the VM."
(Smalltalk classNamed: 'XpStdinFFI') compile:
	'newErrorBuffer
		^ ExternalAddress allocate: 8'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'writeAll: stream bytes: aByteArray
		| count bytesWritten error ok |
		count := aByteArray size.
		bytesWritten := FFISizeT newBuffer.
		error := self newErrorBuffer.
		ok := self gOutputStreamWriteAll: stream buffer: aByteArray count: count
				bytesWritten: bytesWritten cancellable: ExternalAddress null error: error.
		ok ifFalse: [ self error: ''write failed'' ]'
	classified: 'private'.
!

(Smalltalk classNamed: 'XpStdinFFI') compile:
	'readAll: stream
		| out error buf n |
		out := WriteStream on: ByteArray new.
		error := self newErrorBuffer.
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
			sub := self gSubprocessLauncherSpawnv: launcher argv: argv error: self newErrorBuffer.
			(sub isNil or: [ sub isNull ])
				ifTrue: [ reason := ''spawn failed'' ]
				ifFalse: [
					stdinPipe := self gSubprocessGetStdinPipe: sub.
					[ self writeAll: stdinPipe bytes: payload ]
						on: Error do: [ :e | reason := ''write: '' , e messageText ].
					self gOutputStreamClose: stdinPipe cancellable: ExternalAddress null error: self newErrorBuffer.
					self gSubprocessWaitCheck: sub cancellable: ExternalAddress null error: self newErrorBuffer.
					successful := (self gSubprocessGetSuccessful: sub) = 1.
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
