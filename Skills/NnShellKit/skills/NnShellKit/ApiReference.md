# NnShellKit API Reference

Shell command execution from Swift with protocol-based design, timeout support, and proper error handling.

---

<!-- type:Shell -->
## Protocol: Shell

The central abstraction for shell command execution. Depend on this protocol for testability.

```swift
public protocol Shell {
    @discardableResult func bash(_ command: String) throws -> String
    @discardableResult func run(_ program: String, args: [String]) throws -> String
    func runAndPrint(_ program: String, args: [String]) throws
    func runAndPrint(bash command: String) throws
}
```

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `bash(_ command: String)` | `String` | Executes a bash command with full shell features (pipes, redirects, env vars) |
| `run(_ program: String, args: [String])` | `String` | Executes a program directly without shell interpretation |
| `runAndPrint(_ program: String, args: [String])` | `Void` | Executes a program and streams output directly to stdout/stderr |
| `runAndPrint(bash command: String)` | `Void` | Executes a bash command and streams output directly to stdout/stderr |

### Usage Example

```swift
func deploy(using shell: Shell) throws {
    let status = try shell.bash("git status --porcelain")
    if status.isEmpty {
        try shell.runAndPrint(bash: "swift build -c release")
    }
}
```

### Shell Implementations

| Implementation | Key Difference |
|---------------|----------------|
| `NnShell` | Production — executes real processes via Foundation, supports timeout |
| `MockShell` | Testing — records commands, returns preconfigured results |

### Method Selection Guide

| Need | Use |
|:-----|:----|
| Shell features with captured output | `bash()` |
| Shell features with streamed output | `runAndPrint(bash:)` |
| Direct execution with captured output | `run()` |
| Direct execution with streamed output | `runAndPrint(_:args:)` |
| Capture output as a String | `run()` / `bash()` |
| Time-sensitive command with timeout | `run()` / `bash()` with `NnShell(timeout:)` |

### Delegation

- `bash(cmd)` delegates to `run("/bin/bash", args: ["-c", cmd])`
- `runAndPrint(bash: cmd)` delegates to `runAndPrint("/bin/bash", args: ["-c", cmd])`
<!-- /type:Shell -->

---

<!-- type:NnShell -->
## Struct: NnShell

Production implementation of the Shell protocol using Foundation's Process API.

```swift
public struct NnShell: Shell
```

### Initialization

| Initializer | Description |
|-------------|-------------|
| `init(timeout: TimeInterval? = nil)` | Creates a shell with optional timeout for `run()`/`bash()` calls |

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `timeout` | `TimeInterval?` | Optional timeout for capturing methods; `nil` means wait indefinitely |

### Usage Example

```swift
let shell = NnShell()
let output = try shell.bash("echo Hello, World!")
// output == "Hello, World!"

let timedShell = NnShell(timeout: 30)
let result = try timedShell.run("/usr/bin/git", args: ["status"])
try timedShell.runAndPrint(bash: "swift test")
```

### Output Capture

- `run()` and `bash()` merge stdout and stderr into a single `Pipe`
- Output is read asynchronously on a background `DispatchQueue` to prevent truncation
- Returned output is trimmed with `trimmingCharacters(in: .whitespacesAndNewlines)`
- Error payloads carry raw, untrimmed output

### Timeout Support

- Only `run()` and `bash()` support timeouts — `runAndPrint` variants wait indefinitely
- On timeout: sends SIGTERM, then SIGKILL if still running, throws `ShellError.failed` with exit code `124`
- Timeout output may be partial (only data read before the kill sequence)

### Error Behavior

| Scenario | Error Type | Details |
|----------|-----------|---------|
| Non-existent executable via `run()`/`bash()` | `NSError` | Foundation error propagated directly — not wrapped in ShellError |
| Non-existent executable via `runAndPrint()` | `ShellError.failed` | Wrapped with code `127`, output `"Could not execute"` |
| Non-zero exit | `ShellError.failed` | Contains program path, exit code, captured output |
| Timeout | `ShellError.failed` | Exit code `124`, partial output captured |
<!-- /type:NnShell -->

---

<!-- type:ShellError -->
## Enum: ShellError

Error type thrown when a shell command fails.

```swift
public enum ShellError: Error {
    case failed(program: String, code: Int32, output: String)
}
```

### Cases

| Case | Associated Values | Description |
|------|-------------------|-------------|
| `failed` | `program: String, code: Int32, output: String` | Command failure with the program path, exit code, and combined stdout/stderr output |

### Usage Example

```swift
do {
    try shell.bash("ls /nonexistent")
} catch let error as ShellError {
    if case .failed(let program, let code, let output) = error {
        print("'\(program)' failed with code \(code): \(output)")
        // program == "/bin/bash", code != 0
    }
}
```

### Key Details

- The `program` field for `bash()` failures is always `"/bin/bash"`, not the command string
- Exit code `124` indicates a timeout (Unix `timeout` command convention)
- Exit code `127` indicates executable not found (from `runAndPrint` only)
- `runAndPrint` failures always have `output: ""` since output is streamed, not captured
<!-- /type:ShellError -->

---

## Best Practices

- **Depend on `Shell`, not `NnShell`** — Accept the `Shell` protocol in your types for testability. Instantiate `NnShell` only at the composition root.
- **Use `bash()` for shell features, `run()` for direct execution** — `bash()` supports pipes, redirects, and globbing. `run()` avoids shell interpretation overhead and injection risks.
- **Set timeouts for untrusted commands** — `NnShell(timeout: 30)` prevents hanging. Only `run()`/`bash()` respect the timeout; `runAndPrint` waits indefinitely.
- **Stdout and stderr are merged** — Both `run()` and `bash()` combine stdout and stderr into a single output string. You cannot distinguish between them.
- **Output is auto-trimmed on success** — Trailing newlines and whitespace are stripped from successful output. Error payloads carry raw, untrimmed output.
- **Handle both `NSError` and `ShellError`** — Missing executables throw `NSError` from `run()`/`bash()` but `ShellError` from `runAndPrint()`. Catch broadly or handle both.
- **Exit code 124 = timeout** — This follows the Unix `timeout` command convention. Timeout output may be partial.
- **`@discardableResult`** — Both `run()` and `bash()` are marked `@discardableResult`. Ignore the return value when you only care about success/failure.
- **Unmatched MockShell commands log to stdout** — In command-map mode, unmatched commands print `[MockShell] No result mapped for command: '...'` and return empty string. This appears in test runner output.
