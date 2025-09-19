//
//  ConfigurableMockShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
@testable import NnShellKit

@Suite("ConfigurableMockShell Tests")
struct ConfigurableMockShellTests {

    // MARK: - MockCommand Tests

    @Test("MockCommand success initialization")
    func mockCommandSuccessInit() {
        let cmd = MockCommand(command: "git status", result: "clean")
        #expect(cmd.command == "git status")
        #expect(cmd.result == "clean")
        #expect(cmd.shouldThrow == false)
        #expect(cmd.error == nil)
    }

    @Test("MockCommand error initialization")
    func mockCommandErrorInit() {
        let error = ShellError.failed(program: "git", code: 128, output: "auth failed")
        let cmd = MockCommand(command: "git push", error: error)
        #expect(cmd.command == "git push")
        #expect(cmd.result == "")
        #expect(cmd.shouldThrow == true)
        #expect(cmd.error != nil)
    }

    @Test("MockCommand convenience error initialization")
    func mockCommandConvenienceErrorInit() {
        let cmd = MockCommand(command: "test", failWithCode: 42, output: "custom error")
        #expect(cmd.command == "test")
        #expect(cmd.shouldThrow == true)
        if case .failed(_, let code, let output) = cmd.error {
            #expect(code == 42)
            #expect(output == "custom error")
        } else {
            Issue.record("Expected ShellError.failed")
        }
    }

    // MARK: - Ordered Mode Tests

