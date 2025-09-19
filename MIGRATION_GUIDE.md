# MockShell to ConfigurableMockShell Migration Guide

This guide helps AI assistants and developers migrate from the deprecated `MockShell` to the new `ConfigurableMockShell`.

## Quick Reference

| MockShell Pattern | ConfigurableMockShell Replacement |
|-------------------|-----------------------------------|
| `MockShell()` | `ConfigurableMockShell()` |
| `MockShell(results: [...])` | `ConfigurableMockShell(commands: [...], mode: .ordered)` |
| `MockShell(resultMap: [...])` | `ConfigurableMockShell(commands: [...], mode: .mapped)` |
| `MockShell(shouldThrowError: true)` | `ConfigurableMockShell(commands: [MockCommand(command: "...", failWithCode: 1)])` |

## Migration Patterns

### 1. Empty MockShell

**Before:**
```swift
let mock = MockShell()
```

**After:**
```swift
let mock = ConfigurableMockShell()
```

### 2. Array-Based Results (Sequential)

When MockShell uses an array of results that are consumed in order, migrate to ConfigurableMockShell with ordered mode.

**Before:**
```swift
let mock = MockShell(results: ["result1", "result2", "result3"])
// Commands can be anything - results are consumed in FIFO order
let output1 = try mock.bash("any command")     // returns "result1"
let output2 = try mock.bash("different cmd")   // returns "result2"
let output3 = try mock.run("/bin/ls", args: []) // returns "result3"
```

**After:**
```swift
let mock = ConfigurableMockShell(commands: [
    MockCommand(command: "any command", result: "result1"),
    MockCommand(command: "different cmd", result: "result2"),
    MockCommand(command: "/bin/ls", result: "result3")
], mode: .ordered)
// Commands must match exactly in sequence
let output1 = try mock.bash("any command")     // returns "result1"
let output2 = try mock.bash("different cmd")   // returns "result2"
let output3 = try mock.run("/bin/ls", args: []) // returns "result3"
```

**Important:** In ordered mode, you must know the exact commands that will be executed. If you don't care about command matching and just want to return results in order regardless of the command, you may need to inspect the test to determine what commands are actually being executed.

### 3. Dictionary-Based Results (Mapped)

When MockShell uses a resultMap dictionary, migrate to ConfigurableMockShell with mapped mode.

**Before:**
```swift
let mock = MockShell(resultMap: [
    "git status": "clean",
    "git branch": "main\nfeature",
    "pwd": "/home/user"
])
// Commands can be executed in any order
let status = try mock.bash("git status")  // returns "clean"
let pwd = try mock.bash("pwd")           // returns "/home/user"
let branch = try mock.bash("git branch")  // returns "main\nfeature"
```

**After:**
```swift
let mock = ConfigurableMockShell(commands: [
    MockCommand(command: "git status", result: "clean"),
    MockCommand(command: "git branch", result: "main\nfeature"),
    MockCommand(command: "pwd", result: "/home/user")
], mode: .mapped)
// Commands can be executed in any order
let status = try mock.bash("git status")  // returns "clean"
let pwd = try mock.bash("pwd")           // returns "/home/user"
let branch = try mock.bash("git branch")  // returns "main\nfeature"
```

### 4. Global Error Mode

When MockShell throws errors for all commands.

**Before:**
```swift
let mock = MockShell(shouldThrowError: true)
try mock.bash("any command") // throws ShellError.failed
```

**After (Option 1 - Specific commands):**
```swift
let mock = ConfigurableMockShell(commands: [
    MockCommand(command: "any command", failWithCode: 1)
])
try mock.bash("any command") // throws ShellError.failed
```

**After (Option 2 - Multiple commands all failing):**
```swift
let mock = ConfigurableMockShell(commands: [
    MockCommand(command: "cmd1", failWithCode: 1),
    MockCommand(command: "cmd2", failWithCode: 1),
    MockCommand(command: "cmd3", failWithCode: 1)
], mode: .ordered)
```

### 5. Mixed Results and Errors

**Before (not directly possible with MockShell):**
```swift
// MockShell couldn't mix successes and failures
let mock = MockShell(results: ["success1", "success2"])
// OR
let mock = MockShell(shouldThrowError: true) // all fail
```

**After (now possible):**
```swift
let mock = ConfigurableMockShell(commands: [
    MockCommand(command: "git status", result: "clean"),
    MockCommand(command: "git push", failWithCode: 128, output: "auth failed"),
    MockCommand(command: "git pull", result: "Already up to date")
], mode: .ordered)
```

### 6. Reset Methods

