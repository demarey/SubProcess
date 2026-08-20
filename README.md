# SubProcess [![Build Status](https://github.com/demarey/SubProcess/actions/workflows/main.yml/badge.svg)](https://github.com/demarey/SubProcess/actions/workflows/main.yml)

This project allows to run OS sub processes from a Pharo image.
It uses GLib IO library to spawn processes through FFI calls.
SubProcess offers a high-level API, OS-agnostic API to run easily processes from your Pharo code. Windows, Linux and Mac Os are supported!

WARNING: Asynchroneous processes are supported but do not handle all platforms yet (the async tests currently run on POSIX systems).

## Examples

### Run a simple command
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  sync.
process run.
 ```
  
```smalltalk
process := SPSProcessConfiguration new
  command: 'C:\Windows\System32\systeminfo.exe';
  sync.
process run.
```
  
### Run a command and getting the output
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  sync.
process run.
  
out := process stdOut.
err := process stdErr.
```
  
### Set the working directory
```smalltalk
process := SPSProcessConfiguration new
  workingDirectory: '/etc';
  command: '/bin/ls';
  sync.
	
process run.
```
  
### Give arguments
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  arguments: #('/etc');
  sync.
	
process run.
```
  
### Use a shell to run the command
```smalltalk
process := SPSProcessConfiguration new
  workingDirectory: 'C:\';
  windowsShellCommand;
  addArgument: 'dir';
  sync.
  
process run.
```

## Running asynchroneous processes

`async` processes return immediately after the child is spawned: execution resumes without
waiting for the child to terminate. This is handy to run long-running commands or several
processes in parallel.

### Run a command asynchroneously
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  async.
process run.
```

### Know when the process completed
Register a callback invoked when the child process exits:
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/sh';
  arguments: #('-c' 'sleep 2');
  async.
process whenCompletedDo: [ :aProcess |
  Transcript show: 'exit code: ', aProcess exitCode asString; cr ].
process run.
```

### Reading the output with streams
By default no output is captured. Read directly from the process channels (blocking reads):
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  async.
process run.
out := process stdOutChannel readLine.
```
WARNING: if the child produces a lot of output, nothing reads the pipes: they fill up, the child
blocks writing and never finishes. Prefer `collectOutput` or `outputLineDo:` for output-heavy
commands.

### Consuming the output line-by-line (streaming)
`outputLineDo:` evaluates a block for each output line as it is produced, without buffering the
whole output in memory. Ideal for large or infinite output:
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/sh';
  arguments: #('-c' 'seq 1 1000');
  async.
process outputLineDo: [ :aLine | Transcript show: aLine; cr ].
process run.
```

### Auto-collecting the output
Call `collectOutput` to capture stdout and stderr line-by-line in the background. The collected
text is then available on `stdOut` / `stdErr`. When the process completes, the output listeners
are drained to EOF before completion is announced, so the collected output is complete:
```smalltalk
process := (SPSProcessConfiguration new
  command: '/bin/sh';
  arguments: #('-c' 'echo hello');
  async) collectOutput.
process run.
process runAndWaitTimeOut: 2 seconds.
out := process stdOut.   "a String containing 'hello'"
```

### Waiting with a timeout
`runAndWaitTimeOut:` runs the process, waits up to the given duration for completion, and kills
the child if it did not finish in time. It answers `true` on timeout, `false` otherwise:
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/sleep';
  arguments: #('30');
  async.
self assert: (process runAndWaitTimeOut: 1 second).
```

### Terminating a running process
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/sleep';
  arguments: #('30');
  async.
process run.
process terminate.
```

## Getting the status of the process
### Know if the process has completed its execution
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  sync.
process run.
self assert: process isComplete.
```
### Asynchroneous processes: isComplete vs wasTerminated
With `async` processes, `isComplete` tells whether the child has finished running, whatever the
reason. Use `wasTerminated` to know if that finish was caused by your own `terminate` call
(e.g. because of a timeout):
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/sleep';
  arguments: #('30');
  async.
timedOut := process runAndWaitTimeOut: 1 second.
self assert: timedOut.
self assert: process isComplete.      "the process finished"
self assert: process wasTerminated.   "...because we killed it"
```
- `isComplete = true` and `wasTerminated = false` → the child exited by itself (normal or signal exit).
- `isComplete = true` and `wasTerminated = true` → the child was killed by the caller.
- `isComplete = false` → still running (never terminated).
### Know if the spawn of the process is sucessful (no error)
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  sync.
process run.
self assert: process isSuccess.
```
### Getting error if the spawn of the process failed
```smalltalk
process := SPSProcessConfiguration new
  command: '/bin/ls';
  sync.
[ process run ]
on: SPSError
do: [ :error | error messageText inspect ]
```

## Encoding
When running a command that will give you back some output (standard output or standard error), you will get an encoded String (a byte array) that needs to be decoded. SubProcess cannot guess what will be the encoding as many encodings are used worldwide. One commonly used encoding is utf-8 on unix-like systems. On Windows, different encondings are used.
SubProcess configure a default encoding (`utf-8` on unix-like systems and `cp-850` on Windows) for convenience. Do not forget you could need a different encoding. If so, you can configure it before running the process:
```smalltalk
process := SPSProcessConfiguration new
  encoding: 'ISO-8859-2'
  command: '/bin/ls';
  sync.
process run.
out := process stdOut.
```
