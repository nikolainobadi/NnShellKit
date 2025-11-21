# NnShellKit

![Build Status](https://github.com/nikolainobadi/NnShellKit/actions/workflows/ci.yml/badge.svg)
![Swift Version](https://badgen.net/badge/swift/5.5%2B/purple)
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
- [Using MockShell](#using-mockshell)
  - [Basic Usage](#basic-usage)
  - [Result Strategies](#result-strategies)
  - [MockCommand](#mockcommand)
- [Xcode Integration](#xcode-integration)
- [Error Handling](#error-handling)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## Overview

NnShellKit provides a simple interface for bash commands and direct program execution, real time streaming, combined stdout and stderr capture, configurable timeouts, predictable testing utilities, and protocol oriented design.

## Installation

Add the package
```swift
.package(url: "https://github.com/nikolainobadi/NnShellKit.git", from: "2.0.0")
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
- Timeout is available on captured output commands.

## API Summary

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

Timeout behavior includes terminate, kill signal fallback, and partial output capture in the error.

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

- Shell protocol defines the interface.
- NnShell is the production implementation.
- MockShell and MockCommand support testing.
- ShellError includes exit details.

## Contributing

Any feedback or ideas to enhance NnShellKit would be well received. Please feel free to open an issue.

## License

NnShellKit is available under the MIT license.
