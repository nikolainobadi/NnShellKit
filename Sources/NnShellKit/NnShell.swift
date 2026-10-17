//
//  NnShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import os
import Foundation

/// A concrete implementation of the Shell protocol using Foundation's Process API.
///
/// NnShell provides a simple interface for executing shell commands and bash scripts
/// from Swift code. It captures both stdout and stderr output and throws errors
/// for non-zero exit codes.
public struct NnShell: Shell {
    /// Timeout in seconds for executed processes.
    /// If nil, waits indefinitely.
    public var timeout: TimeInterval?

    /// Tracks launched processes so `ChildProcesses.terminateAll(gracePeriod:)` can stop them.
    private let registry: ProcessGroupRegistry

    /// How long a timed-out process group gets to exit after `SIGTERM` before `SIGKILL`.
    private static let timeoutGracePeriod: TimeInterval = 1

    /// Creates a new instance of NnShell.
    /// - Parameter timeout: Optional timeout in seconds (default: nil = no timeout).
    public init(timeout: TimeInterval? = nil) {
        self.init(timeout: timeout, registry: .shared)
    }

    /// Creates a shell that tracks its processes in `registry` instead of the shared one.
    init(timeout: TimeInterval?, registry: ProcessGroupRegistry) {
        self.timeout = timeout
        self.registry = registry
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
        let buffer = OSAllocatedUnfairLock(initialState: Data())
        let group = DispatchGroup()
        group.enter()

        let readQueue = DispatchQueue(label: "nnshell.read")
        readQueue.async {
            while true {
                let chunk = reader.availableData
                if chunk.isEmpty { break }
                buffer.withLock { $0.append(chunk) }
            }
            group.leave()
        }

        let termSemaphore = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in termSemaphore.signal() }

        let token = try registry.launch {
            try p.run()
            return p.processIdentifier
        }
        // Runs on return, after the output pipe has drained, so a grandchild still holding it stays tracked.
        defer { registry.unregister(token) }
        // Resolved right after launch: once the leader exits and is reaped, its group can't be identified.
        let signalTarget = ProcessSignaller.signalTarget(for: p.processIdentifier)

        if let t = timeout {
            let result = termSemaphore.wait(timeout: .now() + t)
            if result == .timedOut {
                ProcessSignaller.terminate(targets: [signalTarget], gracePeriod: Self.timeoutGracePeriod)
                _ = group.wait(timeout: .now() + 1)
                let output = String(decoding: buffer.withLock { $0 }, as: UTF8.self)
                throw ShellError.failed(program: program, code: 124, output: output)
            }
        } else {
            p.waitUntilExit()
        }

        group.wait()
        let output = String(decoding: buffer.withLock { $0 }, as: UTF8.self)

        guard p.terminationStatus == 0, p.terminationReason == .exit else {
            throw ShellError.failed(program: program, code: p.terminationStatus, output: output)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public extension NnShell {
    func runAndPrint(_ program: String, args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: program)
        p.arguments = args
        p.standardOutput = FileHandle.standardOutput
        p.standardError = FileHandle.standardError
        
        let sem = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in sem.signal() }
        
        let token: ProcessGroupRegistry.Token
        do {
            token = try registry.launch {
                try p.run()
                return p.processIdentifier
            }
        } catch let error as CancellationError {
            throw error
        } catch {
            throw ShellError.failed(program: program, code: 127, output: "Could not execute")
        }
        defer { registry.unregister(token) }

        sem.wait() // wait indefinitely for process to finish
        
        if p.terminationReason != .exit || p.terminationStatus != 0 {
            throw ShellError.failed(program: program, code: p.terminationStatus, output: "")
        }
    }
    
    func runAndPrint(bash command: String) throws {
        try runAndPrint("/bin/bash", args: ["-c", command])
    }
}
