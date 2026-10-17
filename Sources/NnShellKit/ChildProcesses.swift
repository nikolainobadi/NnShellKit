//
//  ChildProcesses.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 10/16/26.
//

import Foundation

/// The processes NnShellKit has launched and that are still running.
///
/// `Process` puts every child in its own process group, so a Ctrl-C that stops your program
/// never reaches the commands it started. Call `terminateAll(gracePeriod:)` from your interrupt
/// handler before exiting so they don't outlive it.
public enum ChildProcesses {
    /// Terminates every running process launched by `NnShell` or `AsyncNnShell`, along with
    /// everything in its process group, and refuses all new launches.
    ///
    /// Each process group receives `SIGTERM`; any still alive after `gracePeriod` receives `SIGKILL`.
    /// The call blocks until every group has exited or been sent `SIGKILL`.
    ///
    /// Call this only when your program is about to exit. After it is called, NnShellKit throws
    /// `CancellationError` instead of launching new processes, and there is no reset.
    ///
    /// A process that moves itself into a new process group or session (for example with `setsid`,
    /// or a daemon) is no longer in its group's signal target and is not reached.
    ///
    /// Example usage:
    /// ```swift
    /// signal(SIGINT, SIG_IGN)
    /// let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    /// source.setEventHandler {
    ///     ChildProcesses.terminateAll(gracePeriod: 2)
    ///     exit(130)
    /// }
    /// source.resume()
    /// ```
    ///
    /// - Parameter gracePeriod: How long, in seconds, the processes get to exit after `SIGTERM`
    ///   before `SIGKILL`.
    public static func terminateAll(gracePeriod: TimeInterval) {
        ProcessGroupRegistry.shared.terminateAll(gracePeriod: gracePeriod)
    }
}
