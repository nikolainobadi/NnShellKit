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
    @Test
    func `Executes command and returns trimmed output`() async throws {
        let sut = makeSUT().sut
        let output = try await sut.run("/bin/echo", args: ["  Hello, World!  "])
        #expect(output == "Hello, World!")
    }

    @Test
    func `Supports bash features like pipes`() async throws {
        let sut = makeSUT().sut
        let output = try await sut.bash("echo 'one two three' | wc -w | tr -d ' '")
        #expect(output == "3")
    }
}

// MARK: - Error Handling
extension AsyncNnShellTests {
    @Test
    func `Throws ShellError with the exit code and output for a failing command`() async throws {
        let sut = makeSUT().sut

        do {
            try await sut.bash("echo failure-output; exit 3")
            Issue.record("expected ShellError.failed")
        } catch let ShellError.failed(program, code, output) {
            #expect(program == "/bin/bash")
            #expect(code == 3)
            #expect(output.contains("failure-output"))
        }
    }

    @Test
    func `Throws error for non-existent program`() async {
        let sut = makeSUT().sut
        await #expect(throws: (any Error).self) {
            try await sut.run("/nonexistent/program", args: [])
        }
    }
}

// MARK: - Cancellation
extension AsyncNnShellTests {
    @Test
    func `Cancelling a running command throws CancellationError without waiting for it`() async throws {
        let sut = makeSUT().sut
        let start = Date()
        let task = Task { try await sut.run("/bin/sleep", args: ["30"]) }

        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test
    func `Cancelled process is no longer alive`() async throws {
        let sut = makeSUT().sut
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let task = Task { try await sut.bash("echo $$ > \(pidFile); exec sleep 30") }

        let processID = try await ProcessProbe.waitForProcessID(in: pidFile)
        task.cancel()
        _ = try? await task.value

        #expect(await ProcessProbe.waitUntilDead(processID))
    }

    @Test
    func `A grandchild that ignores SIGTERM does not survive cancellation`() async throws {
        let sut = makeSUT().sut
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let task = Task { try await sut.bash("(trap '' TERM; exec sleep 30) & echo $! > \(pidFile); wait") }

        let grandchildID = try await ProcessProbe.waitForProcessID(in: pidFile)
        task.cancel()
        _ = try? await task.value

        #expect(await ProcessProbe.waitUntilDead(grandchildID))
    }

    @Test
    func `Cancelling before the command starts never spawns it`() async throws {
        let sut = makeSUT().sut
        let markerFile = ProcessProbe.makeTemporaryFilePath()
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

    @Test
    func `Cancellation returns even when an escaped process keeps the output pipe open`() async throws {
        let sut = makeSUT().sut
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let task = Task { try await sut.bash("perl -e 'use POSIX; setsid(); open(F, \">\(pidFile)\"); print F $$; close(F); sleep 8' & wait") }

        let escapedID = try await ProcessProbe.waitForProcessID(in: pidFile)
        let start = Date()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(Date().timeIntervalSince(start) < 5)
        kill(escapedID, SIGKILL)
    }
}

// MARK: - Terminating Child Processes
extension AsyncNnShellTests {
    @Test
    func `Shutting down child processes stops a running command and its grandchild`() async throws {
        let (sut, registry) = makeSUT()
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let task = Task { try await sut.bash("sleep 30 & echo $! > \(pidFile); wait") }
        let grandchildID = try await ProcessProbe.waitForProcessID(in: pidFile)

        registry.terminateAll(gracePeriod: 1)

        await #expect(throws: (any Error).self) {
            try await task.value
        }
        #expect(await ProcessProbe.waitUntilDead(grandchildID))
    }

    @Test
    func `A finished command is no longer tracked`() async throws {
        let (sut, registry) = makeSUT()

        try await sut.run("/bin/echo", args: ["done"])

        #expect(registry.isEmpty)
    }

    @Test
    func `A cancelled command is no longer tracked`() async throws {
        let (sut, registry) = makeSUT()
        let pidFile = ProcessProbe.makeTemporaryFilePath()
        let task = Task { try await sut.bash("echo $$ > \(pidFile); exec sleep 30") }
        _ = try await ProcessProbe.waitForProcessID(in: pidFile)

        task.cancel()
        _ = try? await task.value

        #expect(registry.isEmpty)
    }

    @Test
    func `A command started after shutdown throws CancellationError without launching`() async {
        let (sut, registry) = makeSUT()
        let markerFile = ProcessProbe.makeTemporaryFilePath()
        registry.terminateAll(gracePeriod: 1)

        await #expect(throws: CancellationError.self) {
            try await sut.bash("touch \(markerFile)")
        }
        #expect(!FileManager.default.fileExists(atPath: markerFile))
    }
}

// MARK: - SUT
private extension AsyncNnShellTests {
    func makeSUT() -> (sut: AsyncNnShell, registry: ProcessGroupRegistry) {
        let registry = ProcessGroupRegistry()
        return (.init(registry: registry), registry)
    }
}
