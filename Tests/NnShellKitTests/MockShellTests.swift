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
    @Test("Starting values empty")
    func emptyStartingValues() {
        let sut = makeSUT()
        #expect(sut.executedCommands.count == 0)
        #expect(sut.wasUnused == true)
    }
}


// MARK: - Basic Functionality & Command Recording
extension MockShellTests {
    @Test("Returns configured results in order")
    func returnsConfiguredResultsInOrder() throws {
        let firstResult = "result1"
        let secondResult = "result2"
        let sut = makeSUT(results: [firstResult, secondResult])

        let output1 = try sut.bash("command1")
        let output2 = try sut.bash("command2")

        #expect(output1 == firstResult)
        #expect(output2 == secondResult)
    }

    @Test("Returns empty string when no results configured")
    func returnsEmptyStringWithNoResults() throws {
        let sut = makeSUT()
        let output = try sut.bash("test command")
        #expect(output == "")
    }

    @Test("Records all executed bash commands")
    func recordsExecutedBashCommands() throws {
        let firstCommand = "git status"
        let secondCommand = "echo 'hello world'"
        let sut = makeSUT()

        try sut.bash(firstCommand)
        try sut.bash(secondCommand)

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == firstCommand)
        #expect(sut.executedCommands[1] == secondCommand)
    }

    @Test("Records all executed run commands")
    func recordsExecutedRunCommands() throws {
        let sut = makeSUT()
        try sut.run("/bin/ls", args: ["-la"])
        try sut.run("/usr/bin/git", args: ["status"])

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/ls -la")
        #expect(sut.executedCommands[1] == "/usr/bin/git status")
        #expect(sut.wasUnused == false)
    }

    @Test("Records mixed bash and run commands")
    func recordsMixedCommands() throws {
        let sut = makeSUT()
        try sut.run("/bin/echo", args: ["test"])
        try sut.bash("pwd")

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/echo test")
        #expect(sut.executedCommands[1] == "pwd")
    }

    @Test("Supports discardable results")
    func supportsDiscardableResults() throws {
        let sut = makeSUT(results: ["ignored"])
        try sut.bash("command")
        try sut.run("/bin/test", args: [])
    }
}


// MARK: - Array-Based Result Strategy
extension MockShellTests {
    @Test("Consumes array results in FIFO order")
    func consumesArrayResultsInOrder() throws {
        let sut = makeSUT(results: ["first", "second", "third"])

        #expect(try sut.bash("cmd1") == "first")
        #expect(try sut.bash("cmd2") == "second")
        #expect(try sut.bash("cmd3") == "third")
        #expect(try sut.bash("cmd4") == "")
    }

    @Test("Shares result queue between bash and run commands")
    func sharesResultQueueBetweenMethods() throws {
        let sut = makeSUT(results: ["output1", "output2"])

        #expect(try sut.run("/bin/test", args: ["arg"]) == "output1")
        #expect(try sut.run("/bin/test2", args: []) == "output2")
    }

    @Test("Returns empty string when array results exhausted")
    func returnsEmptyWhenArrayExhausted() throws {
        let sut = makeSUT(results: ["only"], shouldThrowErrorOnFinal: false)

        #expect(try sut.bash("cmd1") == "only")
        #expect(try sut.bash("cmd2") == "")
        #expect(try sut.bash("cmd3") == "")
        #expect(sut.executedCommands.count == 3)
    }

    @Test("Throws error when array results exhausted and configured")
    func throwsErrorWhenArrayExhausted() throws {
        let sut = makeSUT(results: ["first", "second"], shouldThrowErrorOnFinal: true)

        #expect(try sut.bash("cmd1") == "first")
        #expect(try sut.bash("cmd2") == "second")

        do {
            try sut.bash("cmd3")
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

        #expect(sut.executedCommands.count == 3)
    }
}


// MARK: - Dictionary-Based Result Strategy
extension MockShellTests {
    @Test("Returns command-specific results from dictionary")
    func returnsCommandSpecificResults() throws {
        let commands = [
            MockCommand(command: "git status", output: "main\nfeature"),
            MockCommand(command: "pwd", output: "/home/user"),
            MockCommand(command: "echo hello", output: "hello")
        ]
        let sut = makeSUT(commands: commands)

        #expect(try sut.bash("git status") == "main\nfeature")
        #expect(try sut.bash("pwd") == "/home/user")
        #expect(try sut.bash("echo hello") == "hello")
        #expect(sut.executedCommands.count == 3)
        #expect(sut.executedCommands[0] == "git status")
        #expect(sut.executedCommands[1] == "pwd")
        #expect(sut.executedCommands[2] == "echo hello")
    }

