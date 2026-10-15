//
//  AsyncNnShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 9/21/26.
//

/// A cancellable implementation of the AsyncShell protocol using Foundation's Process API.
///
/// AsyncNnShell captures both stdout and stderr output and throws errors for non-zero exit
/// codes, like `NnShell`. Cancelling the awaiting task sends `SIGTERM` to the command's whole
/// process group, escalating to `SIGKILL` for anything still alive after a grace period, so
/// no child or grandchild process outlives the cancellation.
///
/// Example usage:
/// ```swift
/// let shell = AsyncNnShell()
/// let task = Task { try await shell.bash("claude -p 'summarize the changelog'") }
///
/// task.cancel()  // terminates claude and anything it spawned
/// ```
public struct AsyncNnShell: AsyncShell {
    /// Creates a new instance of AsyncNnShell.
    public init() { }

    /// Executes a bash command string.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code,
    ///   or `CancellationError` if the awaiting task is cancelled.
    @discardableResult
    public func bash(_ command: String) async throws -> String {
        try await run("/bin/bash", args: ["-c", command])
    }

    /// Executes a program with the specified arguments.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code,
    ///   or `CancellationError` if the awaiting task is cancelled.
    @discardableResult
    public func run(_ program: String, args: [String]) async throws -> String {
        try await ProcessRunner(program: program, args: args).run()
    }
}
