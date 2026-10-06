//
//  Command.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026-present Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information

import ArgumentParser
import Foundation

/// The command line lives in the library rather than the executable so that its
/// behaviour can be tested without running a process.
///
/// It replaced a hand-rolled check for the string "--check", which ignored
/// anything it did not recognise: a mistyped flag ran in rewrite mode and printed
/// the same success line, so a typo in automation would have turned this check
/// into a step that verified nothing and still reported green.
public struct Plans: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "plans",
        abstract: "Validate plan and decision-record frontmatter and regenerate the index tables.",
        discussion: """
        Run with no options to rewrite the index tables in Development/Specs/README.md \
        and Development/ADRs/README.md. Run with --check to fail instead of rewriting, \
        which is what automation does.
        """
    )

    @Flag(
        name: .long,
        help: "Fail if an index is out of date or a document is invalid, instead of rewriting."
    )
    public var check = false

    public init() {}

    public func run() throws {
        let report = Indexer(development: URL(fileURLWithPath: "Development")).run(check: check)
        for note in report.notes {
            print("note: \(note)")
        }
        for error in report.errors {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        }
        if report.isFailure {
            throw ExitCode(1)
        }
        print("ok: \(report.specCount) plans, \(report.adrCount) decision records"
            + (report.rewritten.isEmpty
                ? "; indexes already current"
                : "; rewrote \(report.rewritten.joined(separator: ", "))"))
    }
}
