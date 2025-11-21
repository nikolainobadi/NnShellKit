//
//  NnShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
import Foundation
@testable import NnShellKit

struct NnShellTests {
    private let shell = NnShell()
}


// MARK: - Successful Command Tests
extension NnShellTests {
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
}


// MARK: - Error Handling Tests
extension NnShellTests {
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
}


// MARK: - Output Trimming Tests
extension NnShellTests {
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
}
    

// MARK: - Asynchronous Output Reading Tests
extension NnShellTests {
    @Test("Large output is not truncated")
    func largeOutputIsNotTruncated() throws {
        // Generate a large output to test async reading prevents truncation
        let expectedLines = 1000
        let command = "for i in {1..\(expectedLines)}; do echo \"Line $i\"; done"
        let output = try shell.bash(command)
        
        let lines = output.components(separatedBy: .newlines)
        #expect(lines.count == expectedLines)
        #expect(lines.first == "Line 1")
        #expect(lines.last == "Line \(expectedLines)")
    }
    
    @Test("Rapid output chunks are captured completely")
    func rapidOutputChunksAreCapturedCompletely() throws {
        // Test that rapid output generation doesn't cause truncation
        let command = "for i in {1..100}; do echo -n \"Chunk$i \"; done; echo"
        let output = try shell.bash(command)
        
        // Verify all chunks are present
        for i in 1...100 {
            #expect(output.contains("Chunk\(i)"))
        }
        
        // Count chunks to ensure none are missing
        let chunkCount = output.components(separatedBy: "Chunk").count - 1
        #expect(chunkCount == 100)
    }
    
    @Test("Mixed stdout and stderr are captured together")
    func mixedStdoutAndStderrAreCapturedTogether() throws {
        // Test that both stdout and stderr are captured when interleaved
        let command = """
        echo "stdout line 1"; \
        echo "stderr line 1" >&2; \
        echo "stdout line 2"; \
        echo "stderr line 2" >&2
        """
        
        let output = try shell.bash(command)
        
        #expect(output.contains("stdout line 1"))
        #expect(output.contains("stderr line 1"))
        #expect(output.contains("stdout line 2"))
        #expect(output.contains("stderr line 2"))
    }
    
    @Test("Binary-like output is handled correctly")
    func binaryLikeOutputIsHandledCorrectly() throws {
        // Test output with various characters including nulls and control chars
        let command = "printf 'Hello\\x00World\\x01\\x02\\x03\\nEnd'"
        let output = try shell.bash(command)
        
        #expect(output.contains("Hello"))
        #expect(output.contains("World"))
        #expect(output.contains("End"))
    }
    
    @Test("Long running command with streaming output")
    func longRunningCommandWithStreamingOutput() throws {
        // Test a command that produces output over time
        let command = "for i in {1..10}; do echo \"Output $i\"; sleep 0.01; done"
        let output = try shell.bash(command)
        
        let lines = output.components(separatedBy: .newlines)
        #expect(lines.count == 10)
        
        for i in 1...10 {
            #expect(lines[i-1] == "Output \(i)")
        }
    }
}
