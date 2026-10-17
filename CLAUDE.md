# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Imports

@~/.claude/guidelines/style/shared-formatting-claude.md
@~/.claude/guidelines/testing/base_unit_testing_guidelines.md

## Skill Documentation

`Skills/NnShellKit/` holds the published API-reference skill. It lives here — not in a separate
skills repo — so the API and its documentation change in the same PR. It previously lived in the
`nelix-swift-tools` marketplace, where nothing tied it to this package's releases.

- **Any PR changing the public API must update `Skills/`.** Nothing enforces this in CI, so
  check it by hand whenever a PR touches `public`/`open`/`package` declarations in `Sources/`.
- **`Skills/NnShellKit/.claude-plugin/plugin.json` deliberately has no `version` field.**
  Do not reintroduce one — the installer keys its cache by commit sha, and a hand-maintained
  version number is exactly the stale-number problem this layout removes.
- **SwiftPM ignores `Skills/`** — it is not a target and must not become one.
- `Skills/NnShellKit/skills/NnShellKit/manifest.json` pins the sha and per-file hashes of the
  `Sources/` state the docs describe. Regenerate it when the docs are updated.

### Releasing

The skill is consumed through the `nn-swift-skills` marketplace, pinned to a **tag** rather than
tracking `main`. **Doc changes therefore reach consumers on release, not on merge** — a correction
merged to `main` is invisible until the next tag. A release is two steps in two repos, but the
second is automated:

1. Tag this repo (no `v` prefix — matches the `2.2.0` convention) and push the tag.
2. `.github/workflows/skill-ref-bump.yml` fires on that push, rewrites `ref` in
   `nn-swift-skills/.claude-plugin/marketplace.json`, and opens a PR there. **Merge it.**

If that automation is ever removed the bump becomes manual, and an unbumped `ref` serves the
previous release's docs forever — nothing errors and nothing warns.

The workflow authenticates with the repo secret **`MARKETPLACE_TOKEN`**: a fine-grained PAT named
`nn-swift-skills-ref-bump`, scoped to `nn-swift-skills` only (Contents + Pull requests, read and
write), **expiring 2027-08-15**. It is **shared with every other package repo** publishing to that
marketplace, so rotating it means re-setting the secret in each of them, not just here.

When it expires the workflow fails loudly on tag push — a red X, not silence. Treat that as "rotate
the shared token", not "this repo's workflow is broken."

## Project Overview

NnShellKit is a lightweight Swift package that provides a simple interface for executing shell commands from Swift code. It offers both direct program execution and bash command execution with proper error handling, through synchronous and cancellable async interfaces. `Package.swift` requires Swift tools 5.9+ and macOS 13+.

## Core Architecture

The package follows a protocol-oriented design with synchronous and async shell interfaces:

### Shell Protocol
The synchronous abstraction requires `Sendable` conformance and defines four methods:
- `bash(_ command: String)` - Executes bash commands with full shell features (pipes, redirects, etc.), returns captured output
- `run(_ program: String, args: [String])` - Executes programs directly without shell interpretation, returns captured output
- `runAndPrint(_ program: String, args: [String])` - Executes programs and streams output directly to stdout/stderr (no capture)
- `runAndPrint(bash command: String)` - Executes bash commands and streams output directly to stdout/stderr (no capture)

### AsyncShell Protocol
The async abstraction also requires `Sendable` conformance and defines `bash(_:)` and `run(_:args:)` as `async throws` methods returning captured output. It has no streaming methods or timeout parameter.

### Implementation Types
- **NnShell** - Production implementation using Foundation's Process API with timeout support
- **AsyncNnShell** - Production async implementation using the internal `ProcessRunner` for process execution and task cancellation
- **MockShell** - `Sendable` struct with flexible result strategies (array-based or command-specific); copies share locked state, and subclassing is unavailable
- **MockAsyncShell** - Async test implementation wrapping `MockShell`; checks task cancellation before recording a command or consuming a result
- **MockCommand** - Defines specific command behaviors for precise test control

### Child Process Shutdown
`ChildProcesses.terminateAll(gracePeriod:)` stops tracked processes from `NnShell` (including streaming commands) and `AsyncNnShell`. It signals the process group when the launched process leads it, otherwise the process itself, sending `SIGTERM` and then `SIGKILL` to remaining targets after the supplied grace period. It blocks until targets have exited or been sent `SIGKILL`; processes that escape their group are outside its signal target.

This is an application-exit operation: the shared `ProcessGroupRegistry` permanently refuses new launches once shutdown begins, with no reset. Shutdown tests use fresh registries through the internal `NnShell(timeout:registry:)` and `AsyncNnShell(registry:)` initializers so they do not shut down the shared registry.

### Error Handling
- **ShellError.failed** - Contains program path, exit code, and combined stdout/stderr output
- Both stdout and stderr are captured to a single stream and trimmed
- Async execution throws `CancellationError` for task cancellation
- After `ChildProcesses.terminateAll(gracePeriod:)` begins, all new production shell launches throw `CancellationError`, including `runAndPrint`

