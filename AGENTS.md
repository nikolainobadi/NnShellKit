# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` declares two libraries: `NnShellKit` (production shell execution) and `NnShellTesting` (testing utilities), plus the `NnShellKitTests` suite.
- `Sources/NnShellKit/` holds the public API (`Shell`, `NnShell`, `AsyncShell`, `AsyncNnShell`, `ShellError`, `ChildProcesses`) for synchronous execution with timeouts and cancellable async execution. Both shell protocols require `Sendable` conformance.
- `ChildProcesses.terminateAll(gracePeriod:)` stops tracked production shell processes, including streaming commands, and permanently refuses new launches with `CancellationError`. It blocks while sending `SIGTERM` and escalating to `SIGKILL` after the grace period; it targets the process group when the launched process leads it, otherwise the process itself. Processes that escape the group are outside its signal target. This is for application exit; there is no reset.
- `NnShell` timeouts use the same signal targeting with a one-second grace period and throw `ShellError.failed` with code 124; `runAndPrint` has no timeout.
- `Sources/NnShellTesting/` provides deterministic helpers (`MockShell`, `MockAsyncShell`, `MockCommand`) for unit tests and examples. `MockShell` is a `Sendable` struct whose copies share command recordings and result state under a lock; it cannot be subclassed.
- `NnShellTesting` re-exports `NnShellKit`, so `import NnShellTesting` also exposes the production public API. Internal production types still require `@testable import NnShellKit`.
- `Tests/NnShellKitTests/` contains XCTest coverage; mirror new features with matching test files and method names.

## Build, Test, and Development Commands
- `swift package resolve` ensures dependencies are ready; `Package.swift` requires Swift tools 5.9+ and macOS 13+.
- `swift build` compiles both libraries; prefer absolute program paths in examples to match runtime behavior.
- `swift test` runs the XCTest suite; append `--enable-code-coverage` when inspecting coverage locally.
- CI runs via GitHub Actions (`ci.yml` badge in `README.md`) on `macos-26` with the image's default Xcode and no explicit Swift version pin; keep CI green by matching its target versions.

## Coding Style & Naming Conventions
- Use Swift defaults with 4-space indentation and `CamelCase` types/`lowerCamelCase` members; keep parameter lists on a single line when concise.
- Prefer protocol-first design for composability and mocking; keep methods small and focused on one concern.
- Prefix package-visible symbols with `Nn` when adding new core types; align with `ShellError` naming for failures.
- Add `///` documentation to public APIs; new Swift files should keep the header author as Nikolai Nobadi.

## Testing Guidelines
- XCTest only; place specs under `Tests/NnShellKitTests/` with files named after the type under test.
- Name tests `testMethod_condition` and cover both success and failure branches (non-zero exits, timeout handling, streaming vs captured output).
- Use `NnShellTesting.MockShell`/`MockCommand` for deterministic outputs instead of hitting the real shell.
- Shutdown tests use isolated `ProcessGroupRegistry` instances via the internal `NnShell(timeout:registry:)` and `AsyncNnShell(registry:)` initializers; shutting down the shared registry would permanently prevent other tests from launching processes.
- The production shell test factories return `(sut:, registry:)` with a fresh registry: `NnShellTests.makeSUT(timeout:)` and `AsyncNnShellTests.makeSUT()`.
- `ProcessProbe` in `ProcessTestHelpers.swift` provides shared synchronous and async polling for process IDs and process death; a missing PID throws `ProcessProbe.ProcessIDTimeout`.

## Commit & Pull Request Guidelines
- Commit messages are short and imperative, matching history (`update readme`, `add timeout guard`).
- PRs should summarize intent, link issues, call out API or behavior changes, and note test/coverage status.
- Keep diffs focused; update `README.md` or `CHANGELOG.md` when surface area changes.

## Scripts & Tooling Notes
- New shell scripts should target zsh, start with `set -e`, remain idempotent, and emit colored INFO/SUCCESS/WARNING/ERROR messages.
- Source shared helpers from `~/.config/sharedAIConfig/` when available and back up existing configs with timestamps before overwriting.
- Use absolute program paths when invoking processes to align with `NnShell` expectations and handle non-zero exits via `ShellError`.

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

## Imports
- Ask before reading `~/.codex/guidelines/shared/shared-formatting-codex.md` when working on Swift code.
- Ask before reading `~/.codex/guidelines/testing/base_unit_testing_guidelines.md` when discussing or editing tests.

## Resource Requests
- Ask before reading `~/.codex/guidelines/shared/shared-formatting-codex.md` when working on Swift code.
- Ask before reading `~/.codex/guidelines/testing/base_unit_testing_guidelines.md` when discussing or editing tests.
