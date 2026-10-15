//
//  MockAsyncShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 9/21/26.
//

import NnShellKit

/// A mock implementation of AsyncShell for testing purposes.
///
/// MockAsyncShell records commands and resolves results exactly like `MockShell`, which it wraps.
/// A call made from a cancelled task throws `CancellationError` without recording the command,
/// matching `AsyncNnShell`, which never spawns a process for a task cancelled before it starts.
///
/// Example usage:
/// ```swift
/// let mock = MockAsyncShell(results: ["main"], shouldThrowErrorOnFinal: false)
/// let output = try await mock.bash("git branch --show-current")  // Returns "main"
/// #expect(mock.executedCommands == ["git branch --show-current"])
/// ```
public struct MockAsyncShell: Sendable {
    private let shell: MockShell

    /// Creates a new MockAsyncShell instance with array-based results.
    ///
    /// - Parameters:
    ///   - results: An array of strings to return from command executions, consumed in order.
    ///   - shouldThrowErrorOnFinal: If true, throws `ShellError.failed` when the results array is exhausted.
    ///                             If false, returns empty string when no more results.
    public init(results: [String], shouldThrowErrorOnFinal: Bool) {
        self.shell = MockShell(results: results, shouldThrowErrorOnFinal: shouldThrowErrorOnFinal)
    }

    /// Creates a new MockAsyncShell instance with command-based results.
    ///
    /// - Parameter commands: An array of MockCommand instances defining specific command behaviors.
    ///                      Commands not found in the array will return empty string and be logged.
    public init(commands: [MockCommand]) {
        self.shell = MockShell(commands: commands)
    }

    /// An array of all commands that have been executed, in order.
    /// For `run()` calls, this contains the program and args joined with spaces.
    /// For `bash()` calls, this contains the exact command string.
    public var executedCommands: [String] {
        shell.executedCommands
    }
}


// MARK: - AsyncShell
extension MockAsyncShell: AsyncShell {
    /// Simulates executing a bash command string.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The next result from the results queue, mapped result, or empty string.
    /// - Throws: `CancellationError` if the calling task is cancelled,
    ///   otherwise `ShellError.failed` based on the strategy configuration.
    @discardableResult
    public func bash(_ command: String) async throws -> String {
        try Task.checkCancellation()

        return try shell.bash(command)
    }

    /// Simulates executing a program with the specified arguments.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The next result from the results queue, mapped result, or empty string.
    /// - Throws: `CancellationError` if the calling task is cancelled,
    ///   otherwise `ShellError.failed` based on the strategy configuration.
    @discardableResult
    public func run(_ program: String, args: [String]) async throws -> String {
        try Task.checkCancellation()

        return try shell.run(program, args: args)
    }
}


// MARK: - Test Helpers
public extension MockAsyncShell {
    /// Returns true if no commands were executed.
    var wasUnused: Bool {
        shell.wasUnused
    }

    /// Checks if any executed command contains the given substring.
    ///
    /// - Parameter substring: The substring to search for in executed commands.
    /// - Returns: True if any executed command contains the substring, false otherwise.
    func executedCommand(containing substring: String) -> Bool {
        shell.executedCommand(containing: substring)
    }

    /// Returns the count of commands containing the given substring.
    ///
    /// - Parameter substring: The substring to search for in executed commands.
    /// - Returns: The number of executed commands that contain the substring.
    func commandCount(containing substring: String) -> Int {
        shell.commandCount(containing: substring)
    }

    /// Verifies that the command at the given index matches exactly.
    ///
    /// - Parameters:
    ///   - index: The index of the command to check (0-based).
    ///   - command: The expected command string.
    /// - Returns: True if the command at the index matches exactly, false otherwise.
    func verifyCommand(at index: Int, equals command: String) -> Bool {
        shell.verifyCommand(at: index, equals: command)
    }
}
