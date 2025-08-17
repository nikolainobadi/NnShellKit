//
//  NnShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
import Foundation
@testable import NnShellKit

@Suite("NnShell Tests")
struct NnShellTests {
    private let shell = NnShell()
    
    // MARK: - Successful Command Tests
    
    @Test("Run successful command")
    func runSuccessfulCommand() throws {
        let output = try shell.run("/bin/echo", args: ["Hello, World!"])
        #expect(output == "Hello, World!")
    }
    
    @Test("Run with multiple arguments")
    func runWithMultipleArguments() throws {
        let output = try shell.run("/bin/echo", args: ["-n", "No newline"])
        #expect(output == "No newline")
    }
    
    @Test("Run with empty arguments")
    func runWithEmptyArguments() throws {
        let output = try shell.run("/bin/echo", args: [])
        #expect(output == "")
    }
    
    @Test("Bash successful command")
    func bashSuccessfulCommand() throws {
        let output = try shell.bash("echo 'Hello from bash'")
        #expect(output == "Hello from bash")
    }
    
    @Test("Bash with pipe")
    func bashWithPipe() throws {
        let output = try shell.bash("echo 'line1\nline2\nline3' | head -2")
        #expect(output == "line1\nline2")
    }
    
    @Test("Bash with environment variable")
    func bashWithEnvironmentVariable() throws {
        let output = try shell.bash("echo $HOME")
        #expect(!output.isEmpty)
        #expect(output.hasPrefix("/"))
    }
    
    @Test("Bash with redirect")
    func bashWithRedirect() throws {
        let tempFile = "/tmp/nnshellkit_test_\(UUID().uuidString).txt"
        try shell.bash("echo 'test content' > \(tempFile)")
        
        let content = try shell.bash("cat \(tempFile)")
        #expect(content == "test content")
        
        // Cleanup
        try shell.bash("rm \(tempFile)")
    }
    
    @Test("Bash with command chaining")
    func bashWithCommandChaining() throws {
        let output = try shell.bash("echo 'first' && echo 'second'")
        #expect(output == "first\nsecond")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Run throws for non-existent program")
    func runThrowsForNonExistentProgram() {
        #expect(throws: (any Error).self) {
            try shell.run("/non/existent/program", args: [])
        }
    }
    
    @Test("Run throws for failing command")
    func runThrowsForFailingCommand() throws {
        #expect(throws: ShellError.self) {
            try shell.run("/bin/ls", args: ["/non/existent/directory"])
        }
    }
    
    @Test("Bash throws for failing command")
    func bashThrowsForFailingCommand() throws {
        do {
            try shell.bash("ls /non/existent/directory")
            Issue.record("Expected command to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, let output) = error {
                #expect(program == "/bin/bash")
                #expect(code != 0)
                #expect(output.contains("No such file or directory"))
            } else {
                Issue.record("Unexpected ShellError case")
            }
        }
    }
    
    @Test("Bash throws for invalid syntax")
    func bashThrowsForInvalidSyntax() throws {
        do {
            try shell.bash("echo 'unclosed quote")
            Issue.record("Expected command to throw")
        } catch let error as ShellError {
            if case .failed(let program, let code, _) = error {
                #expect(program == "/bin/bash")
                #expect(code != 0)
            } else {
                Issue.record("Unexpected ShellError case")
            }
        }
    }
    
    // MARK: - Output Trimming Tests
    
    @Test("Output preserves internal spaces")
    func outputPreservesInternalSpaces() throws {
        let output = try shell.bash("echo '  content with spaces  '")
        #expect(output == "content with spaces")
    }
    
    @Test("Newlines are trimmed")
    func newlinesAreTrimmed() throws {
        let output = try shell.bash("echo 'content'")
        #expect(output == "content")
        #expect(!output.hasSuffix("\n"))
    }
    
    // MARK: - Discardable Result Tests
    
    @Test("Discardable result can be ignored")
    func discardableResultCanBeIgnored() throws {
        // This should compile and run without warnings about unused results
        try shell.run("/bin/echo", args: ["ignored output"])
        try shell.bash("echo 'ignored bash output'")
    }
    
    // MARK: - Integration with Real System Commands
    
    @Test("Which command")
    func whichCommand() throws {
        let output = try shell.bash("which bash")
        #expect(output == "/bin/bash")
    }
}
