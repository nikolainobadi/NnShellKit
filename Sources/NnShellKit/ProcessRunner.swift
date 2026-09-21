//
//  ProcessRunner.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 9/21/26.
//

import os
import Foundation

/// Runs a single process to completion and supports cancelling it with everything it spawned.
///
/// `Process` is not `Sendable`, so this box is `@unchecked Sendable`. Every mutable field lives
/// in `state`, and the process is only launched or signalled while that lock is held, so a
/// cancel can never race a launch.
final class ProcessRunner: @unchecked Sendable {
    private let program: String
    private let process: Process
    private let reader: FileHandle
    private let drained = DispatchGroup()
    private let state = OSAllocatedUnfairLock(initialState: RunState(output: Data(), isCancelled: false, signalTarget: nil))

    /// How long a cancelled process group gets to exit after `SIGTERM` before `SIGKILL`.
    private let terminationGracePeriod: TimeInterval = 1

    /// How long a cancelled run waits for remaining output. A process that escaped the group
    /// can hold the pipe open indefinitely, so this wait must be bounded.
    private let cancelledDrainTimeout: TimeInterval = 1

    init(program: String, args: [String]) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: program)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe

        self.program = program
        self.process = process
        self.reader = pipe.fileHandleForReading
    }

    func run() async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                start(continuation: continuation)
            }
        } onCancel: {
            cancel()
        }
    }
}


// MARK: - Private Methods
private extension ProcessRunner {
    func start(continuation: CheckedContinuation<String, Error>) {
        process.terminationHandler = { [self] _ in
            DispatchQueue.global().async { self.finish(continuation: continuation) }
        }

        drained.enter()
        let launchFailure: Error? = state.withLock { state in
            if state.isCancelled {
                return CancellationError()
            }
            do {
                try process.run()
            } catch {
                return error
            }

            let processID = process.processIdentifier
            // Process makes each child the leader of its own group; signal the group only when
            // that holds, so a group we don't own is never touched.
            state.signalTarget = getpgid(processID) == processID ? -processID : processID
            return nil
        }

        if let launchFailure {
            drained.leave()
            continuation.resume(throwing: launchFailure)
            return
        }

        DispatchQueue(label: "nnshell.async.read").async { [self] in
            while true {
                let chunk = reader.availableData
                if chunk.isEmpty { break }
                state.withLock { $0.output.append(chunk) }
            }
            drained.leave()
        }
    }

    func finish(continuation: CheckedContinuation<String, Error>) {
        if state.withLock({ $0.isCancelled }) {
            _ = drained.wait(timeout: .now() + cancelledDrainTimeout)
            continuation.resume(throwing: CancellationError())
            return
        }

        drained.wait()
        let output = String(decoding: state.withLock { $0.output }, as: UTF8.self)

        guard process.terminationStatus == 0, process.terminationReason == .exit else {
            continuation.resume(throwing: ShellError.failed(program: program, code: process.terminationStatus, output: output))
            return
        }

        continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func cancel() {
        let signalTarget: pid_t? = state.withLock { state in
            state.isCancelled = true
            guard let target = state.signalTarget else { return nil }
            kill(target, SIGTERM)
            return target
        }

        guard let signalTarget else { return }

        DispatchQueue.global().asyncAfter(deadline: .now() + terminationGracePeriod) {
            // Signal 0 only checks whether anything in the target is still alive.
            if kill(signalTarget, 0) == 0 {
                kill(signalTarget, SIGKILL)
            }
        }
    }
}


// MARK: - Dependencies
private extension ProcessRunner {
    struct RunState {
        var output: Data
        var isCancelled: Bool
        /// The negated group id when the process leads its own group, otherwise its pid.
        var signalTarget: pid_t?
    }
}
