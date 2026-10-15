# NnShellKit Testing Reference

Test helpers for mocking shell command execution. Import `NnShellTesting` alongside `NnShellKit`.

---

<!-- type:MockShell -->
## Struct: MockShell

Sendable struct implementing the Shell protocol for testing. Records all executed commands and returns predefined results.

```swift
public struct MockShell: Shell, Sendable
```

### Initialization

| Initializer | Description |
|-------------|-------------|
| `init(results: [String] = [], shouldThrowErrorOnFinal: Bool = false)` | Array-based strategy — results returned in FIFO order |
| `init(commands: [MockCommand])` | Command-map strategy — results matched by exact command string |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `executedCommands` | `[String]` | All commands executed, in order (read-only) |
| `wasUnused` | `Bool` | `true` when no commands have been executed |

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `bash(_ command: String) throws` | `String` | Records command string, returns next result |
| `run(_ program: String, args: [String]) throws` | `String` | Records assembled command, returns next result |
| `runAndPrint(_ program: String, args: [String]) throws` | `Void` | Records command and consumes a result without returning |
| `runAndPrint(bash command: String) throws` | `Void` | Delegates to `runAndPrint("/bin/bash", args: ["-c", command])` |
| `reset(results: [String])` | `Void` | Resets to array strategy with `shouldThrowErrorOnFinal: false` |
| `reset(commands: [MockCommand])` | `Void` | Resets to command-map strategy |
| `executedCommand(containing: String)` | `Bool` | Whether any recorded command contains the substring |
| `commandCount(containing: String)` | `Int` | Count of recorded commands containing the substring |
| `verifyCommand(at: Int, equals: String)` | `Bool` | Whether command at index exactly matches the string |

### Copies and Concurrent Calls

Copies share result consumption and command history; resetting one copy resets all copies. Create a new `MockShell` instance when independent state is needed. Recording and result selection are atomic: the Nth recorded command receives the Nth array result even with concurrent callers. Task scheduling does not establish command order; use command mappings when responses must follow command identity.

### Command Recording Format

- `bash(_:)` records the exact command string: `"git status"`
- `run(_:args:)` records `"program arg1 arg2"` (joined with spaces): `"/bin/ls -la"`
- `run(_:args: [])` with empty args records just the program path: `"/bin/program"`
- `runAndPrint(bash:)` records `"/bin/bash -c <command>"` (differs from `bash()`!)

```swift
try mock.bash("git status")                    // records: "git status"
try mock.run("/bin/ls", args: ["-la"])          // records: "/bin/ls -la"
try mock.runAndPrint(bash: "echo hi")           // records: "/bin/bash -c echo hi"
```

### Array Strategy Behavior

- Results returned in FIFO order, shared across all four methods (`run`, `bash`, `runAndPrint` variants)
- When exhausted with `shouldThrowErrorOnFinal: false` → returns `""` indefinitely
- When exhausted with `shouldThrowErrorOnFinal: true` → throws on every subsequent call

### Command-Map Strategy Behavior

- Lookup uses exact string equality against the recorded command format
- Unmatched commands print `[MockShell] No result mapped for command: '...'` to stdout and return `""`
<!-- /type:MockShell -->

---

<!-- type:MockAsyncShell -->
## Struct: MockAsyncShell

Sendable implementation of `AsyncShell` that wraps `MockShell`, sharing its recording formats and result strategies. Copies share the wrapped mock's state.

```swift
public struct MockAsyncShell: AsyncShell, Sendable
```

### Initialization

| Initializer | Description |
|-------------|-------------|
| `init(results: [String], shouldThrowErrorOnFinal: Bool)` | FIFO results; both arguments are required, with no defaults |
| `init(commands: [MockCommand])` | Exact command-map strategy |

### Methods and Verification

- `bash(_ command: String) async throws -> String` records the exact command string.
- `run(_ program: String, args: [String]) async throws -> String` records the program and arguments joined with spaces.
- Both methods are `@discardableResult` and check task cancellation before recording or consuming a result. An already-cancelled caller receives `CancellationError`.
- Read `executedCommands` and `wasUnused`, or use `executedCommand(containing:)`, `commandCount(containing:)`, and `verifyCommand(at:equals:)` as with `MockShell`.
- There are no `reset` or `runAndPrint` methods. Create a fresh instance for an independent scenario.
- This mock resolves configured results immediately; it does not simulate a running process or process termination.

### Usage Example

```swift
import NnShellKit
import NnShellTesting

func mockBranchOutput() async throws -> String {
    let mock = MockAsyncShell(results: ["main"], shouldThrowErrorOnFinal: false)
    let shell: any AsyncShell = mock
    let output = try await shell.bash("git branch --show-current")
    assert(mock.verifyCommand(at: 0, equals: "git branch --show-current"))
    return output // "main"
}
```
<!-- /type:MockAsyncShell -->

---

<!-- type:MockCommand -->
## Struct: MockCommand

