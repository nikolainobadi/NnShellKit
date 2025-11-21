//
//  MockCommand.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 9/19/25.
//

import NnShellKit

/// Represents a specific mock command with its expected result.
public struct MockCommand {
    public let command: String
    public let result: MockResult
    
    /// Creates a new MockCommand with a success result.
    ///
    /// - Parameters:
    ///   - command: The command string to match.
    ///   - output: The output to return when the command is executed.
    public init(command: String, output: String) {
        self.command = command
        self.result = .success(output)
    }
    
    /// Creates a new MockCommand with a failure result.
    ///
    /// - Parameters:
    ///   - command: The command string to match.
    ///   - error: The ShellError to throw when the command is executed.
    public init(command: String, error: ShellError) {
        self.command = command
        self.result = .failure(error)
    }
}


// MARK: - Dependencies
public extension MockCommand {
    /// Represents the result of a mock command execution.
    enum MockResult {
        case success(String)
        case failure(ShellError)
    }
}
