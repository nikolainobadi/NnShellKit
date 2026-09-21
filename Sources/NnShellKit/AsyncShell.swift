//
//  AsyncShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 9/21/26.
//

/// A protocol defining an async, cancellable interface for executing shell commands.
///
/// Cancelling the task that awaits a call terminates the underlying process together with
/// every process it spawned, and the call throws `CancellationError`.
public protocol AsyncShell: Sendable {
    /// Executes a bash command string.
    ///
    /// This method runs the command through `/bin/bash -c`, enabling the use of
    /// bash features like pipes, redirects, environment variables, and command chaining.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code,
    ///   or `CancellationError` if the awaiting task is cancelled.
    @discardableResult
    func bash(_ command: String) async throws -> String

    /// Executes a program with the specified arguments.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code,
    ///   or `CancellationError` if the awaiting task is cancelled.
    @discardableResult
    func run(_ program: String, args: [String]) async throws -> String
}
