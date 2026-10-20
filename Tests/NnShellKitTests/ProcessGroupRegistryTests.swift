//
//  ProcessGroupRegistryTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Testing
import Foundation
@testable import NnShellKit

struct ProcessGroupRegistryTests {
    @Test("terminateAll with nothing registered returns right away")
    func terminateAllWithNothingRegisteredReturnsRightAway() {
        let sut = makeSUT()
        let start = Date()

        sut.terminateAll(gracePeriod: 5)

        #expect(Date().timeIntervalSince(start) < 1)
    }

    @Test("A process that obeys SIGTERM is stopped without waiting out the grace period")
    func obedientProcessIsStoppedBeforeGracePeriodEnds() throws {
        let sut = makeSUT()
        let process = ProcessProbe.makeBashProcess("exec sleep 30")
        _ = try sut.launch {
            try process.run()
            return process.processIdentifier
        }
        let start = Date()

        sut.terminateAll(gracePeriod: 5)

        #expect(Date().timeIntervalSince(start) < 3)
        #expect(ProcessProbe.waitUntilDead(process.processIdentifier))
    }

    @Test("A process that ignores SIGTERM is killed after the grace period")
    func sigtermIgnoringProcessIsKilledAfterGracePeriod() throws {
        let sut = makeSUT()
        let readyFile = ProcessProbe.makeTemporaryFilePath()
        let process = ProcessProbe.makeBashProcess("trap '' TERM; touch \(readyFile); exec sleep 30")
        _ = try sut.launch {
            try process.run()
            return process.processIdentifier
        }
        #expect(ProcessProbe.waitForFile(at: readyFile))
        let start = Date()

        sut.terminateAll(gracePeriod: 0.5)

        #expect(Date().timeIntervalSince(start) >= 0.5)
        #expect(ProcessProbe.waitUntilDead(process.processIdentifier))
    }
}

// MARK: - Launching
extension ProcessGroupRegistryTests {
    @Test("launch throws CancellationError after terminateAll without calling its closure")
    func launchRefusesAfterTerminateAll() {
        let sut = makeSUT()
        var startWasCalled = false
        sut.terminateAll(gracePeriod: 1)

        do {
            _ = try sut.launch {
                startWasCalled = true
                // A pid that can't exist, so a failing test never signals a real process.
                return pid_t.max
            }
            Issue.record("expected CancellationError")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(!startWasCalled)
    }

    @Test("Errors thrown while launching pass through unchanged and nothing is tracked")
    func launchErrorsPassThrough() {
        let sut = makeSUT()

        #expect(throws: LaunchFailure.self) {
            try sut.launch { throw LaunchFailure() }
        }
        #expect(sut.isEmpty)
    }

    @Test("A launched process is tracked until it is unregistered")
    func launchedProcessIsTrackedUntilUnregistered() throws {
        let sut = makeSUT()
        let process = ProcessProbe.makeBashProcess("exit 0")
        let token = try sut.launch {
            try process.run()
            return process.processIdentifier
        }
        #expect(!sut.isEmpty)

        sut.unregister(token)

        #expect(sut.isEmpty)
    }

    @Test("Every launch racing terminateAll is either refused or stopped")
    func launchesRacingTerminateAllAreRefusedOrStopped() {
        let sut = makeSUT()
        let launches = LaunchLog()
        let threadsDone = DispatchGroup()

        for _ in 0..<8 {
            threadsDone.enter()
            let thread = Thread {
                for _ in 0..<10 {
                    let process = ProcessProbe.makeBashProcess("exec sleep 30")
                    do {
                        _ = try sut.launch {
                            try process.run()
                            return process.processIdentifier
                        }
                        launches.recordLaunched(process)
                    } catch {
                        launches.recordRefusal(error)
                        break
                    }
                }
                threadsDone.leave()
            }
            // A group wait can't boost its threads, so match the waiting caller's QoS up front.
            thread.qualityOfService = Thread.current.qualityOfService
            thread.start()
        }

        Thread.sleep(forTimeInterval: 0.05)
        sut.terminateAll(gracePeriod: 1)
        threadsDone.wait()

        #expect(launches.refusals.allSatisfy { $0 is CancellationError })
        for process in launches.launched {
            #expect(ProcessProbe.waitUntilDead(process.processIdentifier))
        }
    }
}

// MARK: - SUT
private extension ProcessGroupRegistryTests {
    func makeSUT() -> ProcessGroupRegistry {
        return .init()
    }
}

// MARK: - Helpers
private struct LaunchFailure: Error { }

/// Collects the outcome of each launch across threads, keeping launched processes alive.
private final class LaunchLog: @unchecked Sendable {
    private let lock = NSLock()
    private var launchedProcesses: [Process] = []
    private var refusedErrors: [Error] = []

    var launched: [Process] {
        lock.withLock { launchedProcesses }
    }

    var refusals: [Error] {
        lock.withLock { refusedErrors }
    }

    func recordLaunched(_ process: Process) {
        lock.withLock { launchedProcesses.append(process) }
    }

    func recordRefusal(_ error: Error) {
        lock.withLock { refusedErrors.append(error) }
    }
}