    @Test("Ordered mode basic execution")
    func orderedModeBasic() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "first", result: "result1"),
            MockCommand(command: "second", result: "result2"),
            MockCommand(command: "third", result: "result3")
        ])

        #expect(try mock.bash("first") == "result1")
        #expect(try mock.bash("second") == "result2")
        #expect(try mock.bash("third") == "result3")

        #expect(mock.executedCommands.count == 3)
        #expect(mock.allCommandsExecuted == true)
        #expect(mock.remainingCommandCount == 0)
    }

    @Test("Ordered mode wrong command throws")
    func orderedModeWrongCommand() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "expected", result: "result")
        ])

        do {
            try mock.bash("wrong")
            Issue.record("Expected command mismatch error")
        } catch let error as ShellError {
            if case .failed(_, _, let output) = error {
                #expect(output.contains("Command mismatch"))
                #expect(output.contains("Expected: 'expected'"))
                #expect(output.contains("got: 'wrong'"))
            }
        }

        #expect(mock.executedCommands == ["wrong"])
    }

    @Test("Ordered mode too many commands throws")
    func orderedModeTooManyCommands() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "only", result: "one")
        ])

        _ = try mock.bash("only")

        do {
            try mock.bash("extra")
            Issue.record("Expected no more commands error")
        } catch let error as ShellError {
            if case .failed(_, _, let output) = error {
                #expect(output.contains("No more commands expected"))
            }
        }
    }

    @Test("Ordered mode with errors")
    func orderedModeWithErrors() throws {
        let customError = ShellError.failed(program: "custom", code: 99, output: "custom failure")
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "success", result: "ok"),
            MockCommand(command: "fail", error: customError),
            MockCommand(command: "after", result: "continues")
        ])

        #expect(try mock.bash("success") == "ok")

        do {
            try mock.bash("fail")
            Issue.record("Expected error to be thrown")
        } catch let error as ShellError {
            if case .failed(let prog, let code, let output) = error {
                #expect(prog == "custom")
                #expect(code == 99)
                #expect(output == "custom failure")
            }
        }

        #expect(try mock.bash("after") == "continues")
        #expect(mock.executedCommands == ["success", "fail", "after"])
    }

    // MARK: - Mapped Mode Tests

    @Test("Mapped mode any order execution")
    func mappedModeAnyOrder() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "pwd", result: "/home"),
            MockCommand(command: "ls", result: "files"),
            MockCommand(command: "echo test", result: "test")
        ], mode: .mapped)

        // Execute in different order than defined
        #expect(try mock.bash("echo test") == "test")
        #expect(try mock.bash("pwd") == "/home")
        #expect(try mock.bash("ls") == "files")

        #expect(mock.executedCommands == ["echo test", "pwd", "ls"])
    }

    @Test("Mapped mode repeated commands")
    func mappedModeRepeatedCommands() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "pwd", result: "/home")
        ], mode: .mapped)

        #expect(try mock.bash("pwd") == "/home")
        #expect(try mock.bash("pwd") == "/home")
        #expect(try mock.bash("pwd") == "/home")

        #expect(mock.commandCount(containing: "pwd") == 3)
    }

    @Test("Mapped mode unmapped commands return empty")
    func mappedModeUnmappedCommands() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "known", result: "result")
        ], mode: .mapped)

        #expect(try mock.bash("known") == "result")
        #expect(try mock.bash("unknown") == "")
        #expect(try mock.bash("also unknown") == "")

        #expect(mock.executedCommands == ["known", "unknown", "also unknown"])
    }

    @Test("Mapped mode with errors")
    func mappedModeWithErrors() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "success", result: "ok"),
            MockCommand(command: "fail", failWithCode: 127, output: "command not found")
        ], mode: .mapped)

        // Can execute in any order
        do {
            try mock.bash("fail")
            Issue.record("Expected error")
        } catch let error as ShellError {
            if case .failed(_, let code, let output) = error {
                #expect(code == 127)
                #expect(output == "command not found")
            }
        }

        #expect(try mock.bash("success") == "ok")

        // Can execute failing command again
        #expect(throws: ShellError.self) {
            try mock.bash("fail")
        }
    }

    // MARK: - Run vs Bash Tests

    @Test("Run command formatting")
    func runCommandFormatting() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "/bin/ls", result: "no args"),
            MockCommand(command: "/bin/ls -la", result: "with args"),
            MockCommand(command: "/usr/bin/git status --short", result: "multiple args")
        ])

        #expect(try mock.run("/bin/ls", args: []) == "no args")
        #expect(try mock.run("/bin/ls", args: ["-la"]) == "with args")
        #expect(try mock.run("/usr/bin/git", args: ["status", "--short"]) == "multiple args")

        #expect(mock.verifyCommand(at: 0, equals: "/bin/ls"))
        #expect(mock.verifyCommand(at: 1, equals: "/bin/ls -la"))
        #expect(mock.verifyCommand(at: 2, equals: "/usr/bin/git status --short"))
    }

    // MARK: - Convenience Methods Tests

    @Test("Reset functionality")
    func resetFunctionality() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "first", result: "result")
        ])

        _ = try mock.bash("first")
        #expect(mock.wasUnused == false)
        #expect(mock.executedCommands.count == 1)

        mock.reset(commands: [
            MockCommand(command: "new", result: "new result")
        ])

        #expect(mock.wasUnused == true)
        #expect(mock.executedCommands.count == 0)
        #expect(try mock.bash("new") == "new result")
    }

    @Test("Command verification methods")
    func commandVerificationMethods() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "git status", result: ""),
            MockCommand(command: "git add .", result: ""),
            MockCommand(command: "echo test", result: "")
        ])

        _ = try mock.bash("git status")
        _ = try mock.bash("git add .")
        _ = try mock.bash("echo test")

        #expect(mock.executedCommand(containing: "git") == true)
        #expect(mock.executedCommand(containing: "echo") == true)
        #expect(mock.executedCommand(containing: "missing") == false)

        #expect(mock.commandCount(containing: "git") == 2)
        #expect(mock.commandCount(containing: "echo") == 1)

        #expect(mock.verifyCommand(at: 0, equals: "git status"))
        #expect(mock.verifyCommand(at: 1, equals: "git add ."))
        #expect(mock.verifyCommand(at: 2, equals: "echo test"))
        #expect(mock.verifyCommand(at: 3, equals: "anything") == false)
    }

    @Test("Remaining commands tracking")
    func remainingCommandsTracking() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "one", result: "1"),
            MockCommand(command: "two", result: "2"),
            MockCommand(command: "three", result: "3")
        ])

        #expect(mock.remainingCommandCount == 3)
        #expect(mock.allCommandsExecuted == false)

        _ = try mock.bash("one")
        #expect(mock.remainingCommandCount == 2)

        _ = try mock.bash("two")
        #expect(mock.remainingCommandCount == 1)

        _ = try mock.bash("three")
        #expect(mock.remainingCommandCount == 0)
        #expect(mock.allCommandsExecuted == true)
    }

    @Test("Mapped mode always shows all commands executed")
    func mappedModeAlwaysAllExecuted() {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "any", result: "result")
        ], mode: .mapped)

        #expect(mock.allCommandsExecuted == true)
        #expect(mock.remainingCommandCount == 0)
    }

    // MARK: - Edge Cases

    @Test("Empty command list")
    func emptyCommandList() throws {
        let orderedMock = ConfigurableMockShell(commands: [], mode: .ordered)
        let mappedMock = ConfigurableMockShell(commands: [], mode: .mapped)

        // Ordered mode should throw
        #expect(throws: ShellError.self) {
            try orderedMock.bash("any")
        }

        // Mapped mode should return empty
        #expect(try mappedMock.bash("any") == "")
    }

    @Test("Arguments with special characters")
    func argumentsWithSpecialCharacters() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "/bin/echo 'hello world' \"test\"", result: "output")
        ])

        #expect(try mock.run("/bin/echo", args: ["'hello world'", "\"test\""]) == "output")
    }

    @Test("Default error behavior")
    func defaultErrorBehavior() throws {
        let mock = ConfigurableMockShell(commands: [
            MockCommand(command: "test", failWithCode: 1)
        ])

        do {
            try mock.bash("test")
            Issue.record("Expected default error")
        } catch let error as ShellError {
            if case .failed(_, let code, let output) = error {
                #expect(code == 1)
                #expect(output == "Mock command failed")
            }
        }
    }
}