//
//  Shell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

/// A protocol defining the interface for executing shell commands.
public protocol Shell {
    /// Executes a bash command string.
    ///
    /// This method runs the command through `/bin/bash -c`, enabling the use of
    /// bash features like pipes, redirects, environment variables, and command chaining.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    @discardableResult
    func bash(_ command: String) throws -> String
    
    /// Executes a program with the specified arguments.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    @discardableResult
    func run(_ program: String, args: [String]) throws -> String

    /// Executes a program with the specified arguments, streaming output directly to stdout/stderr.
    ///
    /// This method runs the program and pipes its output directly to the console in real-time,
    /// making it ideal for long-running commands, build scripts, or any operation where you
    /// want to see progress as it happens. Unlike `run(_:args:)`, this method does not capture
    /// or return the output.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    ///
    /// - Note: This method waits indefinitely for the command to complete and does not support timeouts.
    func runAndPrint(_ program: String, args: [String]) throws

    /// Executes a bash command string, streaming output directly to stdout/stderr.
    ///
    /// This method runs the command through `/bin/bash -c` and pipes its output directly to
    /// the console in real-time. It enables the use of bash features like pipes, redirects,
    /// environment variables, and command chaining while showing progress as it happens.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    ///
    /// - Note: This method waits indefinitely for the command to complete and does not support timeouts.
    func runAndPrint(bash command: String) throws
}
