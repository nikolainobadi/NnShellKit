//
//  ShellErrorTests.swift
//  NnShellKitTests
//
//  Created by Nikolai Nobadi on 8/16/25.
//

import Testing
@testable import NnShellKit

struct ShellErrorTests {
    
    @Test("ShellError failed case properties")
    func shellErrorFailedCaseProperties() {
        let error = ShellError.failed(program: "/bin/test", code: 127, output: "command not found")
        
        if case .failed(let program, let code, let output) = error {
            #expect(program == "/bin/test")
            #expect(code == 127)
            #expect(output == "command not found")
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }
    
    @Test("ShellError with empty output")
    func shellErrorWithEmptyOutput() {
        let error = ShellError.failed(program: "/bin/test", code: 2, output: "")
        
        if case .failed(let program, let code, let output) = error {
            #expect(program == "/bin/test")
            #expect(code == 2)
            #expect(output == "")
        } else {
            Issue.record("Expected ShellError.failed case")
        }
    }
    
    @Test("ShellError with multiline output")
    func shellErrorWithMultilineOutput() {
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
    
    @Test("ShellError with special characters in program path")
    func shellErrorWithSpecialCharactersInProgramPath() {
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
    
    @Test("ShellError with Unicode in output")
    func shellErrorWithUnicodeInOutput() {
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
    
    @Test("ShellError with common exit codes")
    func shellErrorWithCommonExitCodes() {
        let commonCodes: [Int32] = [1, 2, 126, 127, 128, 130]
        
        for code in commonCodes {
            let error = ShellError.failed(program: "/bin/test", code: code, output: "test error")
            
            if case .failed(_, let errorCode, _) = error {
                #expect(errorCode == code)
            } else {
                Issue.record("Expected ShellError.failed case for code \(code)")
            }
        }
    }
}
