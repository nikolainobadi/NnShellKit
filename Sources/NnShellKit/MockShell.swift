//
//  MockShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

/// A mock implementation of Shell for testing purposes.
public final class MockShell {
    private let shouldThrowError: Bool
    private var results: [String]
    public private(set) var executedCommands: [String] = []
    
    public init(results: [String] = [], shouldThrowError: Bool = false) {
        self.results = results
        self.shouldThrowError = shouldThrowError
    }
}


// MARK: - Shell
extension MockShell: Shell {
    @discardableResult
    public func run(_ program: String, args: [String]) throws -> String {
        let command = "\(program) \(args.joined(separator: " "))"
        executedCommands.append(command)
        
        if shouldThrowError {
            throw ShellError.failed(program: program, code: 1, output: "Mock error")
        }
        
        return results.isEmpty ? "" : results.removeFirst()
    }
    
    @discardableResult
    public func bash(_ command: String) throws -> String {
        executedCommands.append(command)
        
        if shouldThrowError {
            throw ShellError.failed(program: "/bin/bash", code: 1, output: "Mock error")
        }
        
        return results.isEmpty ? "" : results.removeFirst()
    }
}

// MARK: - Convenience Methods
public extension MockShell {
    /// Resets the mock shell state for reuse between tests.
    func reset(results: [String] = []) {
        self.results = results
        self.executedCommands = []
    }
    
    /// Checks if any executed command contains the given substring.
    func executedCommand(containing substring: String) -> Bool {
        executedCommands.contains { $0.contains(substring) }
    }
    
    /// Returns the count of commands containing the given substring.
    func commandCount(containing substring: String) -> Int {
        executedCommands.filter { $0.contains(substring) }.count
    }
    
    /// Verifies that the command at the given index matches exactly.
    func verifyCommand(at index: Int, equals command: String) -> Bool {
        guard index < executedCommands.count else { return false }
        return executedCommands[index] == command
    }
    
    /// Returns true if no commands were executed.
    var wasUnused: Bool {
        executedCommands.isEmpty
    }
}
