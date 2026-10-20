//
//  ProcessGroupRegistry.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import os
import Foundation

/// Tracks every running process NnShellKit launched, so they can all be stopped at shutdown.
///
/// Once `terminateAll(gracePeriod:)` has begun, the registry refuses every new launch. There is no reset.
final class ProcessGroupRegistry: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: RegistryState(targets: [:], nextToken: 0, isShuttingDown: false))

    /// The registry used by every shell outside of tests.
    static let shared = ProcessGroupRegistry()

    /// Whether no launched process is being tracked.
    var isEmpty: Bool {
        state.withLock { $0.targets.isEmpty }
    }

    /// Launches a process and records it, unless shutdown has begun.
    ///
    /// The shutdown check, the launch, and the registration happen under one lock, so
    /// `terminateAll(gracePeriod:)` either refuses this launch or includes it.
    ///
    /// - Parameter start: Launches the process and returns its pid.
    /// - Returns: A token to pass to `unregister(_:)` once the process has exited.
    /// - Throws: `CancellationError` once shutdown has begun, without calling `start`;
    ///   otherwise any error `start` throws.
    func launch(_ start: () throws -> pid_t) throws -> Token {
        // `start` is not `Sendable`, but it only runs synchronously inside this call.
        try state.withLockUnchecked { state in
            if state.isShuttingDown {
                throw CancellationError()
            }

            let processID = try start()
            let token = Token(rawValue: state.nextToken)
            state.nextToken += 1
            state.targets[token] = ProcessSignaller.signalTarget(for: processID)
            return token
        }
    }

    /// Stops tracking a process once it has exited.
    /// - Parameter token: The token returned by `launch(_:)`.
    func unregister(_ token: Token) {
        state.withLock { state in
            _ = state.targets.removeValue(forKey: token)
        }
    }

    /// Refuses every new launch, then terminates every tracked process and its group.
    ///
    /// Blocks until every tracked process has exited or been sent `SIGKILL`.
    ///
    /// - Parameter gracePeriod: How long the processes get to exit after `SIGTERM` before `SIGKILL`.
    func terminateAll(gracePeriod: TimeInterval) {
        let targets = state.withLock { state in
            state.isShuttingDown = true
            return Array(state.targets.values)
        }

        ProcessSignaller.terminate(targets: targets, gracePeriod: gracePeriod)
    }
}

// MARK: - Dependencies
extension ProcessGroupRegistry {
    /// Identifies one launch in the registry.
    struct Token: Hashable, Sendable {
        fileprivate let rawValue: Int
    }
}

private extension ProcessGroupRegistry {
    struct RegistryState: Sendable {
        /// Signal targets of running processes, from `ProcessSignaller.signalTarget(for:)`.
        var targets: [Token: pid_t]
        var nextToken: Int
        var isShuttingDown: Bool
    }
}
