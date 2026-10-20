//
//  ProcessTestHelpers.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation

/// Synchronous helpers for observing real processes from tests.
enum ProcessProbe {
    static func makeTemporaryFilePath() -> String {
        return FileManager.default.temporaryDirectory.appendingPathComponent("NnShellKitTests-\(UUID().uuidString)").path
    }

    /// Waits for a command to write a pid into `path`.
    static func waitForProcessID(in path: String) throws -> pid_t {
        for _ in 0..<50 {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8),
               let processID = pid_t(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return processID
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw ProcessIDTimeout(path: path)
    }

    /// Waits for a command to write a pid into `path`, suspending instead of blocking a thread.
    static func waitForProcessID(in path: String) async throws -> pid_t {
        for _ in 0..<50 {
            if let contents = try? String(contentsOfFile: path, encoding: .utf8),
               let processID = pid_t(contents.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return processID
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        throw ProcessIDTimeout(path: path)
    }

    /// Waits for a command to create `path`.
    static func waitForFile(at path: String) -> Bool {
        for _ in 0..<50 {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    /// Polls rather than sleeping a fixed time, since termination escalates after a grace period.
    static func waitUntilDead(_ processID: pid_t) -> Bool {
        for _ in 0..<50 {
            if kill(processID, 0) != 0 {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    /// Polls like the synchronous version, suspending instead of blocking a thread.
    static func waitUntilDead(_ processID: pid_t) async -> Bool {
        for _ in 0..<50 {
            if kill(processID, 0) != 0 {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    /// A process that runs `command` through bash, configured but not launched.
    static func makeBashProcess(_ command: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        return process
    }

    /// Thrown when no pid appears in time, so the failure can't be mistaken for a cancellation.
    struct ProcessIDTimeout: Error {
        let path: String
    }
}

/// Runs blocking work on its own thread, so a test can act while that work is still running.
final class BackgroundRun: @unchecked Sendable {
    private let done = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var thrownError: Error?

    init(_ work: @escaping @Sendable () throws -> Void) {
        let thread = Thread { [self] in
            do {
                try work()
            } catch {
                lock.withLock { thrownError = error }
            }
            done.signal()
        }
        // A semaphore can't boost its signaller, so match the waiting caller's QoS up front.
        thread.qualityOfService = Thread.current.qualityOfService
        thread.start()
    }

    /// Waits up to `timeout` seconds for the work to finish.
    func outcome(waitingUpTo timeout: TimeInterval) -> Outcome {
        guard done.wait(timeout: .now() + timeout) == .success else {
            return .stillRunning
        }

        if let error = lock.withLock({ thrownError }) {
            return .threw(error)
        }
        return .returned
    }

    enum Outcome {
        case returned
        case threw(Error)
        case stillRunning

        var didThrow: Bool {
            if case .threw = self {
                return true
            }
            return false
        }
    }
}
