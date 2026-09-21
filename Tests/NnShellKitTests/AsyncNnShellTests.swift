//
//  AsyncNnShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 9/21/26.
//

import Testing
import Foundation
@testable import NnShellKit

struct AsyncNnShellTests {
    @Test("Executes command and returns trimmed output")
    func executesCommandAndReturnsTrimmedOutput() async throws {
        let sut = makeSUT()
        let output = try await sut.run("/bin/echo", args: ["  Hello, World!  "])
        #expect(output == "Hello, World!")
    }

    @Test("Supports bash features like pipes")
    func supportsBashPipes() async throws {
        let sut = makeSUT()
        let output = try await sut.bash("echo 'one two three' | wc -w | tr -d ' '")
        #expect(output == "3")
    }
}


// MARK: - Error Handling
extension AsyncNnShellTests {
    @Test("Throws ShellError with the exit code and output for a failing command")
    func throwsShellErrorForFailingCommand() async throws {
        let sut = makeSUT()

        do {
            try await sut.bash("echo failure-output; exit 3")
            Issue.record("expected ShellError.failed")
        } catch let ShellError.failed(program, code, output) {
            #expect(program == "/bin/bash")
            #expect(code == 3)
            #expect(output.contains("failure-output"))
        }
    }

    @Test("Throws error for non-existent program")
    func throwsErrorForNonExistentProgram() async {
        let sut = makeSUT()
        await #expect(throws: (any Error).self) {
            try await sut.run("/nonexistent/program", args: [])
        }
    }
}


// MARK: - Cancellation
extension AsyncNnShellTests {
    @Test("Cancelling a running command throws CancellationError without waiting for it")
    func cancellingThrowsCancellationError() async throws {
        let sut = makeSUT()
        let start = Date()
        let task = Task { try await sut.run("/bin/sleep", args: ["30"]) }

        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test("Cancelled process is no longer alive")
    func cancelledProcessIsNoLongerAlive() async throws {
        let sut = makeSUT()
        let pidFile = makeTemporaryFilePath()
        let task = Task { try await sut.bash("echo $$ > \(pidFile); exec sleep 30") }

        let processID = try await waitForProcessID(in: pidFile)
        task.cancel()
        _ = try? await task.value

        #expect(await waitUntilDead(processID))
    }

    @Test("A grandchild that ignores SIGTERM does not survive cancellation")
    func sigtermIgnoringGrandchildDoesNotSurvive() async throws {
        let sut = makeSUT()
        let pidFile = makeTemporaryFilePath()
        let task = Task { try await sut.bash("(trap '' TERM; exec sleep 30) & echo $! > \(pidFile); wait") }

        let grandchildID = try await waitForProcessID(in: pidFile)
        task.cancel()
        _ = try? await task.value

        #expect(await waitUntilDead(grandchildID))
    }

    @Test("Cancelling before the command starts never spawns it")
    func cancellingBeforeStartNeverSpawns() async throws {
        let sut = makeSUT()
        let markerFile = makeTemporaryFilePath()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await sut.bash("touch \(markerFile)")
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(!FileManager.default.fileExists(atPath: markerFile))
    }

    @Test("Cancellation returns even when an escaped process keeps the output pipe open")
    func cancellationReturnsWhenEscapedProcessHoldsPipe() async throws {
        let sut = makeSUT()
        let pidFile = makeTemporaryFilePath()
        // perl's setsid moves the child into a new session, out of the process group being killed.
        let task = Task { try await sut.bash("perl -e 'use POSIX; setsid(); open(F, \">\(pidFile)\"); print F $$; close(F); sleep 8' & wait") }

        let escapedID = try await waitForProcessID(in: pidFile)
        let start = Date()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(Date().timeIntervalSince(start) < 5)
        kill(escapedID, SIGKILL)
    }
}


// MARK: - SUT
private extension AsyncNnShellTests {
    func makeSUT() -> AsyncNnShell {
        return .init()
    }

    func makeTemporaryFilePath() -> String {
        return FileManager.default.temporaryDirectory.appendingPathComponent("AsyncNnShellTests-\(UUID().uuidString)").path
    }

    func waitForProcessID(in path: String) async throws -> pid_t {
        for _ in 0..<50 {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8),
               let processID = pid_t(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return processID
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw CancellationError()
    }

    /// Polls rather than sleeping a fixed time, since termination escalates after a grace period.
    func waitUntilDead(_ processID: pid_t) async -> Bool {
        for _ in 0..<50 {
            if kill(processID, 0) != 0 {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }
}