## Development Commands

### Building and Testing
```bash
# Build the package
swift build

# Run all tests
swift test

# Run tests for a specific suite — the filter matches the type name, not the @Test description
swift test --filter "NnShellTests"
swift test --filter "MockShellTests"
swift test --filter "ShellErrorTests"
```

A filter that matches nothing runs 0 tests and still **exits 0**, so a typo reads as a green run.
Check the reported test count.

### Test Structure
Tests use Swift Testing framework (not XCTest) with the following patterns:
- `@Test("description")` for individual tests
- Plain structs group the tests (`struct MockShellTests { ... }`) — no `@Suite` attribute is used
- `#expect()` for assertions
- `#expect(throws: ErrorType.self)` for error testing

## Testing Strategy

### MockShell Features (v2.0.0)
The MockShell provides comprehensive testing capabilities:
- **Command Recording** - All executed commands are stored in `executedCommands` array; recording and result consumption happen under one lock so the Nth recorded command receives the Nth FIFO result even with concurrent callers
- **Result Strategies**:
  - Array-based: Predefined results returned in FIFO order via `results` parameter
  - Command-based: Specific results mapped to commands using `MockCommand` instances
- **Error Simulation** - Set `shouldThrowErrorOnFinal: true` to simulate failures when results exhausted
- **runAndPrint Support** - Both `runAndPrint(_:args:)` and `runAndPrint(bash:)` methods record commands and consume results without returning output
- **Convenience Methods** - `executedCommand(containing:)`, `commandCount(containing:)`, etc.

### Test File Organization
All test files live in `Tests/NnShellKitTests/`:
- `NnShellTests.swift` - Tests for the production NnShell implementation including process-group timeouts and shutdown of captured and streaming commands
- `AsyncNnShellTests.swift` - Tests for async execution, errors, cancellation, and child-process shutdown
- `ProcessGroupRegistryTests.swift` - Tests for shutdown escalation, tracking, and launch/shutdown races
- `MockShellTests.swift` - Tests for MockShell testing utility, result strategies, and concurrent command/result pairing
- `MockAsyncShellTests.swift` - Tests for async mock results, recording, and cancellation before execution
- `ShellErrorTests.swift` - Tests for error handling and ShellError enum

`MockShell`, `MockAsyncShell`, and `MockCommand` are **not** test files — they ship to consumers from
`Sources/NnShellTesting/`.

## Code Conventions

### File Headers
All Swift files use "Nikolai Nobadi" in the "Created by" comment header.

### API Design
- Both `run()` and `bash()` methods are marked `@discardableResult`
- Combined stdout/stderr output with automatic trimming
- `Shell` and `AsyncShell` enable dependency injection for testing and require conforming types to be `Sendable`

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
    MockCommand(command: "git status", output: "main branch"),
    MockCommand(command: "git push", error: .failed(program: "/bin/bash", code: 1, output: "error"))
])
try mock.bash("git status")  // Returns "main branch"
```

## Key Implementation Details (v2.0.0)

- `bash()` method delegates to `run("/bin/bash", args: ["-c", command])`
- `runAndPrint(bash:)` method delegates to `runAndPrint("/bin/bash", args: ["-c", command])`
- NnShell supports configurable timeouts to prevent hanging commands (not applicable to `runAndPrint`). A timeout signals the process group when the launched process leads it, otherwise the process itself, with `SIGTERM` and a `SIGKILL` fallback after one second, then throws `ShellError.failed` with code 124
- Output is read asynchronously to prevent truncation issues
- `runAndPrint` methods stream output directly to console using `FileHandle.standardOutput` and `FileHandle.standardError`
- `runAndPrint` methods wait indefinitely for process completion (no timeout support)
- AsyncNnShell cancellation signals the process group when the launched process leads it, otherwise the process itself, with `SIGTERM` and a `SIGKILL` fallback after one second. Processes that escape the group are outside that signal target; cancellation bounds the output-drain wait to one second.
- MockShell uses strategy pattern for flexible result handling; copies share recordings, result consumption, and resets
- MockShell `runAndPrint` methods record commands and consume results from the strategy without returning output
- MockShell handles empty arguments correctly (no trailing space)
- Error tests should expect `NSError` for missing executables, `ShellError` for command failures
- Output expectations should account for shell behavior (e.g., echo stripping outer quotes)

## Public API Expectations

- Clear, well-documented public interfaces
- Semantic versioning for breaking changes
- Comprehensive examples in documentation

## Package Testing

- Behavior-driven unit tests (Swift Testing preferred)
- Use `makeSUT` pattern for test organization
- Track memory leaks with `trackForMemoryLeaks`
- Type-safe assertions (`#expect`, `#require`)
- Use `waitUntil` for async/reactive testing

## CI/CD

- GitHub Actions workflow runs tests on every push and pull request
- Tests run on macOS latest with Swift 5.5
