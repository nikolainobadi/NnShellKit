//
//  MockAsyncShellTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 9/21/26.
//

import Testing
import NnShellKit
import NnShellTesting

struct MockAsyncShellTests {
    @Test("Starting values empty")
    func emptyStartingValues() {
        let sut = makeSUT(results: [])
        #expect(sut.executedCommands.isEmpty)
        #expect(sut.wasUnused)
    }

    @Test("Records commands and returns configured results in order")
    func recordsCommandsAndReturnsResultsInOrder() async throws {
        let sut = makeSUT(results: ["first", "second"])

        let output1 = try await sut.bash("git status")
        let output2 = try await sut.run("/usr/bin/git", args: ["log"])

        #expect(output1 == "first")
        #expect(output2 == "second")
        #expect(sut.executedCommands == ["git status", "/usr/bin/git log"])
    }

    @Test("Returns results mapped to specific commands")
    func returnsMappedCommandResults() async throws {
        let sut = MockAsyncShell(commands: [MockCommand(command: "git status", output: "clean")])

        let output = try await sut.bash("git status")

        #expect(output == "clean")
    }
}


// MARK: - Cancellation
extension MockAsyncShellTests {
    @Test("Throws CancellationError without recording when the task is cancelled")
    func throwsCancellationErrorWhenTaskIsCancelled() async {
        let sut = makeSUT(results: ["unused"])
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
    func makeSUT(results: [String]) -> MockAsyncShell {
        return .init(results: results, shouldThrowErrorOnFinal: false)
    }
}
