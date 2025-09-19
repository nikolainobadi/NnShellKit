//
//  ConfigurableMockShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

/// A flexible mock implementation of Shell that can operate in ordered or mapped modes.
///
/// ConfigurableMockShell provides two distinct modes of operation:
/// - **Ordered mode**: Commands must be executed in the exact sequence specified
/// - **Mapped mode**: Commands can be executed in any order
///
/// This implementation supersedes the original MockShell, providing more explicit
/// and flexible configuration through the MockCommand struct.
///
/// Example usage in ordered mode:
/// ```swift
/// let mock = ConfigurableMockShell(commands: [
///     MockCommand(command: "git status", result: "clean"),
///     MockCommand(command: "git push", error: ShellError.failed(program: "git", code: 128, output: "failed"))
/// ])
/// try mock.bash("git status")  // Returns "clean"
/// try mock.bash("git push")    // Throws error
/// ```
///
/// Example usage in mapped mode:
/// ```swift
/// let mock = ConfigurableMockShell(commands: [
///     MockCommand(command: "pwd", result: "/home"),
///     MockCommand(command: "ls", result: "file1 file2")
/// ], mode: .mapped)
/// try mock.bash("ls")   // Returns "file1 file2" (any order)
/// try mock.bash("pwd")  // Returns "/home"
/// ```
public class ConfigurableMockShell {
    /// The operating mode for the mock shell.
    public enum Mode {
        /// Commands must be executed in the exact order they were provided.
        case ordered

        /// Commands can be executed in any order.
        case mapped
    }

    /// The current operating mode.
    private let mode: Mode

    /// The configured commands.
    private var commands: [MockCommand]

    /// The current index for ordered mode execution.
    private var commandIndex = 0

    /// An array of all commands that have been executed, in order.
    public private(set) var executedCommands: [String] = []

    /// Creates a new ConfigurableMockShell instance.
    ///
    /// - Parameters:
    ///   - commands: An array of MockCommand configurations.
    ///   - mode: The operating mode (ordered or mapped). Defaults to ordered.
    public init(commands: [MockCommand] = [], mode: Mode = .ordered) {
        self.commands = commands
        self.mode = mode
    }
}

// MARK: - Shell
extension ConfigurableMockShell: Shell {
    /// Simulates executing a program with the specified arguments.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The configured result for the command.
    /// - Throws: The configured error or an error if no matching command is found in ordered mode.
    @discardableResult
    public func run(_ program: String, args: [String]) throws -> String {
        let command = args.isEmpty ? program : "\(program) \(args.joined(separator: " "))"
        return try executeCommand(command)
    }

    /// Simulates executing a bash command string.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The configured result for the command.
    /// - Throws: The configured error or an error if no matching command is found in ordered mode.
    @discardableResult
    public func bash(_ command: String) throws -> String {
        try executeCommand(command)
    }

    /// Executes a command based on the current mode.
    ///
    /// - Parameter command: The command to execute.
    /// - Returns: The configured result for the command.
    /// - Throws: The configured error or an error if the command doesn't match expectations.
    private func executeCommand(_ command: String) throws -> String {
        executedCommands.append(command)

        switch mode {
        case .ordered:
            return try executeOrderedCommand(command)
        case .mapped:
            return try executeMappedCommand(command)
        }
    }

    /// Executes a command in ordered mode.
    private func executeOrderedCommand(_ command: String) throws -> String {
        guard commandIndex < commands.count else {
            throw ShellError.failed(
                program: "/bin/bash",
                code: 127,
                output: "No more commands expected. Received: \(command)"
            )
        }

        let expectedCommand = commands[commandIndex]
        guard expectedCommand.command == command else {
            throw ShellError.failed(
                program: "/bin/bash",
                code: 127,
                output: "Command mismatch. Expected: '\(expectedCommand.command)', got: '\(command)'"
            )
        }

        commandIndex += 1

        if expectedCommand.shouldThrow {
            throw expectedCommand.error ?? ShellError.failed(
                program: "/bin/bash",
                code: 1,
                output: "Mock command failed"
            )
        }

        return expectedCommand.result
    }

    /// Executes a command in mapped mode.
    private func executeMappedCommand(_ command: String) throws -> String {
        guard let matchingCommand = commands.first(where: { $0.command == command }) else {
            // In mapped mode, unmapped commands return empty string (similar to original MockShell)
            print("[ConfigurableMockShell] No command mapped for: '\(command)'")
            return ""
        }

        if matchingCommand.shouldThrow {
            throw matchingCommand.error ?? ShellError.failed(
                program: "/bin/bash",
                code: 1,
                output: "Mock command failed"
            )
        }

        return matchingCommand.result
    }
}

// MARK: - Convenience Methods
public extension ConfigurableMockShell {
    /// Resets the mock shell state for reuse between tests.
    ///
    /// Clears all executed commands and resets the command index for ordered mode.
    ///
    /// - Parameter commands: New commands to use. Defaults to empty array.
    func reset(commands: [MockCommand] = []) {
        self.commands = commands
        self.commandIndex = 0
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
    func verifyCommand(at index: Int, equals command: String) -> Bool {
        guard index < executedCommands.count else { return false }
        return executedCommands[index] == command
    }

    /// Returns true if no commands were executed.
    var wasUnused: Bool {
        executedCommands.isEmpty
    }

    /// Returns true if all expected commands in ordered mode have been executed.
    var allCommandsExecuted: Bool {
        mode == .ordered ? commandIndex == commands.count : true
    }

    /// Returns the number of remaining commands in ordered mode.
    var remainingCommandCount: Int {
        mode == .ordered ? max(0, commands.count - commandIndex) : 0
    }
}