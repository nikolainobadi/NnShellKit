//
//  MockCommand.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

/// A configuration model for mock shell commands that specifies the command pattern,
/// expected result, and whether it should throw an error.
///
/// MockCommand provides a clear, explicit way to configure mock shell behavior for testing.
/// Each command can be configured to either return a successful result or throw a specific error.
///
/// Example usage:
/// ```swift
/// // Successful command
/// let successCmd = MockCommand(command: "git status", result: "clean working directory")
///
/// // Failed command with specific error
/// let failCmd = MockCommand(command: "git push",
///                           error: ShellError.failed(program: "git", code: 128, output: "Auth failed"))
/// ```
public struct MockCommand {
    /// The command pattern to match. This should be the exact string that will be executed.
    public let command: String

    /// The result to return when the command succeeds. Ignored if `shouldThrow` is true.
    public let result: String

    /// Whether this command should throw an error when executed.
    public let shouldThrow: Bool

    /// The specific error to throw. If nil and `shouldThrow` is true, a default error is used.
    public let error: ShellError?

    /// Creates a successful mock command configuration.
    ///
    /// - Parameters:
    ///   - command: The command pattern to match.
    ///   - result: The successful result to return.
    public init(command: String, result: String) {
        self.command = command
        self.result = result
        self.shouldThrow = false
        self.error = nil
    }

    /// Creates a failing mock command configuration with a specific error.
    ///
    /// - Parameters:
    ///   - command: The command pattern to match.
    ///   - error: The specific error to throw when this command is executed.
    public init(command: String, error: ShellError) {
        self.command = command
        self.result = ""
        self.shouldThrow = true
        self.error = error
    }

    /// Creates a failing mock command configuration with a default error.
    ///
    /// - Parameters:
    ///   - command: The command pattern to match.
    ///   - code: The exit code for the error (defaults to 1).
    ///   - output: The error output message (defaults to "Mock command failed").
    public init(command: String, failWithCode code: Int32 = 1, output: String = "Mock command failed") {
        self.command = command
        self.result = ""
        self.shouldThrow = true

        // Determine the program from the command for a more realistic error
        let program = command.contains("/") ? command.split(separator: " ").first.map(String.init) ?? command : "/bin/bash"
        self.error = ShellError.failed(program: program, code: code, output: output)
    }
}

// MARK: - Equatable
extension MockCommand: Equatable {
    public static func == (lhs: MockCommand, rhs: MockCommand) -> Bool {
        lhs.command == rhs.command &&
        lhs.result == rhs.result &&
        lhs.shouldThrow == rhs.shouldThrow
    }
}