    @Test("Matches run commands with dictionary strategy")
    func matchesRunCommandsWithDictionary() throws {
        let commands = [
            MockCommand(command: "/bin/ls -la", output: "total 8"),
            MockCommand(command: "/usr/bin/git status", output: "clean working directory")
        ]
        let sut = makeSUT(commands: commands)

        #expect(try sut.run("/bin/ls", args: ["-la"]) == "total 8")
        #expect(try sut.run("/usr/bin/git", args: ["status"]) == "clean working directory")
        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/ls -la")
        #expect(sut.executedCommands[1] == "/usr/bin/git status")
    }

    @Test("Returns empty string for unmapped commands in dictionary strategy")
    func returnsEmptyForUnmappedCommands() throws {
        let commands = [MockCommand(command: "known command", output: "result")]
        let sut = makeSUT(commands: commands)

        #expect(try sut.bash("known command") == "result")
        #expect(try sut.bash("unknown command") == "")
        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "known command")
        #expect(sut.executedCommands[1] == "unknown command")
    }

    @Test("Prefers dictionary over array when both configured")
    func prefersDictionaryOverArray() throws {
        let sut = makeSUT(results: ["from array"])
        sut.reset(commands: [MockCommand(command: "mapped", output: "from dictionary")])

        #expect(try sut.bash("mapped") == "from dictionary")
        #expect(try sut.bash("unmapped") == "")
    }
}


// MARK: - Reset & Verification
extension MockShellTests {
    @Test("Clears all state on reset")
    func clearsStateOnReset() throws {
        let sut = makeSUT()
        try sut.bash("initial command")
        sut.reset()

        #expect(sut.executedCommands.count == 0)
        #expect(sut.wasUnused == true)
    }

    @Test("Replaces results with new array on reset")
    func replacesResultsOnReset() throws {
        let sut = makeSUT()
        try sut.bash("command")
        sut.reset(results: ["new1", "new2"])

        #expect(sut.executedCommands.count == 0)
        #expect(try sut.bash("test") == "new1")
        #expect(try sut.bash("test") == "new2")
    }

    @Test("Replaces results with new commands on reset")
    func replacesCommandsOnReset() throws {
        let sut = makeSUT()
        try sut.bash("initial command")

        let newCommands = [
            MockCommand(command: "test", output: "new result"),
            MockCommand(command: "other", output: "other result")
        ]
        sut.reset(commands: newCommands)

        #expect(sut.executedCommands.count == 0)
        #expect(try sut.bash("test") == "new result")
        #expect(try sut.bash("other") == "other result")
        #expect(try sut.bash("unmapped") == "")
    }

    @Test("Array reset clears dictionary results")
    func arrayResetClearsDictionary() throws {
        let sut = makeSUT(commands: [MockCommand(command: "test", output: "dictionary result")])
        sut.reset(results: ["array result"])

        #expect(try sut.bash("test") == "array result")
        #expect(try sut.bash("another") == "")
    }

    @Test("Dictionary reset clears array results")
    func dictionaryResetClearsArray() throws {
        let sut = makeSUT(results: ["array result"])
        sut.reset(commands: [MockCommand(command: "test", output: "dictionary result")])

        #expect(try sut.bash("test") == "dictionary result")
        #expect(try sut.bash("unmapped") == "")
    }

    @Test("Finds executed commands containing substring")
    func findsCommandsContainingSubstring() throws {
        let sut = makeSUT()
        try sut.bash("git status")
        try sut.bash("git add .")
        try sut.bash("echo hello")

        #expect(sut.executedCommand(containing: "git") == true)
        #expect(sut.executedCommand(containing: "status") == true)
        #expect(sut.executedCommand(containing: "echo") == true)
        #expect(sut.executedCommand(containing: "push") == false)
    }

    @Test("Counts commands containing substring")
    func countsCommandsContainingSubstring() throws {
        let sut = makeSUT()
        try sut.bash("git status")
        try sut.bash("git add .")
        try sut.bash("git commit")
        try sut.bash("echo test")

        #expect(sut.commandCount(containing: "git") == 3)
        #expect(sut.commandCount(containing: "echo") == 1)
        #expect(sut.commandCount(containing: "missing") == 0)
    }

