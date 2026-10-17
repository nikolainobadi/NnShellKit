//
//  ProcessSignaller.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation

/// Signals launched processes, reaching everything they spawned when they lead their own process group.
enum ProcessSignaller {
    /// Returns what to signal for a launched process.
    ///
    /// `Process` makes each child the leader of its own group; the group is signalled only when
    /// that holds, so a group we don't own is never touched.
    ///
    /// - Parameter processID: The pid of a launched process.
    /// - Returns: The negated group id when the process leads its own group, otherwise its pid.
    static func signalTarget(for processID: pid_t) -> pid_t {
        getpgid(processID) == processID ? -processID : processID
    }

    /// Sends `SIGTERM` to every target, then `SIGKILL` to any still alive after `gracePeriod`.
    ///
    /// Blocks until every target has exited or been sent `SIGKILL`.
    ///
    /// - Parameters:
    ///   - targets: Values returned by `signalTarget(for:)`.
    ///   - gracePeriod: How long the targets get to exit after `SIGTERM`.
    static func terminate(targets: [pid_t], gracePeriod: TimeInterval) {
        guard !targets.isEmpty else { return }

        for target in targets {
            kill(target, SIGTERM)
        }

        let deadline = Date().addingTimeInterval(gracePeriod)
        var remaining = targets.filter(isAlive)
        while !remaining.isEmpty, Date() < deadline {
            Thread.sleep(forTimeInterval: pollInterval)
            remaining = remaining.filter(isAlive)
        }

        for target in remaining {
            kill(target, SIGKILL)
        }
    }
}


// MARK: - Private Methods
private extension ProcessSignaller {
    /// How often `terminate(targets:gracePeriod:)` checks whether the targets have exited.
    static let pollInterval: TimeInterval = 0.05

    /// Signal 0 only checks whether anything in the target is still alive.
    static func isAlive(_ target: pid_t) -> Bool {
        kill(target, 0) == 0
    }
}
