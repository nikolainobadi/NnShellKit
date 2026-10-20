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
    @Test
    func `Executes command and returns output`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.run("/bin/echo", args: ["Hello, World!"])
        #expect(output == "Hello, World!")
    }

    @Test
    func `Passes multiple arguments through to the program`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.run("/bin/echo", args: ["-n", "No newline"])
        #expect(output == "No newline")
    }

    @Test
    func `Runs a program with no arguments`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.run("/bin/echo", args: [])
        #expect(output == "")
    }

    @Test
    func `Executes bash commands with shell features`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.bash("echo 'Hello from bash'")
        #expect(output == "Hello from bash")
    }

    @Test
    func `Supports piped commands`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.bash("echo 'line1\nline2\nline3' | head -2")
        #expect(output == "line1\nline2")
    }

    @Test
    func `Expands environment variables`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.bash("echo $HOME")
        #expect(!output.isEmpty)
        #expect(output.hasPrefix("/"))
    }

    @Test
    func `Supports output redirection`() throws {
        let sut = makeSUT(timeout: nil).sut
        let tempFile = "/tmp/nnshellkit_test_\(UUID().uuidString).txt"
        try sut.bash("echo 'test content' > \(tempFile)")

        let content = try sut.bash("cat \(tempFile)")
        #expect(content == "test content")

        try sut.bash("rm \(tempFile)")
    }

    @Test
    func `Chains commands with logical operators`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.bash("echo 'first' && echo 'second'")
        #expect(output == "first\nsecond")
    }
}

// MARK: - Error Handling
extension NnShellTests {
    @Test
    func `Throws error for non-existent program`() {
        let sut = makeSUT(timeout: nil).sut
        #expect(throws: (any Error).self) {
            try sut.run("/non/existent/program", args: [])
        }
    }

    @Test
    func `Throws error for failing command`() throws {
        let sut = makeSUT(timeout: nil).sut
        #expect(throws: ShellError.self) {
            try sut.run("/bin/ls", args: ["/non/existent/directory"])
        }
    }

    @Test
    func `Captures error details for failing bash commands`() throws {
        let sut = makeSUT(timeout: nil).sut
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

    @Test
    func `Throws error for invalid bash syntax`() throws {
        let sut = makeSUT(timeout: nil).sut
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
    @Test
    func `Preserves internal spaces in output`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.bash("echo '  content with spaces  '")
        #expect(output == "content with spaces")
    }

    @Test
    func `Trims trailing newlines from output`() throws {
        let sut = makeSUT(timeout: nil).sut
        let output = try sut.bash("echo 'content'")
        #expect(output == "content")
        #expect(!output.hasSuffix("\n"))
    }

    @Test
    func `Captures non-ASCII output without corruption`() throws {
        let sut = makeSUT(timeout: nil).sut
        let text = "Error: 文件不存在 🚫"
        let output = try sut.bash("echo '\(text)'")
        #expect(output == text)
    }
}

// MARK: - Asynchronous Output Handling
extension NnShellTests {
    @Test
    func `Captures large output without truncation`() throws {
        let sut = makeSUT(timeout: nil).sut
        let expectedLines = 1000
        let command = "for i in {1..\(expectedLines)}; do echo \"Line $i\"; done"
        let output = try sut.bash(command)

        let lines = output.components(separatedBy: .newlines)
        #expect(lines.count == expectedLines)
        let firstLine = try #require(lines.first)
        let lastLine = try #require(lines.last)
        #expect(firstLine == "Line 1")
        #expect(lastLine == "Line \(expectedLines)")
    }

    @Test
    func `Captures rapid output completely`() throws {
        let sut = makeSUT(timeout: nil).sut
        let command = "for i in {1..100}; do echo -n \"Chunk$i \"; done; echo"
        let output = try sut.bash(command)

        for i in 1...100 {
            #expect(output.contains("Chunk\(i)"))
        }

        let chunkCount = output.components(separatedBy: "Chunk").count - 1
        #expect(chunkCount == 100)
    }

