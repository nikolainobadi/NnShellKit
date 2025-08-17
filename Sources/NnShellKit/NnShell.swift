//
//  NnShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Foundation

/// A concrete implementation of the Shell protocol using Foundation's Process API.
///
/// NnShell provides a simple interface for executing shell commands and bash scripts
/// from Swift code. It captures both stdout and stderr output and throws errors
/// for non-zero exit codes.
public struct NnShell: Shell {
    /// Creates a new instance of NnShell.
    public init() {}

    /// Executes a program with the specified arguments.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    @discardableResult
    public func run(_ program: String, args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: program)
        p.arguments = args

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        try p.run()
        p.waitUntilExit()

        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard p.terminationStatus == 0 else {
            throw ShellError.failed(program: program, code: p.terminationStatus, output: output)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Executes a bash command string.
    ///
    /// This method runs the command through `/bin/bash -c`, enabling the use of
    /// bash features like pipes, redirects, environment variables, and command chaining.
    ///
    /// - Parameter command: The bash command string to execute.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    @discardableResult
    public func bash(_ command: String) throws -> String {
        try run("/bin/bash", args: ["-c", command])
    }
}
