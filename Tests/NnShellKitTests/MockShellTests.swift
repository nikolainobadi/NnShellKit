//
//  MockShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
import NnShellTesting

struct MockShellTests {
    @Test
    func `A new mock has no recorded commands`() {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        #expect(sut.executedCommands.count == 0)
        #expect(sut.wasUnused)
    }
}

// MARK: - Basic Functionality & Command Recording
extension MockShellTests {
    @Test
    func `Returns configured results in order`() throws {
        let firstResult = "result1"
        let secondResult = "result2"
        let sut = makeSUT(results: .ordered([firstResult, secondResult], shouldThrowErrorOnFinal: false))

        let output1 = try sut.bash("command1")
        let output2 = try sut.bash("command2")

        #expect(output1 == firstResult)
        #expect(output2 == secondResult)
    }

    @Test
    func `Returns empty string when no results configured`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        let output = try sut.bash("test command")
        #expect(output == "")
    }

    @Test
    func `Records all executed bash commands`() throws {
        let firstCommand = "git status"
        let secondCommand = "echo 'hello world'"
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))

        try sut.bash(firstCommand)
        try sut.bash(secondCommand)

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == firstCommand)
        #expect(sut.executedCommands[1] == secondCommand)
    }

    @Test
    func `Records all executed run commands`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.run("/bin/ls", args: ["-la"])
        try sut.run("/usr/bin/git", args: ["status"])

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/ls -la")
        #expect(sut.executedCommands[1] == "/usr/bin/git status")
        #expect(!sut.wasUnused)
    }

    @Test
    func `Records mixed bash and run commands`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.run("/bin/echo", args: ["test"])
        try sut.bash("pwd")

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/echo test")
        #expect(sut.executedCommands[1] == "pwd")
    }

    @Test
    func `Supports discardable results`() throws {
        let sut = makeSUT(results: .ordered(["ignored"], shouldThrowErrorOnFinal: false))
        try sut.bash("command")
        try sut.run("/bin/test", args: [])
    }
}

// MARK: - Array-Based Result Strategy
extension MockShellTests {
    @Test
    func `Consumes array results in FIFO order`() throws {
        let sut = makeSUT(results: .ordered(["first", "second", "third"], shouldThrowErrorOnFinal: false))

        #expect(try sut.bash("cmd1") == "first")
        #expect(try sut.bash("cmd2") == "second")
        #expect(try sut.bash("cmd3") == "third")
        #expect(try sut.bash("cmd4") == "")
    }

    @Test
    func `Program runs consume ordered results in order`() throws {
        let sut = makeSUT(results: .ordered(["output1", "output2"], shouldThrowErrorOnFinal: false))

        #expect(try sut.run("/bin/test", args: ["arg"]) == "output1")
        #expect(try sut.run("/bin/test2", args: []) == "output2")
    }

    @Test
    func `Returns empty string when array results exhausted`() throws {
        let sut = makeSUT(results: .ordered(["only"], shouldThrowErrorOnFinal: false))

        #expect(try sut.bash("cmd1") == "only")
        #expect(try sut.bash("cmd2") == "")
        #expect(try sut.bash("cmd3") == "")
        #expect(sut.executedCommands.count == 3)
    }

    @Test
    func `Throws error when array results exhausted and configured`() throws {
        let sut = makeSUT(results: .ordered(["first", "second"], shouldThrowErrorOnFinal: true))

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
    @Test
    func `Returns the output mapped to each command`() throws {
        let commands = [
            MockCommand(command: "git status", output: "main\nfeature"),
            MockCommand(command: "pwd", output: "/home/user"),
            MockCommand(command: "echo hello", output: "hello")
        ]
        let sut = makeSUT(results: .byCommand(commands))

        #expect(try sut.bash("git status") == "main\nfeature")
        #expect(try sut.bash("pwd") == "/home/user")
        #expect(try sut.bash("echo hello") == "hello")
        #expect(sut.executedCommands.count == 3)
        #expect(sut.executedCommands[0] == "git status")
        #expect(sut.executedCommands[1] == "pwd")
        #expect(sut.executedCommands[2] == "echo hello")
    }

    @Test
    func `Matches program runs against mapped commands`() throws {
        let commands = [
            MockCommand(command: "/bin/ls -la", output: "total 8"),
            MockCommand(command: "/usr/bin/git status", output: "clean working directory")
        ]
        let sut = makeSUT(results: .byCommand(commands))

        #expect(try sut.run("/bin/ls", args: ["-la"]) == "total 8")
        #expect(try sut.run("/usr/bin/git", args: ["status"]) == "clean working directory")
        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/ls -la")
        #expect(sut.executedCommands[1] == "/usr/bin/git status")
    }

    @Test
    func `Returns an empty string for an unmapped command`() throws {
        let commands = [MockCommand(command: "known command", output: "result")]
        let sut = makeSUT(results: .byCommand(commands))

        #expect(try sut.bash("known command") == "result")
        #expect(try sut.bash("unknown command") == "")
        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "known command")
        #expect(sut.executedCommands[1] == "unknown command")
    }
}

