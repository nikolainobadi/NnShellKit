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

    /// Executes a program with the specified arguments.
    ///
    /// This method directly executes a program using its absolute path and arguments.
    /// It does not use a shell interpreter, so shell features like pipes, redirects,
    /// and environment variable expansion are not available.
    ///
    /// - Parameters:
    ///   - program: The absolute path to the program to execute.
    ///   - args: An array of arguments to pass to the program.
    /// - Returns: The trimmed output from the command's stdout and stderr.
    /// - Throws: `ShellError.failed` if the command returns a non-zero exit code.
    ///
    /// Example usage:
    /// ```swift
    /// let shell = NnShell()
    ///
    /// // List files in current directory
    /// let files = try shell.run("/bin/ls", args: ["-la"])
    ///
    /// // Get git status
    /// let status = try shell.run("/usr/bin/git", args: ["status", "--porcelain"])
    ///
    /// // Create a directory
    /// try shell.run("/bin/mkdir", args: ["-p", "/tmp/mydir"])
    ///
    /// // Copy a file
    /// try shell.run("/bin/cp", args: ["source.txt", "destination.txt"])
    ///
    /// // Build an Xcode project
    /// try shell.run("/usr/bin/xcodebuild", args: ["-project", "MyApp.xcodeproj", "-scheme", "MyApp", "build"])
    ///
    /// // Run tests with xcodebuild
    /// try shell.run("/usr/bin/xcodebuild", args: ["test", "-project", "MyApp.xcodeproj", "-scheme", "MyApp", "-destination", "platform=iOS Simulator,name=iPhone 15"])
    ///
    /// // Archive an app
    /// try shell.run("/usr/bin/xcodebuild", args: ["archive", "-project", "MyApp.xcodeproj", "-scheme", "MyApp", "-archivePath", "MyApp.xcarchive"])
    ///
    /// // List available simulators
    /// let simulators = try shell.run("/usr/bin/xcrun", args: ["simctl", "list", "devices", "available"])
    ///
    /// // Install app on simulator
    /// try shell.run("/usr/bin/xcrun", args: ["simctl", "install", "booted", "MyApp.app"])
    ///
    /// // Run without capturing output (discardableResult)
    /// try shell.run("/usr/bin/touch", args: ["newfile.txt"])
    ///
    /// // Check if a file exists (returns exit code 0 if exists)
    /// try shell.run("/usr/bin/test", args: ["-f", "myfile.txt"])
    /// ```
    @discardableResult
    public func run(_ program: String, args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: program)
        p.arguments = args

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        let reader = pipe.fileHandleForReading
        var data = Data()
        let group = DispatchGroup()
        group.enter()

        let readQueue = DispatchQueue(label: "nnshell.read") // serial
        readQueue.async {
            while true {
                let chunk = reader.availableData
                if chunk.isEmpty { break }
                data.append(chunk)
            }
            group.leave()
        }

        try p.run()
        p.waitUntilExit()
        group.wait()

        // Prefer UTF-8, tolerate invalid bytes
        let output = String(decoding: data, as: UTF8.self)

        guard p.terminationStatus == 0, p.terminationReason == .exit else {
            throw ShellError.failed(program: program, code: p.terminationStatus, output: output)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