**Before:**
```swift
let mock = MockShell()
mock.reset(results: ["new1", "new2"])
// or
mock.reset(resultMap: ["cmd": "result"])
```

**After:**
```swift
let mock = ConfigurableMockShell()
mock.reset(commands: [
    MockCommand(command: "cmd1", result: "new1"),
    MockCommand(command: "cmd2", result: "new2")
])
```

### 7. Convenience Methods (No Change)

These methods work identically:
```swift
// Both MockShell and ConfigurableMockShell support:
mock.executedCommands
mock.wasUnused
mock.executedCommand(containing: "git")
mock.commandCount(containing: "git")
mock.verifyCommand(at: 0, equals: "git status")
```

### 8. New Capabilities

ConfigurableMockShell adds new features not available in MockShell:

```swift
// Check if all expected commands were executed (ordered mode)
mock.allCommandsExecuted

// Get remaining command count (ordered mode)
mock.remainingCommandCount

// Mix success and failure in the same test
let mock = ConfigurableMockShell(commands: [
    MockCommand(command: "succeed", result: "ok"),
    MockCommand(command: "fail", error: ShellError.failed(program: "test", code: 1, output: "error"))
])
```

## Migration Algorithm for AI

When migrating a test file:

1. **Identify MockShell usage pattern:**
   - Look for `MockShell()` instantiation
   - Check constructor parameters: `results`, `resultMap`, or `shouldThrowError`

2. **Determine command execution pattern:**
   - For `results` array: Look at test to find actual commands being executed
   - For `resultMap`: Commands are explicit in the dictionary keys
   - For error mode: Identify which commands are expected to fail

3. **Choose appropriate mode:**
   - Use `.ordered` when migrating from `results` array OR when test expects specific command sequence
   - Use `.mapped` when migrating from `resultMap` OR when commands can execute in any order

4. **Construct MockCommand array:**
   - For each expected command, create a `MockCommand`
   - Use `MockCommand(command:result:)` for success
   - Use `MockCommand(command:failWithCode:output:)` for failure
   - Use `MockCommand(command:error:)` for specific errors

5. **Replace instantiation:**
   ```swift
   // Pattern:
   let mock = MockShell(OLD_PARAMS)
   // Becomes:
   let mock = ConfigurableMockShell(commands: [COMMANDS], mode: MODE)
   ```

6. **Update reset calls:**
   - Replace `reset(results:)` with `reset(commands:)` using ordered MockCommands
   - Replace `reset(resultMap:)` with `reset(commands:)` using mapped MockCommands

7. **Keep convenience methods unchanged:**
   - `executedCommands`, `wasUnused`, etc. work identically

## Complex Migration Example

**Before:**
```swift
func testGitWorkflow() throws {
    // Test part 1: Success flow
    let mock = MockShell(resultMap: [
        "git status": "modified: file.txt",
        "git add .": "",
        "git commit -m 'test'": "1 file changed"
    ])

    try mock.bash("git status")
    try mock.bash("git add .")
    try mock.bash("git commit -m 'test'")

    // Test part 2: Error flow
    mock.reset(resultMap: ["git push": ""])
    mock = MockShell(shouldThrowError: true) // This doesn't work well
}
```

**After:**
```swift
func testGitWorkflow() throws {
    // Test part 1: Success flow
    let mock = ConfigurableMockShell(commands: [
        MockCommand(command: "git status", result: "modified: file.txt"),
        MockCommand(command: "git add .", result: ""),
        MockCommand(command: "git commit -m 'test'", result: "1 file changed")
    ], mode: .mapped)

    try mock.bash("git status")
    try mock.bash("git add .")
    try mock.bash("git commit -m 'test'")

    // Test part 2: Error flow (now possible in single mock!)
    mock.reset(commands: [
        MockCommand(command: "git push", failWithCode: 128, output: "Authentication failed")
    ])

    // Or even better, include all in one:
    let mock2 = ConfigurableMockShell(commands: [
        MockCommand(command: "git status", result: "modified: file.txt"),
        MockCommand(command: "git add .", result: ""),
        MockCommand(command: "git commit -m 'test'", result: "1 file changed"),
        MockCommand(command: "git push", failWithCode: 128, output: "Authentication failed")
    ], mode: .ordered)
}
```

## Validation Checklist

After migration, verify:
- [ ] All MockShell imports are replaced with ConfigurableMockShell
- [ ] Commands in ordered mode match the exact execution sequence
- [ ] Commands in mapped mode include all possible commands that might be called
- [ ] Error scenarios use appropriate MockCommand error constructors
- [ ] Reset methods use the new `reset(commands:)` signature
- [ ] Tests still pass with the same behavior