// MARK: - Reset & Verification
extension MockShellTests {
    @Test
    func `Clears all state on reset`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.bash("initial command")
        sut.reset()

        #expect(sut.executedCommands.count == 0)
        #expect(sut.wasUnused)
    }

    @Test
    func `Replaces results with new array on reset`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.bash("command")
        sut.reset(results: ["new1", "new2"])

        #expect(sut.executedCommands.count == 0)
        #expect(try sut.bash("test") == "new1")
        #expect(try sut.bash("test") == "new2")
    }

    @Test
    func `Replaces results with new commands on reset`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
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

    @Test
    func `Resetting to ordered results discards mapped commands`() throws {
        let sut = makeSUT(results: .byCommand([MockCommand(command: "test", output: "dictionary result")]))
        sut.reset(results: ["array result"])

        #expect(try sut.bash("test") == "array result")
        #expect(try sut.bash("another") == "")
    }

    @Test
    func `Resetting to mapped commands discards ordered results`() throws {
        let sut = makeSUT(results: .ordered(["array result"], shouldThrowErrorOnFinal: false))
        sut.reset(commands: [MockCommand(command: "test", output: "dictionary result")])

        #expect(try sut.bash("test") == "dictionary result")
        #expect(try sut.bash("unmapped") == "")
    }

    @Test
    func `Finds executed commands containing substring`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.bash("git status")
        try sut.bash("git add .")
        try sut.bash("echo hello")

        #expect(sut.executedCommand(containing: "git"))
        #expect(sut.executedCommand(containing: "status"))
        #expect(sut.executedCommand(containing: "echo"))
        #expect(!sut.executedCommand(containing: "push"))
    }

    @Test
    func `Counts commands containing substring`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.bash("git status")
        try sut.bash("git add .")
        try sut.bash("git commit")
        try sut.bash("echo test")

        #expect(sut.commandCount(containing: "git") == 3)
        #expect(sut.commandCount(containing: "echo") == 1)
        #expect(sut.commandCount(containing: "missing") == 0)
    }

    @Test
    func `Verifies command matches at specific index`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.bash("first command")
        try sut.bash("second command")

        #expect(sut.verifyCommand(at: 0, equals: "first command"))
        #expect(sut.verifyCommand(at: 1, equals: "second command"))
        #expect(!sut.verifyCommand(at: 0, equals: "wrong command"))
        #expect(!sut.verifyCommand(at: 2, equals: "out of bounds"))
    }

    @Test
    func `Reports unused until a command runs and again after a reset`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        #expect(sut.wasUnused)

        try sut.bash("any command")
        #expect(!sut.wasUnused)

        sut.reset()
        #expect(sut.wasUnused)
    }
}

// MARK: - Error Handling
extension MockShellTests {
    @Test
    func `Throws configured error for specific command`() throws {
        let expectedError = ShellError.failed(program: "/bin/test", code: 42, output: "Custom error message")
        let commands = [
            MockCommand(command: "success", output: "ok"),
            MockCommand(command: "failure", error: expectedError)
        ]
        let sut = makeSUT(results: .byCommand(commands))

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

    @Test
    func `Throws each mapped command's own error`() throws {
        let error1 = ShellError.failed(program: "/usr/bin/failing", code: 1, output: "Error 1")
        let error2 = ShellError.failed(program: "/bin/bash", code: 2, output: "Error 2")
        let commands = [
            MockCommand(command: "success1", output: "result1"),
            MockCommand(command: "error1", error: error1),
            MockCommand(command: "success2", output: "result2"),
            MockCommand(command: "error2", error: error2)
        ]
        let sut = makeSUT(results: .byCommand(commands))

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

    @Test
    func `Resets error configuration with new commands`() throws {
        let sut = makeSUT(results: .ordered(["initial"], shouldThrowErrorOnFinal: false))
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
    @Test
    func `Records a program with no arguments without a trailing space`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.run("/bin/program", args: [])
        #expect(sut.executedCommands[0] == "/bin/program")
    }

    @Test
    func `Preserves spaces in arguments`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.run("/bin/program", args: ["arg with spaces", "another arg"])
        #expect(sut.executedCommands[0] == "/bin/program arg with spaces another arg")
    }

    @Test
    func `Preserves multiple spaces in arguments`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.run("/bin/test", args: ["  spaced  ", "  arg  "])
        #expect(sut.executedCommands[0] == "/bin/test   spaced     arg  ")
    }
}