    @Test
    func `Merges stdout and stderr into single stream`() throws {
        let sut = makeSUT(timeout: nil).sut
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

    @Test
    func `Keeps readable text around control characters in output`() throws {
        let sut = makeSUT(timeout: nil).sut
        let command = "printf 'Hello\\x00World\\x01\\x02\\x03\\nEnd'"
        let output = try sut.bash(command)

        #expect(output.contains("Hello"))
        #expect(output.contains("World"))
        #expect(output.contains("End"))
    }

    @Test
    func `Captures streaming output from long-running commands`() throws {
        let sut = makeSUT(timeout: nil).sut
        let command = "for i in {1..10}; do echo \"Output $i\"; sleep 0.01; done"
        let output = try sut.bash(command)

        let lines = output.components(separatedBy: .newlines)
        #expect(lines.count == 10)

        for i in 1...10 {
            #expect(lines[i-1] == "Output \(i)")
        }
    }
}

// MARK: - Terminating Child Processes
extension NnShellTests {
    @Test
    func `Shutting down child processes stops a running command and its grandchild`() throws {
        let (sut, registry) = makeSUT(timeout: nil)
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let run = BackgroundRun { try sut.bash("sleep 30 & echo $! > \(pidFile); wait") }
        let grandchildID = try ProcessProbe.waitForProcessID(in: pidFile)

        registry.terminateAll(gracePeriod: 1)

        #expect(run.outcome(waitingUpTo: 5).didThrow)
        #expect(ProcessProbe.waitUntilDead(grandchildID))
    }

    @Test
    func `Shutting down child processes stops a streamed command and its grandchild`() throws {
        let (sut, registry) = makeSUT(timeout: nil)
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let run = BackgroundRun { try sut.runAndPrint(bash: "sleep 30 & echo $! > \(pidFile); wait") }
        let grandchildID = try ProcessProbe.waitForProcessID(in: pidFile)

        registry.terminateAll(gracePeriod: 1)

        #expect(run.outcome(waitingUpTo: 5).didThrow)
        #expect(ProcessProbe.waitUntilDead(grandchildID))
    }

    @Test
    func `A finished command is no longer tracked`() throws {
        let (sut, registry) = makeSUT(timeout: nil)

        try sut.run("/bin/echo", args: ["done"])

        #expect(registry.isEmpty)
    }

    @Test
    func `A failed command is no longer tracked`() {
        let (sut, registry) = makeSUT(timeout: nil)

        #expect(throws: ShellError.self) {
            try sut.bash("exit 3")
        }
        #expect(registry.isEmpty)
    }

    @Test
    func `A command started after shutdown throws CancellationError without launching`() {
        let (sut, registry) = makeSUT(timeout: nil)
        let markerFile = ProcessProbe.makeTemporaryFilePath()
        registry.terminateAll(gracePeriod: 1)

        #expect(throws: CancellationError.self) {
            try sut.bash("touch \(markerFile)")
        }
        #expect(!FileManager.default.fileExists(atPath: markerFile))
    }

    @Test
    func `A streamed command started after shutdown throws CancellationError without launching`() {
        let (sut, registry) = makeSUT(timeout: nil)
        let markerFile = ProcessProbe.makeTemporaryFilePath()
        registry.terminateAll(gracePeriod: 1)

        #expect(throws: CancellationError.self) {
            try sut.runAndPrint(bash: "touch \(markerFile)")
        }
        #expect(!FileManager.default.fileExists(atPath: markerFile))
    }
}

// MARK: - Timeout
extension NnShellTests {
    @Test
    func `A timeout kills a grandchild that ignores SIGTERM`() throws {
        let sut = makeSUT(timeout: 0.5).sut
        let pidFile = ProcessProbe.makeTemporaryFilePath()

        do {
            try sut.bash("(trap '' TERM; exec sleep 30) & echo $! > \(pidFile); wait")
            Issue.record("expected the command to time out")
        } catch let ShellError.failed(_, code, _) {
            #expect(code == 124)
        }

        let grandchildID = try ProcessProbe.waitForProcessID(in: pidFile)
        #expect(ProcessProbe.waitUntilDead(grandchildID))
    }
}

// MARK: - SUT
private extension NnShellTests {
    func makeSUT(timeout: TimeInterval?) -> (sut: NnShell, registry: ProcessGroupRegistry) {
        let registry = ProcessGroupRegistry()
        return (.init(timeout: timeout, registry: registry), registry)
    }
}
