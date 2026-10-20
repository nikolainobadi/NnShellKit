//
//  MockAsyncShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 9/21/26.
//

import Testing
import NnShellTesting

struct MockAsyncShellTests {
    @Test
    func `A new mock has no recorded commands`() {
        let sut = makeSUT(results: .ordered([]))
        #expect(sut.executedCommands.isEmpty)
        #expect(sut.wasUnused)
    }

    @Test
    func `Records commands and returns configured results in order`() async throws {
        let sut = makeSUT(results: .ordered(["first", "second"]))

        let output1 = try await sut.bash("git status")
        let output2 = try await sut.run("/usr/bin/git", args: ["log"])

        #expect(output1 == "first")
        #expect(output2 == "second")
        #expect(sut.executedCommands == ["git status", "/usr/bin/git log"])
    }

    @Test
    func `Returns results mapped to specific commands`() async throws {
        let sut = makeSUT(results: .byCommand([MockCommand(command: "git status", output: "clean")]))

        let output = try await sut.bash("git status")

        #expect(output == "clean")
    }
}

// MARK: - Cancellation
extension MockAsyncShellTests {
    @Test
    func `Throws CancellationError without recording when the task is cancelled`() async {
        let sut = makeSUT(results: .ordered(["unused"]))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await sut.bash("git push")
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(sut.wasUnused)
    }
}

// MARK: - SUT
private extension MockAsyncShellTests {
    enum Results {
        case ordered([String])
        case byCommand([MockCommand])
    }

    func makeSUT(results: Results) -> MockAsyncShell {
        switch results {
        case .ordered(let results):
            return .init(results: results, shouldThrowErrorOnFinal: false)
        case .byCommand(let commands):
            return .init(commands: commands)
        }
    }
}