// MARK: - runAndPrint Methods
extension MockShellTests {
    @Test
    func `Records streamed program and bash commands`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.runAndPrint("/bin/echo", args: ["test"])
        try sut.runAndPrint(bash: "git status")

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/echo test")
        #expect(sut.executedCommands[1] == "/bin/bash -c git status")
    }

    @Test
    func `A streamed command consumes the next ordered result`() throws {
        let sut = makeSUT(results: .ordered(["result1", "result2", "result3"], shouldThrowErrorOnFinal: false))
        try sut.runAndPrint("/bin/test", args: [])

        let output = try sut.bash("next")
        #expect(output == "result2")
    }

    @Test
    func `A streamed command throws when ordered results are exhausted and configured to throw`() throws {
        let sut = makeSUT(results: .ordered(["result1"], shouldThrowErrorOnFinal: true))
        try sut.runAndPrint("/bin/test", args: [])

        #expect(throws: ShellError.self) {
            try sut.runAndPrint("/bin/test2", args: [])
        }
    }

    @Test
    func `Records streamed commands against mapped commands`() throws {
        let commands = [
            MockCommand(command: "/bin/test arg", output: "output1"),
            MockCommand(command: "/bin/bash -c git status", output: "output2")
        ]
        let sut = makeSUT(results: .byCommand(commands))

        try sut.runAndPrint("/bin/test", args: ["arg"])
        try sut.runAndPrint(bash: "git status")

        #expect(sut.executedCommands.count == 2)
        #expect(sut.executedCommands[0] == "/bin/test arg")
        #expect(sut.executedCommands[1] == "/bin/bash -c git status")
    }

    @Test
    func `A streamed command throws its mapped error`() throws {
        let error = ShellError.failed(program: "/bin/test", code: 1, output: "error")
        let commands = [
            MockCommand(command: "/bin/test", error: error)
        ]
        let sut = makeSUT(results: .byCommand(commands))

        #expect(throws: ShellError.self) {
            try sut.runAndPrint("/bin/test", args: [])
        }
    }

    @Test
    func `Records a streamed bash command as a /bin/bash -c invocation`() throws {
        let command = "echo hello"
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.runAndPrint(bash: command)

        #expect(sut.executedCommands.count == 1)
        #expect(sut.executedCommands[0] == "/bin/bash -c \(command)")
    }

    @Test
    func `Records a streamed program with no arguments without a trailing space`() throws {
        let sut = makeSUT(results: .ordered([], shouldThrowErrorOnFinal: false))
        try sut.runAndPrint("/bin/program", args: [])

        #expect(sut.executedCommands[0] == "/bin/program")
    }

    @Test
    func `Captured and streamed commands share one ordered result queue`() throws {
        let sut = makeSUT(results: .ordered(["r1", "r2", "r3", "r4"], shouldThrowErrorOnFinal: false))

        let output1 = try sut.bash("cmd1")
        try sut.runAndPrint("/bin/test", args: [])
        let output2 = try sut.run("/bin/echo", args: ["test"])
        try sut.runAndPrint(bash: "git status")

        #expect(output1 == "r1")
        #expect(output2 == "r3")
        #expect(sut.executedCommands.count == 4)
    }
}

// MARK: - Concurrency
extension MockShellTests {
    @Test
    func `Pairs the Nth recorded command with the Nth result under concurrency`() async throws {
        let results = (0..<100).map { "r\($0)" }
        let sut = makeSUT(results: .ordered(results, shouldThrowErrorOnFinal: false))

        let outputs = await withTaskGroup(of: (String, String).self) { group in
            for index in 0..<100 {
                group.addTask {
                    let command = "c\(index)"
                    let output = (try? sut.bash(command)) ?? ""
                    return (command, output)
                }
            }

            var outputs: [String: String] = [:]
            for await (command, output) in group {
                outputs[command] = output
            }
            return outputs
        }

        #expect(sut.executedCommands.count == 100)
        for (position, command) in sut.executedCommands.enumerated() {
            let output = try #require(outputs[command])
            #expect(output == "r\(position)")
        }
    }
}

// MARK: - SUT
private extension MockShellTests {
    enum Results {
        case ordered([String], shouldThrowErrorOnFinal: Bool)
        case byCommand([MockCommand])
    }

    func makeSUT(results: Results) -> MockShell {
        switch results {
        case .ordered(let results, let shouldThrowErrorOnFinal):
            return .init(results: results, shouldThrowErrorOnFinal: shouldThrowErrorOnFinal)
        case .byCommand(let commands):
            return .init(commands: commands)
        }
    }
}
