//
//  NnShell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Foundation

public struct NnShell: Shell {
    public init() {}

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
    
    @discardableResult
    public func bash(_ command: String) throws -> String {
        try run("/bin/bash", args: ["-c", command])
    }
}