    @Test("Verifies command matches at specific index")
    func verifiesCommandAtIndex() throws {
        let sut = makeSUT()
        try sut.bash("first command")
        try sut.bash("second command")

        #expect(sut.verifyCommand(at: 0, equals: "first command") == true)
        #expect(sut.verifyCommand(at: 1, equals: "second command") == true)
        #expect(sut.verifyCommand(at: 0, equals: "wrong command") == false)
        #expect(sut.verifyCommand(at: 2, equals: "out of bounds") == false)
    }

    @Test("Tracks unused state correctly")
    func tracksUnusedState() throws {
        let sut = makeSUT()
        #expect(sut.wasUnused == true)

        try sut.bash("any command")
        #expect(sut.wasUnused == false)

        sut.reset()
        #expect(sut.wasUnused == true)
    }
}


// MARK: - Error Handling
extension MockShellTests {
    @Test("Throws configured error for specific command")
    func throwsConfiguredError() throws {
        let expectedError = ShellError.failed(program: "/bin/test", code: 42, output: "Custom error message")
        let commands = [
            MockCommand(command: "success", output: "ok"),
            MockCommand(command: "failure", error: expectedError)
        ]
        let sut = makeSUT(commands: commands)

        #expect(try sut.bash("success") == "ok")

        do {
            try sut.bash("failure")
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

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "success")
        #expect(sut.executedCommands[1] == "failure")
    }

    @Test("Handles multiple error commands correctly")
    func handlesMultipleErrors() throws {
        let error1 = ShellError.failed(program: "/usr/bin/failing", code: 1, output: "Error 1")
        let error2 = ShellError.failed(program: "/bin/bash", code: 2, output: "Error 2")
        let commands = [
            MockCommand(command: "success1", output: "result1"),
            MockCommand(command: "error1", error: error1),
            MockCommand(command: "success2", output: "result2"),
            MockCommand(command: "error2", error: error2)
        ]
        let sut = makeSUT(commands: commands)

        #expect(try sut.bash("success1") == "result1")
        #expect(try sut.bash("success2") == "result2")

        do {
            try sut.bash("error1")
            Issue.record("Expected error1 to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/usr/bin/failing")
                #expect(code == 1)
                #expect(output == "Error 1")
            }
        }

        do {
            try sut.bash("error2")
            Issue.record("Expected error2 to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/bash")
                #expect(code == 2)
                #expect(output == "Error 2")
            }
        }

        #expect(sut.executedCommands.count == 4)
    }

    @Test("Resets error configuration with new commands")
    func resetsErrorConfiguration() throws {
        let sut = makeSUT(results: ["initial"])
        let error = ShellError.failed(program: "/bin/test", code: 1, output: "Reset error")
        let newCommands = [
            MockCommand(command: "success", output: "new success"),
            MockCommand(command: "failure", error: error)
        ]
        sut.reset(commands: newCommands)

        #expect(sut.executedCommands.count == 0)
        #expect(try sut.bash("success") == "new success")
        #expect(throws: ShellError.self) {
            try sut.bash("failure")
        }
    }
}


// MARK: - Edge Cases
extension MockShellTests {
    @Test("Handles empty arguments correctly")
    func handlesEmptyArguments() throws {
        let sut = makeSUT()
        try sut.run("/bin/program", args: [])
        #expect(sut.executedCommands[0] == "/bin/program")
    }

    @Test("Preserves spaces in arguments")
    func preservesSpacesInArguments() throws {
        let sut = makeSUT()
        try sut.run("/bin/program", args: ["arg with spaces", "another arg"])
        #expect(sut.executedCommands[0] == "/bin/program arg with spaces another arg")
    }

    @Test("Preserves multiple spaces in arguments")
    func preservesMultipleSpaces() throws {
        let sut = makeSUT()
        try sut.run("/bin/test", args: ["  spaced  ", "  arg  "])
        #expect(sut.executedCommands[0] == "/bin/test   spaced     arg  ")
    }
}


// MARK: - SUT
private extension MockShellTests {
    func makeSUT(results: [String] = [], commands: [MockCommand] = [], shouldThrowErrorOnFinal: Bool = false) -> MockShell {
        if !commands.isEmpty {
            return .init(commands: commands)
        } else if !results.isEmpty {
            return .init(results: results, shouldThrowErrorOnFinal: shouldThrowErrorOnFinal)
        } else {
            return .init()
        }
    }
}
