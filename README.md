# NnShellKit

![Build Status](https://github.com/nikolainobadi/NnShellKit/actions/workflows/ci.yml/badge.svg)
![Swift Version](https://badgen.net/badge/swift/5.9%2B/purple)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

NnShellKit is a lightweight Swift package for executing shell commands in Swift. It provides a simple API, real time streaming, timeout control, and a dedicated testing module for predictable unit tests.

This package is built to be simple, reliable, and easy to test.

## Table of Contents
- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [API Summary](#api-summary)
- [Using NnShell](#using-nnshell)
  - [Bash Commands](#bash-commands)
  - [Direct Program Execution](#direct-program-execution)
  - [Streaming Output](#streaming-output)
  - [Timeouts](#timeouts)
- [Using AsyncNnShell](#using-asyncnnshell)
- [Stopping Child Processes at Shutdown](#stopping-child-processes-at-shutdown)
- [Using MockShell](#using-mockshell)
  - [Basic Usage](#basic-usage)
  - [Result Strategies](#result-strategies)
  - [MockCommand](#mockcommand)
  - [Sharing MockShell](#sharing-mockshell)
  - [Async Mocking](#async-mocking)
- [Xcode Integration](#xcode-integration)
- [Error Handling](#error-handling)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## Overview

NnShellKit provides a simple interface for bash commands and direct program execution, real time streaming, combined stdout and stderr capture, configurable timeouts, cancellable async execution, child process shutdown control, predictable testing utilities, and protocol oriented design.

> **Looking for more API details?** This README is a guided tour of the common
> paths. Further details — including the MockShell recording formats and result
> strategies not shown here — are documented in [`Skills/NnShellKit`](Skills/NnShellKit),
> which lives in this repo so it changes in the same PR as the API it describes.

## Installation

Requires Swift 5.9 or later and macOS 13 or later.

Add the package
```swift
.package(url: "https://github.com/nikolainobadi/NnShellKit.git", from: "2.4.0")
```

Add NnShellKit as a target dependency
```swift
.product(name: "NnShellKit", package: "NnShellKit")
```

Add NnShellTesting as a test target dependency (optional)
```swift
.product(name: "NnShellTesting", package: "NnShellKit")
```

## Quick Start

```swift
import NnShellKit

let shell = NnShell()

let status = try shell.bash("git status")
let files = try shell.run("/bin/ls", args: ["-la"])

try shell.runAndPrint("/usr/bin/swift", args: ["build"])
```

## Core Concepts

- `bash` uses `/bin/bash -c` for pipes, redirects, env variables.
- `run` executes programs directly with no shell overhead.
- Streaming methods print directly to stdout and stderr.
- Timeout is available on captured output commands in `NnShell`.
- `AsyncNnShell` captures output with `async`/`await` and supports task cancellation.
- `Shell` and `AsyncShell` require `Sendable` conformance.

## API Summary

Synchronous `Shell` methods:

| Method                     | Captures output | Streams output | Timeout support |
|---------------------------|-----------------|----------------|-----------------|
| bash                      | Yes             | No             | Yes             |
| run                       | Yes             | No             | Yes             |
| runAndPrint               | No              | Yes            | No              |
| runAndPrint(bash)         | No              | Yes            | No              |

## Using NnShell

### Bash Commands

```swift
let result = try shell.bash("git status | grep modified")
try shell.bash("echo $HOME > /tmp/home.txt")
try shell.bash("ls *.swift | wc -l")
```

### Direct Program Execution

```swift
let output = try shell.run("/bin/echo", args: ["Hello"])
try shell.run("/usr/bin/git", args: ["status", "--porcelain"])
```

### Streaming Output

```swift
try shell.runAndPrint("/usr/bin/swift", args: ["build"])
try shell.runAndPrint(bash: "git clone https://github.com/user/repo.git")
```

### Timeouts

```swift
let shell = NnShell(timeout: 20)
try shell.bash("sleep 30")
```

On timeout, the command's process group receives `SIGTERM`, followed by `SIGKILL` after a one-second grace period if needed. The error includes partial output.

## Using AsyncNnShell

`AsyncNnShell` implements `AsyncShell` with async `bash` and `run` methods. Both capture combined stdout and stderr and return trimmed output. It has no streaming methods or timeout parameter.

In an async context:

```swift
import NnShellKit

let shell = AsyncNnShell()
let output = try await shell.run("/bin/echo", args: ["Hello"])
let status = try await shell.bash("git status")
```

Cancelling the awaiting task requests termination of the command's process group with `SIGTERM`, escalating to `SIGKILL` after a grace period if needed. Cancellation throws `CancellationError`; non-zero exits throw `ShellError.failed`.

## Stopping Child Processes at Shutdown

Call `ChildProcesses.terminateAll(gracePeriod:)` from your application's shutdown path to stop running commands launched by `NnShell` or `AsyncNnShell`, including streaming commands and descendants in their process groups.

Call this only when your application is about to exit: it permanently prevents new launches across all `NnShell` and `AsyncNnShell` instances. Subsequent launch attempts throw `CancellationError`; there is no reset.

```swift
import NnShellKit

// In your application's shutdown path, before exiting:
ChildProcesses.terminateAll(gracePeriod: 2)
```

Each tracked process group receives `SIGTERM`, followed by `SIGKILL` if it remains alive after the grace period in seconds. The call blocks until every tracked group has exited or been sent `SIGKILL`. Processes that move into another process group or session, such as daemons, are not reached.

## Using MockShell

Import:

```swift
import NnShellKit
import NnShellTesting
```

### Basic Usage

```swift
let mock = MockShell(results: ["one", "two"])

let first = try mock.bash("cmd")
let second = try mock.run("/bin/ls", args: [])
```

### Result Strategies

FIFO results or command mapping:

```swift
let mock = MockShell(results: ["a", "b"])
```

```swift
let mock = MockShell(commands: [
    MockCommand(command: "git status", output: "clean"),
    MockCommand(command: "git push", error: ShellError.failed(program: "git", code: 1, output: "fail"))
])
```

### MockCommand

```swift
let mock = MockShell(commands: [
    MockCommand(command: "/usr/bin/git status", output: "OK"),
    MockCommand(command: "/usr/bin/git push origin main", output: "Done")
])
```

### Sharing MockShell

`MockShell` is a `Sendable` struct and cannot be subclassed. Copies share the same recorded commands and result queue, protected by a lock. Use composition when adding custom behavior.

### Async Mocking

`MockAsyncShell` implements `AsyncShell` with the same FIFO results and command mappings as `MockShell`. Its FIFO initializer requires an explicit `shouldThrowErrorOnFinal` argument.

In an async context:

```swift
import NnShellKit
import NnShellTesting

let mock = MockAsyncShell(results: ["clean"], shouldThrowErrorOnFinal: false)
let output = try await mock.bash("git status") // Returns "clean"
let commands = mock.executedCommands // ["git status"]
```

A call from an already-cancelled task throws `CancellationError` without recording a command.

## Xcode Integration

```swift
try shell.run("/usr/bin/xcodebuild", args: [
    "-project", "MyApp.xcodeproj",
    "-scheme", "MyApp",
    "build"
])
```

## Error Handling

```swift
do {
    try shell.bash("git status")
} catch let error as ShellError {
    switch error {
    case .failed(let program, let code, let output):
        print(program)
        print(code)
        print(output)
    }
}
```

## Architecture

- Shell and AsyncShell define the synchronous and asynchronous interfaces.
- NnShell and AsyncNnShell are the production implementations.
- MockShell, MockAsyncShell, and MockCommand support testing.
- ShellError includes exit details.

## Contributing

Any feedback or ideas to enhance NnShellKit would be well received. Please feel free to open an issue.

## License

NnShellKit is available under the MIT license.
