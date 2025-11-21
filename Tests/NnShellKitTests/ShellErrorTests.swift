//
//  ShellErrorTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
@testable import NnShellKit

struct ShellErrorTests {
    @Test("Captures program path, exit code, and error output")
    func capturesProgramPathExitCodeAndOutput() {
        let programPath = "/bin/test"
        let exitCode: Int32 = 127
        let errorOutput = "command not found"
        let error = ShellError.failed(program: programPath, code: exitCode, output: errorOutput)

        if case .failed(let program, let code, let output) = error {
            #expect(program == programPath)
            #expect(code == exitCode)
            #expect(output == errorOutput)
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }

    @Test("Preserves empty error output")
    func preservesEmptyErrorOutput() {
        let error = ShellError.failed(program: "/bin/test", code: 2, output: "")

        if case .failed(let program, let code, let output) = error {
            #expect(program == "/bin/test")
            #expect(code == 2)
            #expect(output == "")
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }

    @Test("Preserves multiline error messages")
    func preservesMultilineErrorMessages() {
        let multilineOutput = "Error line 1\nError line 2\nError line 3"
        let error = ShellError.failed(program: "/usr/bin/complex", code: 42, output: multilineOutput)

        if case .failed(let program, let code, let output) = error {
            #expect(program == "/usr/bin/complex")
            #expect(code == 42)
            #expect(output == multilineOutput)
            #expect(output.contains("\n"))
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }

    @Test("Handles special characters in program paths")
    func handlesSpecialCharactersInProgramPaths() {
        let specialPath = "/usr/local/bin/my-app_v2.0"
        let error = ShellError.failed(program: specialPath, code: 1, output: "special error")

        if case .failed(let program, let code, let output) = error {
            #expect(program == specialPath)
            #expect(code == 1)
            #expect(output == "special error")
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }

    @Test("Handles Unicode characters in error output")
    func handlesUnicodeCharactersInErrorOutput() {
        let unicodeOutput = "Error: 文件不存在 🚫"
        let error = ShellError.failed(program: "/bin/test", code: 1, output: unicodeOutput)

        if case .failed(let program, let code, let output) = error {
            #expect(program == "/bin/test")
            #expect(code == 1)
            #expect(output == unicodeOutput)
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }

    @Test("Represents common shell exit codes", arguments: [1, 2, 126, 127, 128, 130])
    func representsCommonShellExitCodes(code: Int32) {
        let error = ShellError.failed(program: "/bin/test", code: code, output: "test error")

        if case .failed(_, let errorCode, _) = error {
            #expect(errorCode == code)
        } else {
            Issue.record("Expected ShellError.failed case for code \(code)")
        }
    }
}
