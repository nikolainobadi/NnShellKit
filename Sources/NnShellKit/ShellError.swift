//
//  ShellError.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

/// An error that occurs when executing shell commands.
public enum ShellError: Error {
    /// Indicates that a command failed with a non-zero exit code.
    ///
    /// - Parameters:
    ///   - program: The program or command that failed.
    ///   - code: The exit code returned by the command.
    ///   - output: The combined stdout and stderr output from the failed command.
    case failed(program: String, code: Int32, output: String)

    /// A generic error case for testing or simple error scenarios.
    case generic
}
