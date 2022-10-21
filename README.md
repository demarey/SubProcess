# SubProcess [![Build Status](https://github.com/demarey/SubProcess/actions/workflows/main.yml/badge.svg)](https://github.com/demarey/SubProcess/actions/workflows/main.yml)

This project allows to run OS sub processes from a Pharo image.
It uses GLib IO library to spawn processes through FFI calls.
SubProcess offers a high-level API, OS-agnostic API to run easily processes from your Pharo code. Windows, Linux and Mac Os are supported!

WARNING: For now, there is only support for synchroneous processes (i.e. the execution will wait the spawed process termination). Asynchroneous support will come a bit later.
WARNING 2: fetching of the exit code may not be reliable (TO FIX!)

## Examples

### Run a simple command
```smalltalk
process := SPSProcess new
  command: '/bin/ls'.
process run.
 ```
  
```smalltalk
process := SPSProcess new
  command: 'C:\Windows\System32\systeminfo.exe'.
process run.
```
  
### Run a command and getting the output
```smalltalk
process := SPSProcess new
  command: '/bin/ls';
  run.
  
out := process stdOut.
err := process stdErr.
```
  
### Set the working directory
```smalltalk
process := SPSProcess new
  workingDirectory: '/etc';
  command: '/bin/ls'.
	
process run.
```
  
### Give arguments
```smalltalk
process := SPSProcess new
  command: '/bin/ls';
  arguments: #('/etc').
	
process run.
```
  
### Use a shell to run the command
```smalltalk
process := SPSProcess new
  workingDirectory: 'C:\';
  windowsShellCommand;
  addArgument: 'dir'.
  
process run.
```

## Getting the status of the process
### Know if the process has completed its execution
```smalltalk
process := SPSProcess new
  command: '/bin/ls';
  run.
self assert: process isComplete.
```
### Know if the spawn of the process is sucessful (no error)
```smalltalk
process := SPSProcess new
  command: '/bin/ls';
  run.
self assert: process isSuccess.
```
### Getting error if the spawn of the process failed
```smalltalk
process := SPSProcess new
  command: '/bin/ls'.
[ process run ]
on: SPSError
do: [ :error | error messageText inspect ]
```

## Encoding
When running a command that will give you back some output (standard output or standard error), you will get an encoded String (a byte array) that needs to be decoded. SubProcess cannot guess what will be the encoding as many encodings are used worldwide. One commonly used encoding is utf-8 on unix-like systems. On Windows, different encondings are used.
SubProcess configure a default encoding (`utf-8` on unix-like systems and `cp-850` on Windows) for convenience. Do not forget you could need a different encoding. If so, you can configure it before running the process:
```smalltalk
process := SPSProcess new
  encoding: 'ISO-8859-2'
  command: '/bin/ls';
  run.
out := process stdOut.
```
