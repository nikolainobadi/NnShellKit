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
    
    func runAndPrint(_ program: String, args: [String]) throws
    
    func runAndPrint(bash command: String) throws
}
