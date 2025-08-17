//
//  Shell.swift
//  NnShellKit
//
//  Created by Nikolai Nobadi on 8/16/25.
//

public protocol Shell {
    @discardableResult
    func run(_ program: String, args: [String]) throws -> String
    
    @discardableResult
    func bash(_ command: String) throws -> String
}
