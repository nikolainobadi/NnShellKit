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
- **Real-time output streaming**: Stream command output directly to stdout/stderr with `runAndPrint`
- **Comprehensive error handling**: Captures exit codes and combined stdout/stderr
- **Timeout support**: Prevent commands from hanging with configurable timeouts
- **Built-in testing support**: MockShell with flexible result strategies for unit testing
- **Protocol-oriented design**: Easy dependency injection and testing
- **@discardableResult**: Use with or without capturing output
- **Async output reading**: Prevents truncation of large command outputs

## Installation

Add the package to your Swift project using Swift Package Manager:

```swift
.package(url: "https://github.com/nikolainobadi/NnShellKit.git", from: "2.0.0")
```

## Usage

### Basic Shell Command Execution

```swift
import NnShellKit

let shell = NnShell()

// Or with timeout (in seconds)
let shellWithTimeout = NnShell(timeout: 30)

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

### Real-Time Output Streaming

Use `runAndPrint()` when you want to see command output in real-time (doesn't capture/return output):

```swift
// Stream build output directly to console
try shell.runAndPrint("/usr/bin/swift", args: ["build", "--verbose"])

// Stream test results as they run
try shell.runAndPrint("/usr/bin/swift", args: ["test"])

// Stream git operations with progress
try shell.runAndPrint(bash: "git clone --progress https://github.com/user/repo.git")

// Stream deployment scripts
try shell.runAndPrint(bash: "npm install && npm run build && npm test")
```

**When to use `runAndPrint` vs `run`/`bash`:**
- Use `runAndPrint()` for long-running commands where you want real-time feedback
- Use `runAndPrint()` for build scripts, tests, or deployments with progress indicators
- Use `run()`/`bash()` when you need to capture and process the output

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
import NnShellTesting

let mock = MockShell(results: ["branch1\nbranch2", "commit abc123"])

// Returns predefined results
let branches = try mock.bash("git branch")  // Returns "branch1\nbranch2"
let commit = try mock.bash("git rev-parse HEAD")  // Returns "commit abc123"

// Verify commands were executed
assert(mock.executedCommands == ["git branch", "git rev-parse HEAD"])

// MockShell also supports runAndPrint (consumes results without returning)
try mock.runAndPrint("/usr/bin/swift", args: ["build"])
try mock.runAndPrint(bash: "npm test")
```

### Advanced Mock Features (v2.0.0)

```swift
// Error simulation when results exhausted
let errorMock = MockShell(results: ["output1"], shouldThrowErrorOnFinal: true)
try errorMock.bash("first command")  // Returns "output1"
// Next command will throw ShellError.failed

// Command verification helpers
let mock = MockShell(results: ["output1", "output2"])
try mock.bash("git add .")
try mock.bash("git commit -m 'test'")

assert(mock.executedCommand(containing: "git add"))
assert(mock.commandCount(containing: "git") == 2)
assert(mock.verifyCommand(at: 0, equals: "git add ."))

// Testing runAndPrint methods
let buildMock = MockShell(results: ["build output", "test output"])
try buildMock.runAndPrint("/usr/bin/swift", args: ["build"])  // Consumes "build output"
try buildMock.runAndPrint(bash: "swift test")  // Consumes "test output"
assert(buildMock.executedCommands.count == 2)
```

### MockCommand for Precise Test Control (v2.0.0)

MockCommand allows you to define specific behaviors for individual commands, making your tests more predictable and easier to understand:

```swift
// Basic MockCommand usage
let mock = MockShell(commands: [
    MockCommand(command: "git status", result: .success("clean")),
    MockCommand(command: "git push", result: .failure(code: 1, output: "error"))
])

try mock.bash("git status")  // Returns "clean"
// try mock.bash("git push")  // Would throw ShellError.failed

// Testing a deployment script
let deployMock = MockShell(commands: [
    MockCommand(command: "npm test", result: .success("All tests passed")),
    MockCommand(command: "npm run build", result: .success("Build complete")),
    MockCommand(command: "aws s3 sync dist/ s3://bucket", result: .success("Upload complete")),
    MockCommand(command: "aws cloudfront create-invalidation --distribution-id ABC123 --paths '/*'",
                result: .success("Invalidation created"))
])

// Your deployment function
func deploy(using shell: Shell) throws {
    print(try shell.bash("npm test"))
    print(try shell.bash("npm run build"))
    print(try shell.bash("aws s3 sync dist/ s3://bucket"))
    print(try shell.bash("aws cloudfront create-invalidation --distribution-id ABC123 --paths '/*'"))
}

try deploy(using: deployMock)
assert(deployMock.executedCommands.count == 4)

// Simulating different scenarios
let failureMock = MockShell(commands: [
    MockCommand(command: "npm test", result: .failure(code: 1, output: "2 tests failed"))
])

do {
    try deploy(using: failureMock)
} catch {
    // Handle test failure scenario
}

// Using run() with MockCommand
let runMock = MockShell(commands: [
    MockCommand(command: "/usr/bin/git status", result: .success("On branch main")),
    MockCommand(command: "/usr/bin/git push origin main", result: .success("Everything up-to-date"))
])

try runMock.run("/usr/bin/git", args: ["status"])  // Returns "On branch main"
try runMock.run("/usr/bin/git", args: ["push", "origin", "main"])  // Returns "Everything up-to-date"
```

## Architecture

NnShellKit follows a protocol-oriented design:

- **Shell Protocol**: Defines the interface for command execution with four methods:
  - `bash(_:)` - Execute bash commands, returns captured output
  - `run(_:args:)` - Execute programs directly, returns captured output
  - `runAndPrint(_:args:)` - Execute programs, stream output to stdout/stderr
  - `runAndPrint(bash:)` - Execute bash commands, stream output to stdout/stderr
- **NnShell**: Production implementation using Foundation's Process API with timeout support
- **MockShell**: Test implementation with flexible result strategies (array-based or command-specific)
- **MockCommand**: Defines specific command behaviors for precise test control
- **ShellError**: Structured error type with program, exit code, and output

This design makes it easy to:
- Write testable code through dependency injection
- Mock shell operations in unit tests
- Extend functionality with custom Shell implementations

## Contributing

Feel free to submit issues or pull requests. If you have ideas for improvements or additional features, I'd love to hear from you!

## License

NnShellKit is available under the MIT license. See the [LICENSE](LICENSE) file for more information.