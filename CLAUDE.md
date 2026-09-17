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

NnShellKit is a lightweight Swift package that provides a simple interface for executing shell commands from Swift code. It offers both direct program execution and bash command execution with proper error handling.

## Core Architecture

The package follows a protocol-oriented design with four main components:

### Shell Protocol
The central abstraction that defines four methods:
- `bash(_ command: String)` - Executes bash commands with full shell features (pipes, redirects, etc.), returns captured output
- `run(_ program: String, args: [String])` - Executes programs directly without shell interpretation, returns captured output
- `runAndPrint(_ program: String, args: [String])` - Executes programs and streams output directly to stdout/stderr (no capture)
- `runAndPrint(bash command: String)` - Executes bash commands and streams output directly to stdout/stderr (no capture)

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
- **Command Recording** - All executed commands are stored in `executedCommands` array
- **Result Strategies**:
  - Array-based: Predefined results returned in FIFO order via `results` parameter
  - Command-based: Specific results mapped to commands using `MockCommand` instances
- **Error Simulation** - Set `shouldThrowErrorOnFinal: true` to simulate failures when results exhausted
- **runAndPrint Support** - Both `runAndPrint(_:args:)` and `runAndPrint(bash:)` methods record commands and consume results without returning output
- **Convenience Methods** - `executedCommand(containing:)`, `commandCount(containing:)`, etc.

### Test File Organization
All test files live in `Tests/NnShellKitTests/`:
- `NnShellTests.swift` - Tests for the production NnShell implementation including timeout behavior
- `MockShellTests.swift` - Tests for MockShell testing utility and result strategies
- `ShellErrorTests.swift` - Tests for error handling and ShellError enum

`MockShell` and `MockCommand` are **not** test files — they ship to consumers from
`Sources/NnShellTesting/`.

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
    MockCommand(command: "git status", output: "main branch"),
    MockCommand(command: "git push", error: .failed(program: "/bin/bash", code: 1, output: "error"))
])
try mock.bash("git status")  // Returns "main branch"
```

## Key Implementation Details (v2.0.0)

- `bash()` method delegates to `run("/bin/bash", args: ["-c", command])`
- `runAndPrint(bash:)` method delegates to `runAndPrint("/bin/bash", args: ["-c", command])`
- NnShell supports configurable timeouts to prevent hanging commands (not applicable to `runAndPrint`)
- Output is read asynchronously to prevent truncation issues
- `runAndPrint` methods stream output directly to console using `FileHandle.standardOutput` and `FileHandle.standardError`
- `runAndPrint` methods wait indefinitely for process completion (no timeout support)
- MockShell uses strategy pattern for flexible result handling
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
