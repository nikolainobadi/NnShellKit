//
//  ShellErrorTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
@testable import NnShellKit

struct ShellErrorTests {
    @Test(arguments: [
        (program: "/bin/test", code: Int32(127), output: "command not found"),
        (program: "/bin/test", code: Int32(2), output: ""),
        (program: "/usr/bin/complex", code: Int32(42), output: "Error line 1\nError line 2\nError line 3"),
        (program: "/usr/local/bin/my-app_v2.0", code: Int32(1), output: "special error"),
        (program: "/bin/test", code: Int32(1), output: "Error: 文件不存在 🚫")
    ])
    func `Keeps the program, exit code, and output it was created with`(input: (program: String, code: Int32, output: String)) {
        let sut = makeSUT(program: input.program, code: input.code, output: input.output)

        if case .failed(let program, let code, let output) = sut {
            #expect(program == input.program)
            #expect(code == input.code)
            #expect(output == input.output)
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }

    @Test(arguments: [1, 2, 126, 127, 128, 130])
    func `Represents common shell exit codes`(code: Int32) {
        let sut = makeSUT(program: "/bin/test", code: code, output: "test error")

        if case .failed(_, let errorCode, _) = sut {
            #expect(errorCode == code)
        } else {
            Issue.record("Expected ShellError.failed case for code \(code)")
        }
    }
}

// MARK: - SUT
private extension ShellErrorTests {
    func makeSUT(program: String, code: Int32, output: String) -> ShellError {
        return .failed(program: program, code: code, output: output)
    }
}
