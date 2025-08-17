//
//  MockShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
@testable import NnShellKit

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
    
    // MARK: - Error Simulation Tests
    
    @Test("Error simulation")
    func errorSimulation() throws {
        let mock = MockShell(shouldThrowError: true)
        
        do {
            try mock.bash("any command")
            Issue.record("Expected command to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/bash")
                #expect(code == 1)
                #expect(output == "Mock error")
            } else {
                Issue.record("Unexpected ShellError case")
            }
        }
    }
    
    @Test("Error simulation with run")
    func errorSimulationWithRun() throws {
        let mock = MockShell(shouldThrowError: true)
        
        do {
            try mock.run("/bin/test", args: ["arg"])
            Issue.record("Expected command to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/test")
                #expect(code == 1)
                #expect(output == "Mock error")
            } else {
                Issue.record("Unexpected ShellError case")
            }
        }
    }
    
    @Test("Error simulation still records commands")
    func errorSimulationStillRecordsCommands() {
        let mock = MockShell(shouldThrowError: true)
        
        #expect(throws: ShellError.self) {
            try mock.bash("command that fails")
        }
        #expect(mock.executedCommands.count == 1)
        #expect(mock.executedCommands[0] == "command that fails")
    }
    
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
}
