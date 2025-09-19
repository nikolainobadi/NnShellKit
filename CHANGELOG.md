# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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