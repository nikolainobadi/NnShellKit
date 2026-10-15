//
//  MockShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import os
import NnShellKit

/// A mock implementation of Shell for testing purposes.
///
/// MockShell records all executed commands and can be configured to return
/// predefined results or throw errors. It's designed for unit testing code
/// that depends on shell operations without actually executing commands.
///
/// Example usage with array results:
/// ```swift
/// let mock = MockShell(results: ["branch1", "branch2"], shouldThrowError: false)
/// let output = try mock.bash("git branch")  // Returns "branch1"
/// #expect(mock.executedCommands.first == "git branch")
/// ```
///
/// Example usage with dictionary results:
/// ```swift
/// let mock = MockShell(resultMap: ["git branch": "main\nfeature"], shouldThrowError: false)
/// let output = try mock.bash("git branch")  // Returns "main\nfeature"
/// #expect(mock.executedCommands.first == "git branch")
/// ```
public struct MockShell: Sendable {
    /// Shared, lock-guarded state, so every copy of the mock observes the same recording.
    ///
    /// Recording a command and resolving its result happen in one critical section, so the Nth
    /// recorded command always receives the Nth result, even when callers run concurrently.
    /// The lock is never held across a suspension point.
    private let state: OSAllocatedUnfairLock<State>
    
    // MARK: - Initializers

    /// Creates a new MockShell instance with array-based results.
    ///
    /// - Parameters:
    ///   - results: An array of strings to return from command executions.
    ///             Results are consumed in order. Defaults to empty array.
    ///   - shouldThrowErrorOnFinal: If true, throws `ShellError.failed` when the results array is exhausted.
    ///                             If false, returns empty string when no more results. Defaults to false.
    public init(results: [String] = [], shouldThrowErrorOnFinal: Bool = false) {
        self.state = OSAllocatedUnfairLock(initialState: State(strategy: .arrayResults(ArrayResultsConfig(results: results, shouldThrowErrorOnFinal: shouldThrowErrorOnFinal)), executedCommands: []))
    }

    /// Creates a new MockShell instance with command-based results.
    ///
    /// - Parameter commands: An array of MockCommand instances defining specific command behaviors.
    ///                      Commands not found in the array will return empty string and be logged.
    public init(commands: [MockCommand]) {
        self.state = OSAllocatedUnfairLock(initialState: State(strategy: .commandMap(commands), executedCommands: []))
    }

    /// An array of all commands that have been executed, in order.
    /// For `run()` calls, this contains the program and args joined with spaces.
    /// For `bash()` calls, this contains the exact command string.
    public var executedCommands: [String] {
        state.withLock { $0.executedCommands }
    }
}


// MARK: - Shell
extension MockShell: Shell {
    /// Simulates executing a program with the specified arguments.
    ///
    /// Records the command in `executedCommands` and returns the next result
    /// from the results queue or result map, or throws an error if configured to do so.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The next result from the results queue, mapped result, or empty string.
    /// - Throws: `ShellError.failed` based on the strategy configuration.
    @discardableResult
    public func run(_ program: String, args: [String]) throws -> String {
        let command = args.isEmpty ? program : "\(program) \(args.joined(separator: " "))"

        return try execute(command: command, program: program)
    }
    
    /// Simulates executing a bash command string.
    ///
    /// Records the command in `executedCommands` and returns the next result
    /// from the results queue or result map, or throws an error if configured to do so.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The next result from the results queue, mapped result, or empty string.
    /// - Throws: `ShellError.failed` based on the strategy configuration.
    @discardableResult
    public func bash(_ command: String) throws -> String {
        return try execute(command: command, program: "/bin/bash")
    }
    
    /// Simulates executing a program with streaming output.
    ///
    /// Records the command in `executedCommands` and consumes the next result
    /// from the results queue or result map without returning it. Throws errors
    /// based on the strategy configuration.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Throws: `ShellError.failed` based on the strategy configuration.
    public func runAndPrint(_ program: String, args: [String]) throws {
        _ = try run(program, args: args)
    }

    /// Simulates executing a bash command with streaming output.
    ///
    /// Records the command in `executedCommands` and delegates to `runAndPrint(_:args:)`.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Throws: `ShellError.failed` based on the strategy configuration.
    public func runAndPrint(bash command: String) throws {
        try runAndPrint("/bin/bash", args: ["-c", command])
    }
}


// MARK: - Test Helpers
public extension MockShell {
    /// Returns true if no commands were executed.
    ///
    /// Useful for verifying that code paths that shouldn't execute shell commands
    /// actually don't execute any commands.
    var wasUnused: Bool {
        executedCommands.isEmpty
    }
    
    /// Resets the mock shell state for reuse between tests.
    ///
    /// Clears all executed commands and optionally sets new results.
    ///
    /// - Parameter results: New results queue to use. Defaults to empty array.
    func reset(results: [String] = []) {
        reset(strategy: .arrayResults(ArrayResultsConfig(results: results, shouldThrowErrorOnFinal: false)))
    }

    /// Resets the mock shell state for reuse between tests with command results.
    ///
    /// Clears all executed commands and sets new command mappings.
    ///
    /// - Parameter commands: New command mappings to use.
    func reset(commands: [MockCommand]) {
        reset(strategy: .commandMap(commands))
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
        let commands = executedCommands
        guard index < commands.count else { return false }
        return commands[index] == command
    }
}


// MARK: - Dependencies
internal extension MockShell {
    /// Configuration for array-based results.
    struct ArrayResultsConfig {
        var results: [String]
        let shouldThrowErrorOnFinal: Bool
    }

    /// Internal enum to handle different result strategies.
    enum ResultStrategy {
        case arrayResults(ArrayResultsConfig)
        case commandMap([MockCommand])
        case alwaysThrowError
    }

    /// The mutable state guarded by `MockShell`'s lock.
    struct State {
        var strategy: ResultStrategy
        var executedCommands: [String]
    }
}


// MARK: - Private Methods
private extension MockShell {
    func reset(strategy: ResultStrategy) {
        state.withLock { state in
            state.strategy = strategy
            state.executedCommands = []
        }
    }

    /// Records the command and returns the result the current strategy dictates.
    ///
    /// - Parameters:
    ///   - command: The command to record and resolve.
    ///   - program: The program being executed (for error reporting).
    /// - Returns: The result for the command.
    /// - Throws: ShellError if the strategy dictates an error should be thrown.
    func execute(command: String, program: String) throws -> String {
        try state.withLock { state in
            state.executedCommands.append(command)

            switch state.strategy {
            case .arrayResults(var config):
                if !config.results.isEmpty {
                    let result = config.results.removeFirst()
                    state.strategy = .arrayResults(config) // Update the strategy with modified config
                    return result
                }
                if config.shouldThrowErrorOnFinal {
                    throw ShellError.failed(program: program, code: 1, output: "Mock error on final command")
                }
                return ""

            case .commandMap(let commands):
                if let matchingCommand = commands.first(where: { $0.command == command }) {
                    switch matchingCommand.result {
                    case .success(let output):
                        return output
                    case .failure(let error):
                        throw error
                    }
                }

                // No result found - log the unmapped command and return empty string
                print("[MockShell] No result mapped for command: '\(command)'")
                return ""

            case .alwaysThrowError:
                throw ShellError.failed(program: program, code: 1, output: "Mock error")
            }
        }
    }
}
