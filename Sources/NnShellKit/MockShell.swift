//
//  MockShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

/// A mock implementation of Shell for testing purposes.
///
/// MockShell records all executed commands and can be configured to return
/// predefined results or throw errors. It's designed for unit testing code
/// that depends on shell operations without actually executing commands.
///
/// Example usage:
/// ```swift
/// let mock = MockShell(results: ["branch1", "branch2"], shouldThrowError: false)
/// let output = try mock.bash("git branch")  // Returns "branch1"
/// assert(mock.executedCommands.first == "git branch")
/// ```
public final class MockShell {
    /// Determines whether all commands should throw errors.
    private let shouldThrowError: Bool
    
    /// A queue of results to return from command executions.
    /// Results are consumed in FIFO order (first in, first out).
    private var results: [String]
    
    /// An array of all commands that have been executed, in order.
    /// For `run()` calls, this contains the program and args joined with spaces.
    /// For `bash()` calls, this contains the exact command string.
    public private(set) var executedCommands: [String] = []
    
    /// Creates a new MockShell instance.
    ///
    /// - Parameters:
    ///   - results: An array of strings to return from command executions.
    ///             Results are consumed in order. Defaults to empty array.
    ///   - shouldThrowError: If true, all commands will throw `ShellError.failed`.
    ///                      If false, commands return results or empty string. Defaults to false.
    public init(results: [String] = [], shouldThrowError: Bool = false) {
        self.results = results
        self.shouldThrowError = shouldThrowError
    }
}


// MARK: - Shell
extension MockShell: Shell {
    /// Simulates executing a program with the specified arguments.
    ///
    /// Records the command in `executedCommands` and returns the next result
    /// from the results queue, or throws an error if configured to do so.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The next result from the results queue, or empty string if queue is empty.
    /// - Throws: `ShellError.failed` if `shouldThrowError` is true.
    @discardableResult
    public func run(_ program: String, args: [String]) throws -> String {
        let command = args.isEmpty ? program : "\(program) \(args.joined(separator: " "))"
        executedCommands.append(command)
        
        if shouldThrowError {
            throw ShellError.failed(program: program, code: 1, output: "Mock error")
        }
        
        return results.isEmpty ? "" : results.removeFirst()
    }
    
    /// Simulates executing a bash command string.
    ///
    /// Records the command in `executedCommands` and returns the next result
    /// from the results queue, or throws an error if configured to do so.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The next result from the results queue, or empty string if queue is empty.
    /// - Throws: `ShellError.failed` if `shouldThrowError` is true.
    @discardableResult
    public func bash(_ command: String) throws -> String {
        executedCommands.append(command)
        
        if shouldThrowError {
            throw ShellError.failed(program: "/bin/bash", code: 1, output: "Mock error")
        }
        
        return results.isEmpty ? "" : results.removeFirst()
    }
}

// MARK: - Convenience Methods
public extension MockShell {
    /// Resets the mock shell state for reuse between tests.
    ///
    /// Clears all executed commands and optionally sets new results.
    ///
    /// - Parameter results: New results queue to use. Defaults to empty array.
    func reset(results: [String] = []) {
        self.results = results
        self.executedCommands = []
    }
    
    /// Checks if any executed command contains the given substring.
    ///
    /// - Parameter substring: The substring to search for in executed commands.
    /// - Returns: True if any executed command contains the substring, false otherwise.
    func executedCommand(containing substring: String) -> Bool {
        executedCommands.contains { $0.contains(substring) }
    }
    
    /// Returns the count of commands containing the given substring.
    ///
    /// - Parameter substring: The substring to search for in executed commands.
    /// - Returns: The number of executed commands that contain the substring.
    func commandCount(containing substring: String) -> Int {
        executedCommands.filter { $0.contains(substring) }.count
    }
    
    /// Verifies that the command at the given index matches exactly.
    ///
    /// - Parameters:
    ///   - index: The index of the command to check (0-based).
    ///   - command: The expected command string.
    /// - Returns: True if the command at the index matches exactly, false otherwise.
    ///           Also returns false if the index is out of bounds.
    func verifyCommand(at index: Int, equals command: String) -> Bool {
        guard index < executedCommands.count else { return false }
        return executedCommands[index] == command
    }
    
    /// Returns true if no commands were executed.
    ///
    /// Useful for verifying that code paths that shouldn't execute shell commands
    /// actually don't execute any commands.
    var wasUnused: Bool {
        executedCommands.isEmpty
    }
}
