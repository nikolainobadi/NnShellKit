# NnShellKit

![Build Status](https://github.com/nikolainobadi/NnShellKit/actions/workflows/ci.yml/badge.svg)
![Swift Version](https://badgen.net/badge/swift/5.5%2B/purple)
![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

NnShellKit is a lightweight Swift package that provides a simple interface for executing shell commands from Swift code. I built this package as a clean alternative to SwiftShell for basic shell command execution needs, focusing on simplicity and testability.

The package offers both direct program execution and full bash command support with pipes, redirects, and environment variables, while providing comprehensive testing utilities through MockShell.

> **Note:** This package focuses on the core essentials of shell command execution. It's designed to be simple, reliable, and easy to test.

## Features

- **Two execution modes**: Direct program execution and bash command execution
- **Comprehensive error handling**: Captures exit codes and combined stdout/stderr
- **Built-in testing support**: MockShell for unit testing without actual command execution
- **Protocol-oriented design**: Easy dependency injection and testing
- **@discardableResult**: Use with or without capturing output

## Installation

Add the package to your Swift project using Swift Package Manager:

```swift
.package(url: "https://github.com/nikolainobadi/NnShellKit.git", from: "1.0.0")
```

## Usage

### Basic Shell Command Execution

```swift
import NnShellKit

let shell = NnShell()

// Execute bash commands with full shell features
let output = try shell.bash("git status | grep modified")

// Execute programs directly
let files = try shell.run("/bin/ls", args: ["-la", "/tmp"])

// Silent execution (discardable result)
try shell.bash("git add .")
try shell.run("/usr/bin/touch", args: ["newfile.txt"])
```

### Bash vs Direct Execution

Use `bash()` when you need shell features:
```swift
// Pipes, redirects, environment variables
try shell.bash("echo $HOME > /tmp/home.txt")
try shell.bash("ls *.swift | wc -l")
try shell.bash("cd /tmp && ls")
```

Use `run()` for direct program execution:
```swift
// More efficient for simple commands
let output = try shell.run("/bin/echo", args: ["Hello, World!"])
try shell.run("/usr/bin/git", args: ["status", "--porcelain"])
```

### Xcode Integration

NnShellKit works great for build scripts and Xcode automation:

```swift
// Build an Xcode project
try shell.run("/usr/bin/xcodebuild", args: [
    "-project", "MyApp.xcodeproj", 
    "-scheme", "MyApp", 
    "build"
])

// Run tests
try shell.run("/usr/bin/xcodebuild", args: [
    "test", 
    "-project", "MyApp.xcodeproj", 
    "-scheme", "MyApp", 
    "-destination", "platform=iOS Simulator,name=iPhone 15"
])

// List simulators
let simulators = try shell.run("/usr/bin/xcrun", args: [
    "simctl", "list", "devices", "available"
])
```

### Error Handling

```swift
do {
    let output = try shell.bash("git status")
    print("Git output: \(output)")
} catch let error as ShellError {
    switch error {
    case .failed(let program, let code, let output):
        print("Command failed: \(program)")
        print("Exit code: \(code)")
        print("Error output: \(output)")
    }
}
```

## Testing with MockShell

NnShellKit includes MockShell for comprehensive testing without executing real commands:

### Basic Mock Usage

```swift
import NnShellKit

let mock = MockShell(results: ["branch1\nbranch2", "commit abc123"])

// Returns predefined results
let branches = try mock.bash("git branch")  // Returns "branch1\nbranch2"
let commit = try mock.bash("git rev-parse HEAD")  // Returns "commit abc123"

// Verify commands were executed
assert(mock.executedCommands == ["git branch", "git rev-parse HEAD"])
```

### Advanced Mock Features

```swift
// Error simulation
let errorMock = MockShell(shouldThrowError: true)
// All commands will throw ShellError.failed

// Command verification
mock.reset()
try mock.bash("git add .")
try mock.bash("git commit -m 'test'")

assert(mock.executedCommand(containing: "git add"))
assert(mock.commandCount(containing: "git") == 2)
assert(mock.verifyCommand(at: 0, equals: "git add ."))
```

## Architecture

NnShellKit follows a protocol-oriented design:

- **Shell Protocol**: Defines the interface for command execution
- **NnShell**: Production implementation using Foundation's Process API
- **MockShell**: Test implementation with command recording and result stubbing
- **ShellError**: Structured error type with program, exit code, and output

This design makes it easy to:
- Write testable code through dependency injection
- Mock shell operations in unit tests
- Extend functionality with custom Shell implementations

## Contributing

Feel free to submit issues or pull requests. If you have ideas for improvements or additional features, I'd love to hear from you!

## License

NnShellKit is available under the MIT license. See the [LICENSE](LICENSE) file for more information.