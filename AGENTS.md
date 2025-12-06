# Repository Guidelines

## Project Structure & Module Organization
- `Package.swift` declares two libraries: `NnShellKit` (production shell execution) and `NnShellTesting` (testing utilities), plus the `NnShellKitTests` suite.
- `Sources/NnShellKit/` holds the public API (`Shell`, `NnShell`, `ShellError`) for running commands and handling timeouts.
- `Sources/NnShellTesting/` provides deterministic helpers (`MockShell`, `MockCommand`) for unit tests and examples.
- `Tests/NnShellKitTests/` contains XCTest coverage; mirror new features with matching test files and method names.

## Build, Test, and Development Commands
- `swift package resolve` ensures dependencies are ready for Swift 5.5+.
- `swift build` compiles both libraries; prefer absolute program paths in examples to match runtime behavior.
- `swift test` runs the XCTest suite; append `--enable-code-coverage` when inspecting coverage locally.
- CI runs via GitHub Actions (`ci.yml` badge in `README.md`); keep CI green by matching its target versions.

## Coding Style & Naming Conventions
- Use Swift defaults with 4-space indentation and `CamelCase` types/`lowerCamelCase` members; keep parameter lists on a single line when concise.
- Prefer protocol-first design for composability and mocking; keep methods small and focused on one concern.
- Prefix package-visible symbols with `Nn` when adding new core types; align with `ShellError` naming for failures.
- Add `///` documentation to public APIs; new Swift files should keep the header author as Nikolai Nobadi.

## Testing Guidelines
- XCTest only; place specs under `Tests/NnShellKitTests/` with files named after the type under test.
- Name tests `testMethod_condition` and cover both success and failure branches (non-zero exits, timeout handling, streaming vs captured output).
- Use `NnShellTesting.MockShell`/`MockCommand` for deterministic outputs instead of hitting the real shell.

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
