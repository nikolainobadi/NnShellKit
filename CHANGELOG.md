# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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