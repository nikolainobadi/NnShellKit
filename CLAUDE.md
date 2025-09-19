# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NnShellKit is a lightweight Swift package that provides a simple interface for executing shell commands from Swift code. It offers both direct program execution and bash command execution with proper error handling.

## Core Architecture

The package follows a protocol-oriented design with four main components:

### Shell Protocol
The central abstraction that defines two methods:
- `bash(_ command: String)` - Executes bash commands with full shell features (pipes, redirects, etc.)
- `run(_ program: String, args: [String])` - Executes programs directly without shell interpretation

### Implementation Types
- **NnShell** - Production implementation using Foundation's Process API with timeout support
- **MockShell** - Test implementation with flexible result strategies (array-based or command-specific)
- **MockCommand** - Defines specific command behaviors for precise test control

### Error Handling
- **ShellError.failed** - Contains program path, exit code, and combined stdout/stderr output
- Both stdout and stderr are captured to a single stream and trimmed

## Development Commands

### Building and Testing
```bash
# Build the package
swift build

# Run all tests
swift test

# Run tests for a specific suite
swift test --filter "NnShell Tests"
swift test --filter "MockShell Tests"
swift test --filter "ShellErrorTests"
```

### Test Structure
Tests use Swift Testing framework (not XCTest) with the following patterns:
- `@Test("description")` for individual tests
- `@Suite("suite name")` for test groupings
- `#expect()` for assertions
- `#expect(throws: ErrorType.self)` for error testing

## Testing Strategy

### MockShell Features (v2.0.0)
The MockShell provides comprehensive testing capabilities:
- **Command Recording** - All executed commands are stored in `executedCommands` array
- **Result Strategies**:
  - Array-based: Predefined results returned in FIFO order via `results` parameter
  - Command-based: Specific results mapped to commands using `MockCommand` instances
- **Error Simulation** - Set `shouldThrowErrorOnFinal: true` to simulate failures when results exhausted
- **Convenience Methods** - `executedCommand(containing:)`, `commandCount(containing:)`, `verifyCommand(at:equals:)`, etc.

### Test File Organization
- `NnShellTests.swift` - Tests for the production NnShell implementation including timeout behavior
- `MockShellTests.swift` - Tests for MockShell testing utility and result strategies
- `ShellErrorTests.swift` - Tests for error handling and ShellError enum
- `MockCommand.swift` - Support type for command-specific test behaviors

## Code Conventions

### File Headers
All Swift files use "Nikolai Nobadi" in the "Created by" comment header.

### API Design
- Both `run()` and `bash()` methods are marked `@discardableResult`
- Combined stdout/stderr output with automatic trimming
- Shell protocol enables dependency injection for testing

### MockShell Usage Patterns (v2.0.0)

#### Array-based results:
```swift
let mock = MockShell(results: ["output1", "output2"])
try mock.bash("git status")  // Returns "output1"
assert(mock.executedCommands.first == "git status")
```

#### Command-specific results:
```swift
let mock = MockShell(commands: [
    MockCommand(command: "git status", result: .success("main branch")),
    MockCommand(command: "git push", result: .failure(code: 1, output: "error"))
])
try mock.bash("git status")  // Returns "main branch"
```

## Key Implementation Details (v2.0.0)

- `bash()` method delegates to `run("/bin/bash", args: ["-c", command])`
- NnShell supports configurable timeouts to prevent hanging commands
- Output is read asynchronously to prevent truncation issues
- MockShell uses strategy pattern for flexible result handling
- MockShell handles empty arguments correctly (no trailing space)
- Error tests should expect `NSError` for missing executables, `ShellError` for command failures
- Output expectations should account for shell behavior (e.g., echo stripping outer quotes)

## CI/CD

- GitHub Actions workflow runs tests on every push and pull request
- Tests run on macOS latest with Swift 6.0