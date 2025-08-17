//
//  ShellError.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

public enum ShellError: Error {
    case failed(program: String, code: Int32, output: String)
}
