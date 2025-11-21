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
    @Test("Executes command and returns output")
    func executesCommandAndReturnsOutput() throws {
        let sut = makeSUT()
        let output = try sut.run("/bin/echo", args: ["Hello, World!"])
        #expect(output == "Hello, World!")
    }

    @Test("Handles multiple command arguments")
    func handlesMultipleArguments() throws {
        let sut = makeSUT()
        let output = try sut.run("/bin/echo", args: ["-n", "No newline"])
        #expect(output == "No newline")
    }

    @Test("Handles commands without arguments")
    func handlesCommandsWithoutArguments() throws {
        let sut = makeSUT()
        let output = try sut.run("/bin/echo", args: [])
        #expect(output == "")
    }

    @Test("Executes bash commands with shell features")
    func executesBashCommands() throws {
        let sut = makeSUT()
        let output = try sut.bash("echo 'Hello from bash'")
        #expect(output == "Hello from bash")
    }

    @Test("Supports piped commands")
    func supportsPipedCommands() throws {
        let sut = makeSUT()
        let output = try sut.bash("echo 'line1\nline2\nline3' | head -2")
        #expect(output == "line1\nline2")
    }

    @Test("Expands environment variables")
    func expandsEnvironmentVariables() throws {
        let sut = makeSUT()
        let output = try sut.bash("echo $HOME")
        #expect(!output.isEmpty)
        #expect(output.hasPrefix("/"))
    }

    @Test("Supports output redirection")
    func supportsOutputRedirection() throws {
        let sut = makeSUT()
        let tempFile = "/tmp/nnshellkit_test_\(UUID().uuidString).txt"
        try sut.bash("echo 'test content' > \(tempFile)")

        let content = try sut.bash("cat \(tempFile)")
        #expect(content == "test content")

        try sut.bash("rm \(tempFile)")
    }

    @Test("Chains commands with logical operators")
    func chainsCommandsWithLogicalOperators() throws {
        let sut = makeSUT()
        let output = try sut.bash("echo 'first' && echo 'second'")
        #expect(output == "first\nsecond")
    }
}


// MARK: - Error Handling
extension NnShellTests {
    @Test("Throws error for non-existent program")
    func throwsErrorForNonExistentProgram() {
        let sut = makeSUT()
        #expect(throws: (any Error).self) {
            try sut.run("/non/existent/program", args: [])
        }
    }

    @Test("Throws error for failing command")
    func throwsErrorForFailingCommand() throws {
        let sut = makeSUT()
        #expect(throws: ShellError.self) {
            try sut.run("/bin/ls", args: ["/non/existent/directory"])
        }
    }

    @Test("Captures error details for failing bash commands")
    func capturesErrorDetailsForFailingBashCommands() throws {
        let sut = makeSUT()
        do {
            try sut.bash("ls /non/existent/directory")
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

    @Test("Throws error for invalid bash syntax")
    func throwsErrorForInvalidBashSyntax() throws {
        let sut = makeSUT()
        do {
            try sut.bash("echo 'unclosed quote")
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


// MARK: - Output Processing
extension NnShellTests {
    @Test("Preserves internal spaces in output")
    func preservesInternalSpaces() throws {
        let sut = makeSUT()
        let output = try sut.bash("echo '  content with spaces  '")
        #expect(output == "content with spaces")
    }

    @Test("Trims trailing newlines from output")
    func trimsTrailingNewlines() throws {
        let sut = makeSUT()
        let output = try sut.bash("echo 'content'")
        #expect(output == "content")
        #expect(!output.hasSuffix("\n"))
    }
}


// MARK: - Asynchronous Output Handling
extension NnShellTests {
    @Test("Captures large output without truncation")
    func capturesLargeOutputWithoutTruncation() throws {
        let sut = makeSUT()
        let expectedLines = 1000
        let command = "for i in {1..\(expectedLines)}; do echo \"Line $i\"; done"
        let output = try sut.bash(command)

        let lines = output.components(separatedBy: .newlines)
        #expect(lines.count == expectedLines)
        #expect(lines.first == "Line 1")
        #expect(lines.last == "Line \(expectedLines)")
    }

    @Test("Captures rapid output completely")
    func capturesRapidOutputCompletely() throws {
        let sut = makeSUT()
        let command = "for i in {1..100}; do echo -n \"Chunk$i \"; done; echo"
        let output = try sut.bash(command)

        for i in 1...100 {
            #expect(output.contains("Chunk\(i)"))
        }

        let chunkCount = output.components(separatedBy: "Chunk").count - 1
        #expect(chunkCount == 100)
    }

    @Test("Merges stdout and stderr into single stream")
    func mergesStdoutAndStderr() throws {
        let sut = makeSUT()
        let command = """
        echo "stdout line 1"; \
        echo "stderr line 1" >&2; \
        echo "stdout line 2"; \
        echo "stderr line 2" >&2
        """

        let output = try sut.bash(command)

        #expect(output.contains("stdout line 1"))
        #expect(output.contains("stderr line 1"))
        #expect(output.contains("stdout line 2"))
        #expect(output.contains("stderr line 2"))
    }

    @Test("Handles output with special characters")
    func handlesOutputWithSpecialCharacters() throws {
        let sut = makeSUT()
        let command = "printf 'Hello\\x00World\\x01\\x02\\x03\\nEnd'"
        let output = try sut.bash(command)

        #expect(output.contains("Hello"))
        #expect(output.contains("World"))
        #expect(output.contains("End"))
    }

    @Test("Captures streaming output from long-running commands")
    func capturesStreamingOutput() throws {
        let sut = makeSUT()
        let command = "for i in {1..10}; do echo \"Output $i\"; sleep 0.01; done"
        let output = try sut.bash(command)

        let lines = output.components(separatedBy: .newlines)
        #expect(lines.count == 10)

        for i in 1...10 {
            #expect(lines[i-1] == "Output \(i)")
        }
    }
}


// MARK: - SUT
private extension NnShellTests {
    func makeSUT() -> NnShell {
        return .init()
    }
}
