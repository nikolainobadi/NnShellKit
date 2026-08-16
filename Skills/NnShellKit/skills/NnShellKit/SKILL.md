---
name: NnShellKit
description: NnShellKit Swift API reference for shell command execution. USE WHEN importing NnShellKit, executing shell commands from Swift, using Shell protocol, NnShell, MockShell, bash commands, run process, runAndPrint, shell error handling.
user-invocable: true
---

# NnShellKit

Lightweight Swift package for executing shell commands with proper error handling and test support.

**Dependency:** `https://github.com/nikolainobadi/NnShellKit.git`
**Products:** `NnShellKit` (production), `NnShellTesting` (test helpers)
**Platforms:** macOS | **Swift tools:** 5.5
<!-- package_path: . --> <!-- this skill lives inside the NnShellKit repo it documents -->

> This skill lives in the NnShellKit repo under `Skills/NnShellKit/`. Any PR changing the
> package's public API must update it in the same change.

## Context Files

| File | Purpose | Load When |
|------|---------|-----------|
| `ApiReference.md` | Shell protocol, NnShell, ShellError — full API with behavioral docs | Implementing shell commands, choosing between run/bash/runAndPrint, handling errors |
| `TestingReference.md` | MockShell, MockCommand — test helpers with complete examples | Writing tests for code that uses Shell protocol |

## Quick Reference

### Production
- **Shell** — Protocol defining `bash()`, `run()`, `runAndPrint()`, `runAndPrint(bash:)` methods
- **NnShell** — Production implementation using Foundation Process with optional timeout
- **ShellError** — Error enum with `.failed(program:code:output:)` case
- `bash()` delegates to `run("/bin/bash", args: ["-c", command])` — use for pipes, redirects, env vars
- `run()` executes programs directly — use for discrete arguments without shell interpretation

### Testing
- **MockShell** — Open class conforming to Shell with array-based or command-specific result strategies
- **MockCommand** — Defines specific command-to-result mappings with `.success`/`.failure` outcomes
- Use `executedCommands` array and convenience methods to verify command execution

## Examples

- "How do I run a bash command from Swift?" -> Loads ApiReference.md
- "What's the difference between run and bash?" -> Loads ApiReference.md
- "How do I mock shell commands in tests?" -> Loads TestingReference.md
