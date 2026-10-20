# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.5.0] - 2026-10-20

### Added
- `NnShellTesting` now re-exports `NnShellKit`, so importing `NnShellTesting` also makes types such as `Shell`, `AsyncShell`, and `ShellError` available without a separate `import NnShellKit`

## [2.4.0] - 2026-10-17

### Added
- `ChildProcesses.terminateAll(gracePeriod:)` stops commands launched by `NnShell` and `AsyncNnShell`, including `runAndPrint`, by sending `SIGTERM` to their process groups and escalating to `SIGKILL` after the grace period. Call it only when your program is about to exit: it blocks during shutdown and permanently rejects new launches with `CancellationError`. Descendants that move to another process group or session are not reached

### Fixed
- `NnShell` timeouts now signal the command's process group so descendants are also stopped, allowing one second after `SIGTERM` before escalating to `SIGKILL`; timeout errors still use code `124`

## [2.3.0] - 2026-10-15

### Added
- `AsyncShell` and `AsyncNnShell` provide async `bash(_:)` and `run(_:args:)` methods with captured stdout/stderr and task cancellation support; cancellation signals the command's process group when available and throws `CancellationError`
- `MockAsyncShell` provides queued or command-mapped results and command recording for async tests, rejecting calls from already-cancelled tasks without recording them
- `ShellError`, `MockCommand`, and `MockCommand.MockResult` now conform to `Sendable`

### Changed
- **BREAKING**: The package now requires Swift 5.9 and macOS 13 or later; update your toolchain and macOS deployment target before upgrading
- **BREAKING**: `Shell` now inherits `Sendable`; update custom conforming types to satisfy Swift's sendability requirements
- **BREAKING**: `MockShell` is now a `Sendable` struct instead of an open class; replace subclasses with custom `Shell` implementations that compose a `MockShell`. Copies share command recordings and queued results

### Fixed
- `MockShell` now safely pairs recorded commands with queued results during concurrent calls
- Prevent concurrent access to `NnShell`'s captured output buffer when collecting timeout errors

## [2.2.1] - 2026-08-16

Documentation and tooling release. No public API changes.

### Added
- The `NnShellKit` skill now lives in this repo at `Skills/NnShellKit`, so the API reference changes in the same PR as the API it documents. It is published through the `nn-swift-skills` marketplace, pinned to this tag
- `.github/workflows/skill-docs.yml` fails any PR that changes a `public`/`open`/`package` declaration under `Sources/` without touching `Skills/`. Waive with the `skip-skill-check` label when a PR changes no documented behavior
- `.github/workflows/skill-ref-bump.yml` bumps the marketplace's pinned `ref` on tag push, so released documentation always matches a shipped version

### Changed
- Point the README at the bundled skill as the authoritative API reference for symbols the README does not cover
- Correct the `MockCommand` examples in `CLAUDE.md`, which used a `result:` parameter that is not part of the API — the initializers are `init(command:output:)` and `init(command:error:)`
- Correct the `swift test --filter` examples in `CLAUDE.md`, which named suites that match nothing and therefore ran zero tests while exiting 0

## [2.2.0] - 2025-12-05

### Changed
- MockShell class is now `open` and can be subclassed for custom testing implementations
- MockShell internal strategy and helper methods are now accessible to subclasses

## [2.1.0] - 2025-11-21

### Added
- `runAndPrint(_:args:)` method to Shell protocol for executing programs with real-time output streaming to stdout/stderr
- `runAndPrint(bash:)` method to Shell protocol for executing bash commands with real-time output streaming to stdout/stderr

### Changed
- MockShell and MockCommand moved to separate `NnShellTesting` library for cleaner dependency separation

## [2.0.0] - 2025-09-19

### Added
- Timeout support for NnShell to prevent command hangs
- Command-specific result mapping for MockShell using new MockCommand type
- GitHub Actions CI workflow for automated testing

### Changed
- **BREAKING**: MockShell initializer parameter renamed from `shouldThrowError` to `shouldThrowErrorOnFinal` with different semantics
- MockShell refactored with strategy pattern for more flexible result handling

### Fixed
- Shell output truncation issue by reading process output asynchronously

## [1.1.0] - 2025-08-21

### Changed
- Removed 'final' keyword from MockShell class to allow clients to extend and subclass it for testing purposes

## [1.0.0] - 2025-08-16

### Added
- Initial release of NnShellKit Swift package
- Shell protocol defining interface for executing shell commands
- NnShell implementation for production use with Foundation's Process API
- MockShell implementation for testing with command recording and result queuing
- Comprehensive error handling with ShellError enum
- Support for both bash command execution and direct program execution
- Full test coverage using Swift Testing framework
- Documentation with inline examples and usage guidelines