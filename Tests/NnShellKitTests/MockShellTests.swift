//
//  MockShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
import NnShellKit
import NnShellTesting

struct MockShellTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test("MockShell initialization")
    func mockShellInitialization() {
        let mock = MockShell()
        #expect(mock.executedCommands.count == 0)
        #expect(mock.wasUnused == true)
    }
    
    @Test("MockShell with results")
    func mockShellWithResults() throws {
        let mock = MockShell(results: ["result1", "result2"])
        
        let output1 = try mock.bash("command1")
        let output2 = try mock.bash("command2")
        
        #expect(output1 == "result1")
        #expect(output2 == "result2")
    }
    
    @Test("MockShell with empty results")
    func mockShellWithEmptyResults() throws {
        let mock = MockShell()
        let output = try mock.bash("test command")
        #expect(output == "")
    }
    
    // MARK: - Command Recording Tests
    
    @Test("Run command recording")
    func runCommandRecording() throws {
        let mock = MockShell()
        try mock.run("/bin/ls", args: ["-la"])
        try mock.run("/usr/bin/git", args: ["status"])
        
        #expect(mock.executedCommands.count == 2)
        #expect(mock.executedCommands[0] == "/bin/ls -la")
        #expect(mock.executedCommands[1] == "/usr/bin/git status")
        #expect(mock.wasUnused == false)
    }
    
    @Test("Bash command recording")
    func bashCommandRecording() throws {
        let mock = MockShell()
        try mock.bash("git status")
        try mock.bash("echo 'hello world'")
        
        #expect(mock.executedCommands.count == 2)
        #expect(mock.executedCommands[0] == "git status")
        #expect(mock.executedCommands[1] == "echo 'hello world'")
    }
    
    @Test("Mixed command recording")
    func mixedCommandRecording() throws {
        let mock = MockShell()
        try mock.run("/bin/echo", args: ["test"])
        try mock.bash("pwd")
        
        #expect(mock.executedCommands.count == 2)
        #expect(mock.executedCommands[0] == "/bin/echo test")
        #expect(mock.executedCommands[1] == "pwd")
    }
    
    // MARK: - Result Queue Tests
    
    @Test("Result queue consumption")
    func resultQueueConsumption() throws {
        let mock = MockShell(results: ["first", "second", "third"])
        
        #expect(try mock.bash("cmd1") == "first")
        #expect(try mock.bash("cmd2") == "second")
        #expect(try mock.bash("cmd3") == "third")
        #expect(try mock.bash("cmd4") == "") // Queue exhausted
    }
    
    @Test("Result queue with run")
    func resultQueueWithRun() throws {
        let mock = MockShell(results: ["output1", "output2"])
        
        #expect(try mock.run("/bin/test", args: ["arg"]) == "output1")
        #expect(try mock.run("/bin/test2", args: []) == "output2")
    }
    
    // MARK: - Error Simulation Test
    
    // MARK: - Reset Functionality Tests
    
    @Test("Reset")
    func reset() throws {
        let mock = MockShell()
        try mock.bash("initial command")
        mock.reset()
        
        #expect(mock.executedCommands.count == 0)
        #expect(mock.wasUnused == true)
    }
    
    @Test("Reset with new results")
    func resetWithNewResults() throws {
        let mock = MockShell()
        try mock.bash("command")
        mock.reset(results: ["new1", "new2"])
        
        #expect(mock.executedCommands.count == 0)
        #expect(try mock.bash("test") == "new1")
        #expect(try mock.bash("test") == "new2")
    }
    
    // MARK: - Convenience Method Tests
    
    @Test("Executed command containing")
    func executedCommandContaining() throws {
        let mock = MockShell()
        try mock.bash("git status")
        try mock.bash("git add .")
        try mock.bash("echo hello")
        
        #expect(mock.executedCommand(containing: "git") == true)
        #expect(mock.executedCommand(containing: "status") == true)
        #expect(mock.executedCommand(containing: "echo") == true)
        #expect(mock.executedCommand(containing: "push") == false)
    }
    
    @Test("Command count")
    func commandCount() throws {
        let mock = MockShell()
        try mock.bash("git status")
        try mock.bash("git add .")
        try mock.bash("git commit")
        try mock.bash("echo test")
        
        #expect(mock.commandCount(containing: "git") == 3)
        #expect(mock.commandCount(containing: "echo") == 1)
        #expect(mock.commandCount(containing: "missing") == 0)
    }
    
    @Test("Verify command at index")
    func verifyCommandAtIndex() throws {
        let mock = MockShell()
        try mock.bash("first command")
        try mock.bash("second command")
        
        #expect(mock.verifyCommand(at: 0, equals: "first command") == true)
        #expect(mock.verifyCommand(at: 1, equals: "second command") == true)
        #expect(mock.verifyCommand(at: 0, equals: "wrong command") == false)
        #expect(mock.verifyCommand(at: 2, equals: "out of bounds") == false)
    }
    
    @Test("Was unused")
    func wasUnused() throws {
        let mock = MockShell()
        #expect(mock.wasUnused == true)
        
        try mock.bash("any command")
        #expect(mock.wasUnused == false)
        
        mock.reset()
        #expect(mock.wasUnused == true)
    }
    
    // MARK: - Discardable Result Tests
    
    @Test("Discardable result with mock")
    func discardableResultWithMock() throws {
        let mock = MockShell(results: ["ignored"])
        
        // Should compile without warnings about unused results
        try mock.bash("command")
        try mock.run("/bin/test", args: [])
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty arguments")
    func emptyArguments() throws {
        let mock = MockShell()
        try mock.run("/bin/program", args: [])
        #expect(mock.executedCommands[0] == "/bin/program")
    }
    
    @Test("Arguments with spaces")
    func argumentsWithSpaces() throws {
        let mock = MockShell()
        try mock.run("/bin/program", args: ["arg with spaces", "another arg"])
        #expect(mock.executedCommands[0] == "/bin/program arg with spaces another arg")
    }
    
    @Test("Multiple spaces in arguments")
    func multipleSpacesInArguments() throws {
        let mock = MockShell()
        try mock.run("/bin/test", args: ["  spaced  ", "  arg  "])
        #expect(mock.executedCommands[0] == "/bin/test   spaced     arg  ")
    }
    
    // MARK: - Dictionary-Based Results Tests
    
    @Test("Dictionary-based initialization")
    func dictionaryBasedInitialization() {
        let commands = [
            MockCommand(command: "git status", output: "main\nfeature"),
            MockCommand(command: "pwd", output: "/home/user")
        ]
        let mock = MockShell(commands: commands)
        #expect(mock.executedCommands.count == 0)
        #expect(mock.wasUnused == true)
    }
    
    @Test("Dictionary-based bash commands")
    func dictionaryBasedBashCommands() throws {
        let commands = [
            MockCommand(command: "git status", output: "main\nfeature"),
            MockCommand(command: "pwd", output: "/home/user"),
            MockCommand(command: "echo hello", output: "hello")
        ]
        let mock = MockShell(commands: commands)
        
        #expect(try mock.bash("git status") == "main\nfeature")
        #expect(try mock.bash("pwd") == "/home/user")
        #expect(try mock.bash("echo hello") == "hello")
        
        #expect(mock.executedCommands.count == 3)
        #expect(mock.executedCommands[0] == "git status")
        #expect(mock.executedCommands[1] == "pwd")
        #expect(mock.executedCommands[2] == "echo hello")
    }
    
    @Test("Dictionary-based run commands")
    func dictionaryBasedRunCommands() throws {
        let commands = [
            MockCommand(command: "/bin/ls -la", output: "total 8"),
            MockCommand(command: "/usr/bin/git status", output: "clean working directory")
        ]
        let mock = MockShell(commands: commands)
        
        #expect(try mock.run("/bin/ls", args: ["-la"]) == "total 8")
        #expect(try mock.run("/usr/bin/git", args: ["status"]) == "clean working directory")
        
        #expect(mock.executedCommands.count == 2)
        #expect(mock.executedCommands[0] == "/bin/ls -la")
        #expect(mock.executedCommands[1] == "/usr/bin/git status")
    }
    
    @Test("Dictionary-based unmapped commands return empty string")
    func dictionaryBasedUnmappedCommands() throws {
        let commands = [MockCommand(command: "known command", output: "result")]
        let mock = MockShell(commands: commands)
        
        #expect(try mock.bash("known command") == "result")
        #expect(try mock.bash("unknown command") == "")
        
        #expect(mock.executedCommands.count == 2)
        #expect(mock.executedCommands[0] == "known command")
        #expect(mock.executedCommands[1] == "unknown command")
    }
    
    @Test("Dictionary-based mixed with array fallback")
    func dictionaryBasedMixedWithArrayFallback() throws {
        // Initialize with both dictionary and array results
        var mock = MockShell(commands: [MockCommand(command: "mapped", output: "from dictionary")])
        mock.reset(results: ["from array"])

        // Dictionary result should take precedence when both are available
        mock = MockShell(results: ["from array"])
        mock.reset(commands: [MockCommand(command: "mapped", output: "from dictionary")])
        
        #expect(try mock.bash("mapped") == "from dictionary")
        #expect(try mock.bash("unmapped") == "")
    }
    
    // MARK: - New Reset Method Tests
    
    @Test("Reset with dictionary results")
    func resetWithDictionaryResults() throws {
        let mock = MockShell()
        try mock.bash("initial command")

        let newCommands = [
            MockCommand(command: "test", output: "new result"),
            MockCommand(command: "other", output: "other result")
        ]
        mock.reset(commands: newCommands)
        
        #expect(mock.executedCommands.count == 0)
        #expect(try mock.bash("test") == "new result")
        #expect(try mock.bash("other") == "other result")
        #expect(try mock.bash("unmapped") == "")
    }
    
    @Test("Reset array clears dictionary")
    func resetArrayClearsDictionary() throws {
        let mock = MockShell(commands: [MockCommand(command: "test", output: "dictionary result")])
        mock.reset(results: ["array result"])
        
        #expect(try mock.bash("test") == "array result")
        #expect(try mock.bash("another") == "")
    }
    
    @Test("Reset dictionary clears array")
    func resetDictionaryClearsArray() throws {
        let mock = MockShell(results: ["array result"])
        mock.reset(commands: [MockCommand(command: "test", output: "dictionary result")])

        #expect(try mock.bash("test") == "dictionary result")
        #expect(try mock.bash("unmapped") == "")
    }

    // MARK: - Error Testing for New Features

    @Test("MockCommand with error result throws correctly")
    func mockCommandWithErrorResult() throws {
        let expectedError = ShellError.failed(program: "/bin/test", code: 42, output: "Custom error message")
        let commands = [
            MockCommand(command: "success", output: "ok"),
            MockCommand(command: "failure", error: expectedError)
        ]
        let mock = MockShell(commands: commands)

        // Success case should work normally
        #expect(try mock.bash("success") == "ok")

        // Error case should throw the specified error
        do {
            try mock.bash("failure")
            Issue.record("Expected error to be thrown")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/test")
                #expect(code == 42)
                #expect(output == "Custom error message")
            } else {
                Issue.record("Expected ShellError.failed case")
            }
        }

        #expect(mock.executedCommands.count == 2)
        #expect(mock.executedCommands[0] == "success")
        #expect(mock.executedCommands[1] == "failure")
    }

    @Test("Array results with shouldThrowErrorOnFinal true")
    func arrayResultsThrowErrorOnFinal() throws {
        let mock = MockShell(results: ["first", "second"], shouldThrowErrorOnFinal: true)

        // First two commands should return results
        #expect(try mock.bash("cmd1") == "first")
        #expect(try mock.bash("cmd2") == "second")

        // Third command should throw error since results are exhausted
        do {
            try mock.bash("cmd3")
            Issue.record("Expected error to be thrown on final command")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/bash")
                #expect(code == 1)
                #expect(output == "Mock error on final command")
            } else {
                Issue.record("Expected ShellError.failed case")
            }
        }

        #expect(mock.executedCommands.count == 3)
    }

    @Test("Array results with shouldThrowErrorOnFinal false")
    func arrayResultsReturnEmptyOnFinal() throws {
        let mock = MockShell(results: ["only"], shouldThrowErrorOnFinal: false)

        // First command should return result
        #expect(try mock.bash("cmd1") == "only")

        // Subsequent commands should return empty string
        #expect(try mock.bash("cmd2") == "")
        #expect(try mock.bash("cmd3") == "")

        #expect(mock.executedCommands.count == 3)
    }

    @Test("Mixed success and error commands in array")
    func mixedSuccessAndErrorCommands() throws {
        let error1 = ShellError.failed(program: "/usr/bin/failing", code: 1, output: "Error 1")
        let error2 = ShellError.failed(program: "/bin/bash", code: 2, output: "Error 2")

        let commands = [
            MockCommand(command: "success1", output: "result1"),
            MockCommand(command: "error1", error: error1),
            MockCommand(command: "success2", output: "result2"),
            MockCommand(command: "error2", error: error2)
        ]
        let mock = MockShell(commands: commands)

        // Test success cases
        #expect(try mock.bash("success1") == "result1")
        #expect(try mock.bash("success2") == "result2")

        // Test error cases and verify error details
        do {
            try mock.bash("error1")
            Issue.record("Expected error1 to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/usr/bin/failing")
                #expect(code == 1)
                #expect(output == "Error 1")
            }
        }

        do {
            try mock.bash("error2")
            Issue.record("Expected error2 to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/bash")
                #expect(code == 2)
                #expect(output == "Error 2")
            }
        }

        #expect(mock.executedCommands.count == 4)
    }

    @Test("Reset with commands containing errors")
    func resetWithCommandsContainingErrors() throws {
        let mock = MockShell(results: ["initial"])

        let error = ShellError.failed(program: "/bin/test", code: 1, output: "Reset error")
        let newCommands = [
            MockCommand(command: "success", output: "new success"),
            MockCommand(command: "failure", error: error)
        ]
        mock.reset(commands: newCommands)

        #expect(mock.executedCommands.count == 0) // Reset clears commands

        #expect(try mock.bash("success") == "new success")

        #expect(throws: ShellError.self) {
            try mock.bash("failure")
        }
    }
}