Defines a specific command behavior for the command-map strategy.

```swift
public struct MockCommand: Sendable
```

### Initialization

| Initializer | Description |
|-------------|-------------|
| `init(command: String, output: String)` | Creates a command that returns a success result |
| `init(command: String, error: ShellError)` | Creates a command that throws the given error |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `command` | `String` | The command string to match against |
| `result` | `MockResult` | The result to return when matched |
<!-- /type:MockCommand -->

---

<!-- type:MockResult -->
## Enum: MockCommand.MockResult

Result type for command-map mock behavior.

```swift
public enum MockCommand.MockResult: Sendable {
    case success(String)
    case failure(ShellError)
}
```

### Cases

| Case | Associated Values | Description |
|------|-------------------|-------------|
| `success` | `String` | Returns the associated string as output |
| `failure` | `ShellError` | Throws the associated error |
<!-- /type:MockResult -->

---

## Complete Example

```swift
import Testing
@testable import MyFeature
import NnShellTesting

struct GitManagerTests {
    @Test("Starts with no executed commands")
    func startingValues() {
        let mock = makeSUT()
        #expect(mock.wasUnused)
        #expect(mock.executedCommands.isEmpty)
    }

    @Test("Fetches branch name from git status output")
    func fetchBranch() throws {
        let mock = makeSUT(results: ["main"])
        let manager = GitManager(shell: mock)

        let branch = try manager.currentBranch()

        #expect(branch == "main")
        #expect(mock.executedCommand(containing: "branch"))
    }

    @Test("Handles command-specific success and failure")
    func commandMap() throws {
        let mock = makeSUT(commands: [
            MockCommand(command: "git status", output: "clean"),
            MockCommand(command: "git push", error: .failed(program: "/bin/bash", code: 1, output: "rejected"))
        ])
        let manager = GitManager(shell: mock)

        #expect(try manager.status() == "clean")
        #expect(throws: ShellError.self) { try manager.push() }
        #expect(mock.commandCount(containing: "git") == 2)
    }
}

// MARK: - SUT
private extension GitManagerTests {
    func makeSUT(results: [String] = [], commands: [MockCommand] = [], shouldThrowErrorOnFinal: Bool = false) -> MockShell {
        if !commands.isEmpty {
            return MockShell(commands: commands)
        }
        return MockShell(results: results, shouldThrowErrorOnFinal: shouldThrowErrorOnFinal)
    }
}
```

## Common Patterns

### Pattern: Verify command sequence

```swift
let mock = MockShell(results: ["", ""])
try mock.bash("git add .")
try mock.bash("git commit -m 'fix'")
#expect(mock.verifyCommand(at: 0, equals: "git add ."))
#expect(mock.verifyCommand(at: 1, equals: "git commit -m 'fix'"))
```

### Pattern: Simulate exhaustion error

```swift
let mock = MockShell(results: ["ok"], shouldThrowErrorOnFinal: true)
#expect(try mock.bash("first") == "ok")
#expect(throws: ShellError.self) { try mock.bash("second") }
```

### Pattern: Verify no commands executed

```swift
let mock = MockShell()
// ... perform action that should NOT execute commands
#expect(mock.wasUnused)
```

### Pattern: Reset for multi-scenario test

```swift
let mock = MockShell(results: ["initial"])
_ = try mock.bash("cmd")
mock.reset(results: ["fresh1", "fresh2"])
#expect(mock.executedCommands.isEmpty) // reset clears history
#expect(try mock.bash("cmd") == "fresh1")
```

### Pattern: Shared results across method types

```swift
// runAndPrint consumes results from the same queue
let mock = MockShell(results: ["consumed", "returned"])
try mock.runAndPrint(bash: "setup")  // consumes "consumed"
let output = try mock.bash("query")  // returns "returned"
```

---

## Best Practices

- **Inject via `Shell` protocol** — Accept `Shell` in production types, supply `MockShell` in tests. Never depend on `MockShell` directly in production code.
- **Array strategy for sequential tests, command-map for flexible tests** — Use `init(results:)` when call order is predictable. Use `init(commands:)` when you need specific responses per command regardless of order.
- **Create a new mock per test via `makeSUT`** — Prefer fresh mocks over `reset()`. The `reset()` method always sets `shouldThrowErrorOnFinal: false`, which may silently change your test's behavior.
- **Mind the recording format differences** — `bash("git status")` records `"git status"`, but `runAndPrint(bash: "git status")` records `"/bin/bash -c git status"`. Match the format in your assertions.
- **Unmatched commands in command-map print to stdout** — If a command has no mapping, MockShell logs `[MockShell] No result mapped for command: '...'` and returns `""`. Watch test output for these warnings.
- **`runAndPrint` consumes results silently** — Both `runAndPrint` variants consume a result from the array strategy without returning it. Account for this when sizing your results array.
- **MockShell is a struct** — It cannot be subclassed. For custom behavior, implement the Sendable `Shell` protocol in your own test double.
