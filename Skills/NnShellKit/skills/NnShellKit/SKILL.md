---
name: NnShellKit
description: NnShellKit Swift API reference for shell command execution. USE WHEN importing NnShellKit, executing shell commands from Swift, using Shell or AsyncShell protocols, NnShell, AsyncNnShell, MockShell, MockAsyncShell, ChildProcesses, process shutdown, bash commands, run process, runAndPrint, shell error handling.
user-invocable: true
---

# NnShellKit

Lightweight Swift package for executing shell commands with proper error handling and test support.

**Dependency:** `https://github.com/nikolainobadi/NnShellKit.git`
**Products:** `NnShellKit` (production), `NnShellTesting` (test helpers)
**Platforms:** macOS 13+ | **Swift tools:** 5.9
<!-- package_path: . --> <!-- this skill lives inside the NnShellKit repo it documents -->

> This skill lives in the NnShellKit repo under `Skills/NnShellKit/`. Any PR changing the
> package's public API must update it in the same change.

## Context Files

| File | Purpose | Load When |
|------|---------|-----------|
| `ApiReference.md` | Shell / AsyncShell protocols, NnShell / AsyncNnShell, ChildProcesses, ShellError — full API with behavioral docs | Implementing shell commands, choosing synchronous or async execution, handling errors, cancellation, and application shutdown |
| `TestingReference.md` | MockShell, MockAsyncShell, MockCommand — test helpers with complete examples | Writing tests for code that uses Shell or AsyncShell |

## Quick Reference

### Production
- **Shell** — Sendable synchronous protocol defining `bash()`, `run()`, `runAndPrint()`, `runAndPrint(bash:)` methods
- **NnShell** — Production implementation using Foundation Process with optional timeout
- **AsyncShell** — Sendable protocol with async `bash()` and `run()` for captured output
- **AsyncNnShell** — Cancellable async implementation; no streaming methods or timeout initializer
- **ChildProcesses** — `terminateAll(gracePeriod:)` stops tracked commands at application shutdown and permanently refuses new production launches with `CancellationError`
- **ShellError** — Error enum with `.failed(program:code:output:)` case
- `bash()` delegates to `run("/bin/bash", args: ["-c", command])` — use for pipes, redirects, env vars
- `run()` executes programs directly — use for discrete arguments without shell interpretation

### Testing
- **MockShell** — Sendable struct conforming to Shell with array-based or command-specific result strategies
- **MockAsyncShell** — Sendable AsyncShell mock with the same recording and result strategies
- **MockCommand** — Defines specific command-to-result mappings with `.success`/`.failure` outcomes
- Use `executedCommands` array and convenience methods to verify command execution

## Examples

- "How do I run a bash command from Swift?" -> Loads ApiReference.md
- "What's the difference between run and bash?" -> Loads ApiReference.md
- "How do I stop child processes before my app exits?" -> Loads ApiReference.md
- "How do I mock shell commands in tests?" -> Loads TestingReference.md
