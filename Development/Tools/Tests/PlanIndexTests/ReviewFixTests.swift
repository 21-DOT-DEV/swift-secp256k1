//
//  ReviewFixTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026-present Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information

import Foundation
@testable import PlanIndex
import Testing

// MARK: - Escaping when the table is written

@Test func escapesAVerticalBarInATitleSoTheRowKeepsItsColumns() {
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "Encode a | b",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains(#"Encode a \| b"#))
    #expect(!out.contains("Encode a | b"))
}

@Test func escapesBracketsInADecisionRecordTitleSoTheLinkSurvives() {
    let out = Tables.adrTable([ADRRow(
        number: "0001",
        title: "Use [brackets] here",
        status: "Accepted",
        date: "2026-01-01",
        file: "0001-x.md"
    )])
    #expect(out.contains(#"Use \[brackets\] here"#))
}

@Test func escapesABackslashBeforeAnythingElse() {
    // Two parsers eat a pair each — the table level then the inline level — so
    // one author's backslash becomes four in the row, and renders as one again.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: #"back\slash"#,
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains(#"back\\\\slash"#))
}

@Test func aBackslashBeforePunctuationSurvivesBothParseLevels() {
    // A single doubling left `\(`, which the inline parser reads as an escape
    // and prints "(" — the author's backslash vanished. Four in, one out.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: #"call a\(b"#,
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains(#"a\\\\(b"#))
}

@Test func escapesParenthesesInALinkDestination() {
    let out = Tables.adrTable([ADRRow(
        number: "0001",
        title: "t",
        status: "Accepted",
        date: "2026-01-01",
        file: "0001-a(b).md"
    )])
    #expect(out.contains(#"0001-a\(b\).md"#))
}

// MARK: - Malformed table rows anywhere in the tree

@Test func reportsATableRowWhoseColumnCountDisagreesWithItsHeader() {
    let rows = Tables.malformedRows(in: """
    | a | b |
    |---|---|
    | one | two |
    | one | two | three |
    """)
    #expect(rows.count == 1)
    #expect(rows.first?.line == 4)
}

@Test func acceptsARowWhoseExtraBarIsEscaped() {
    let rows = Tables.malformedRows(in: """
    | a | b |
    |---|---|
    | one \\| still one | two |
    """)
    #expect(rows.isEmpty)
}

// MARK: - Messages name the folder that was actually read

@Test func errorMessagesNameTheFolderThatWasActuallyScanned() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("Planning-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("Specs/001-x"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Nope\nupdated: 2026-01-01\n---\n"
        .write(to: root.appendingPathComponent("Specs/001-x/plan.md"), atomically: true, encoding: .utf8)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
    }
    defer { try? fm.removeItem(at: root) }

    let report = Indexer(development: root).run(check: false)
    let statusError = try #require(report.errors.first { $0.contains("is not one of") })
    #expect(statusError.hasPrefix(root.lastPathComponent + "/"))
    #expect(!statusError.contains("Development/"))
}

// MARK: - Read failures say why

@Test func saysWhyAPlanCouldNotBeReadRatherThanCallingItAbsent() throws {
    let root = try makeUnreadableTree(plan: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    let e = try #require(report.errors.first { $0.contains("plan.md") })
    #expect(!e.contains("has no plan.md")) // the file is right there
    #expect(e.lowercased().contains("format") || e.lowercased().contains("couldn"))
}

@Test func reportsAnUnreadableDecisionRecordInsteadOfSkippingIt() throws {
    let root = try makeUnreadableTree(plan: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("0001-broken.md") })
}

private func makeUnreadableTree(plan: Bool) throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("unreadable-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("Specs/001-x"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
    }
    // Bytes that are not valid text: present, but unreadable. Portable, unlike chmod games.
    let bad = Data([0xFF, 0xFE, 0x00, 0x01])
    if plan {
        try bad.write(to: root.appendingPathComponent("Specs/001-x/plan.md"))
    } else {
        try "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n"
            .write(to: root.appendingPathComponent("Specs/001-x/plan.md"), atomically: true, encoding: .utf8)
        try bad.write(to: root.appendingPathComponent("ADRs/0001-broken.md"))
    }
    return root
}

// MARK: - The command line refuses what it does not recognise

@Test func acceptsTheCheckFlag() throws {
    let cmd = try Plans.parse(["--check"])
    #expect(cmd.check == true)
}

@Test func defaultsToRewritingWhenNoFlagIsGiven() throws {
    #expect(try Plans.parse([]).check == false)
}

@Test func refusesAMistypedFlagInsteadOfIgnoringIt() {
    // The previous hand-rolled reader accepted this and ran in rewrite mode while
    // printing the same success line, so automation could report green having
    // verified nothing.
    #expect(throws: (any Error).self) { _ = try Plans.parse(["--chekc"]) }
}

@Test func refusesAStrayPositionalArgument() {
    #expect(throws: (any Error).self) { _ = try Plans.parse(["SomeOtherFolder"]) }
}

// MARK: - Degenerate frontmatter is reported, not fatal

@Test func reportsAnEmptyFrontmatterBlockInsteadOfTrapping() {
    // The closing marker sits where the content would start, so the naive
    // arithmetic produced a backwards range and killed the process. A malformed
    // document must produce a readable error, not take the checker down with it.
    #expect(throws: (any Error).self) {
        try Frontmatter.decode(PlanFrontmatter.self, from: "---\n---\n")
    }
}

@Test func reportsAFrontmatterBlockHoldingOnlyBlankLines() {
    #expect(throws: (any Error).self) {
        try Frontmatter.decode(PlanFrontmatter.self, from: "---\n\n---\n")
    }
}

@Test func reportsAnEmptyFrontmatterWithNoTrailingNewline() {
    #expect(throws: (any Error).self) {
        try Frontmatter.decode(PlanFrontmatter.self, from: "---\n---")
    }
}

// MARK: - Windows line endings

@Test func acceptsFrontmatterWrittenWithWindowsLineEndings() throws {
    let front = try Frontmatter.decode(
        PlanFrontmatter.self,
        from:
        "---\r\nfeature: 002\r\ntitle: t\r\nphase: null\r\nstatus: Planned\r\nupdated: 2026-01-01\r\n---\r\nbody"
    )
    #expect(front.feature == "002")
}

// MARK: - A line starting with a bar is not always a table

@Test func ignoresALineThatStartsWithABarButHoldsNoColumns() {
    // A list continuation written as "| - item" has one bar and no columns. Treating
    // it as a header would make every following real table row look wrong.
    let rows = Tables.malformedRows(in: """
    | - a continuation, not a table
    | - another one

    | a | b |
    |---|---|
    | one | two |
    """)
    #expect(rows.isEmpty)
}

@Test func ignoresPipesInsideAFencedCodeBlock() {
    // Three pipe-led lines that disagree on columns. Without fence tracking the
    // first becomes a header, the second its divider, and the third a
    // three-column row in a two-column table — an error on data, not a row.
    let rows = Tables.malformedRows(in: """
    | a | b |
    |---|---|
    | one | two |

    ```sh
    | a | b |
    |---|---|
    | x | y | z |
    ```

    | c | d |
    |---|---|
    | one | two |
    """)
    #expect(rows.isEmpty)
}

@Test func stillFlagsAMalformedRowAfterAClosedFence() {
    // Guards the other half: if the fence never recognised its closer, every
    // table below it would be skipped and this row would never be reported.
    let rows = Tables.malformedRows(in: """
    ```
    | x | y | z |
    ```
    | a | b |
    |---|---|
    | one | two | three |
    """)
    #expect(rows.count == 1)
    #expect(rows.first?.line == 6)
}

@Test func aFenceEndsTheTableAboveIt() {
    // Without a reset at the fence line, this clean two-column table is
    // measured against the three-column header above the fence and its divider
    // row is reported as a malformed row.
    let rows = Tables.malformedRows(in: """
    | a | b | c |
    ```
    | filler |
    ```
    | c | d |
    |---|---|
    | one | two |
    """)
    #expect(rows.isEmpty)
}

@Test func aShorterFenceDoesNotCloseALongerOne() {
    // Comparing only the first three characters closed the outer fence at the
    // ``` example line, and the bogus table below it was checked as real rows.
    let rows = Tables.malformedRows(in: """
    ````markdown
    ```markdown
    | a | b |
    |---|---|
    | one | two | three |
    ```
    ````
    """)
    #expect(rows.isEmpty)
}

@Test func handlesWindowsLineEndingsInTables() {
    // \r\n is a single Character, so splitting on "\n" alone never fires — a
    // CRLF document reads as one line and every line-based check silently
    // passes it. logicalLines() normalises first.
    #expect(Tables.malformedRows(in: "| a | b |\r\n|---|---|\r\n| x | y |\r\n").isEmpty)
    #expect(Tables.malformedRows(in: "| a | b |\r\n|---|---|\r\n| x | y | z |\r\n").count == 1)
}

// MARK: - A failed write says why

/// Root ignores permission bits — the folder stays writable and this test would
/// report a failure for a case it never exercised. Skipped, not passed silently.
@Test(.enabled(if: geteuid() != 0, "root ignores permission bits"))
func reportsWhyAnIndexCouldNotBeWritten() throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("readonly-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("Specs/001-x"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n"
        .write(to: root.appendingPathComponent("Specs/001-x/plan.md"), atomically: true, encoding: .utf8)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
    }
    let specsDir = root.appendingPathComponent("Specs")
    try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: specsDir.path)
    defer {
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: specsDir.path)
        try? fm.removeItem(at: root)
    }

    let report = Indexer(development: root).run(check: false)
    let e = try #require(report.errors.first { $0.contains("Specs/README.md") })
    #expect(!e.hasSuffix("could not be written")) // must say why, not just that
    #expect(e.lowercased().contains("permission") || e.lowercased().contains("couldn"))
}

@Test func reportsAnInjectedWriteFailureTheSameEverywhere() throws {
    // What matters is how a failed write is reported, and permission bits
    // cannot supply the failure where the suite runs as root — root writes
    // anyway. The injected writer exercises the same reporting path on every
    // platform, root or not.
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("writefail-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("Specs/001-x"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n"
        .write(to: root.appendingPathComponent("Specs/001-x/plan.md"), atomically: true, encoding: .utf8)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
    }
    defer { try? fm.removeItem(at: root) }

    let report = Indexer(development: root) { _, _ in
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "the disk is full"])
    }.run(check: false)
    let writeErrors = report.errors.filter { $0.contains("Specs/README.md") }
    #expect(writeErrors.count == 1)
    #expect(writeErrors.first?.contains("the disk is full") == true)
    #expect(report.rewritten.isEmpty)
}

// MARK: - The closing fence must be a line of its own

@Test func refusesADocumentWhoseFrontmatterIsNeverClosed() {
    // A horizontal rule in the body is not a terminator. Accepting one meant a
    // document missing its closing fence parsed anyway, from whatever happened to
    // come first.
    #expect(throws: Frontmatter.ParseError("frontmatter is not closed with ---")) {
        try Frontmatter.decode(
            PlanFrontmatter.self,
            from:
            "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n----------\n"
        )
    }
    #expect(throws: Frontmatter.ParseError("frontmatter is not closed with ---")) {
        try Frontmatter.decode(
            PlanFrontmatter.self,
            from:
            "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n--- notes\n"
        )
    }
}

@Test func stillAcceptsAProperlyClosedDocumentEndingAtTheFence() throws {
    let front = try Frontmatter.decode(
        PlanFrontmatter.self,
        from:
        "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---"
    )
    #expect(front.title == "t")
}

// MARK: - Divider rows are structural, not guessed from punctuation

@Test func flagsAOneColumnRowWhoseOnlyCellIsADash() {
    // Treated as a divider before, because it strips to nothing and holds a dash,
    // so a genuinely malformed row was skipped rather than reported.
    let rows = Tables.malformedRows(in: "| a | b | c |\n|---|---|---|\n| x | y | z |\n| - |\n")
    #expect(rows.count == 1)
    #expect(rows.first?.columns == 1)
}

@Test func stillSkipsTheRealDividerRowIncludingTheMinimalForm() {
    #expect(Tables.malformedRows(in: "| a | b |\n|-|-|\n| x | y |\n").isEmpty)
    #expect(Tables.malformedRows(in: "| a | b |\n|:--|--:|\n| x | y |\n").isEmpty)
}

// MARK: - "Empty" means empty, not "starts with three dashes"

@Test func doesNotCallAnUnclosedDocumentEmptyJustBecauseItsBodyStartsWithDashes() {
    #expect(throws: Frontmatter.ParseError("frontmatter is not closed with ---")) {
        try Frontmatter.decode(PlanFrontmatter.self, from: "---\n---foo\nbar\n")
    }
}

@Test func stillReportsAGenuinelyEmptyBlock() {
    #expect(throws: Frontmatter.ParseError("frontmatter is empty")) {
        try Frontmatter.decode(PlanFrontmatter.self, from: "---\n---\n")
    }
}

// MARK: - An unreadable index says why

@Test func saysWhyAnIndexFileCouldNotBeRead() throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("unreadable-index-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("Specs"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try Data([0xFF, 0xFE, 0x00]).write(to: root.appendingPathComponent("Specs/README.md"))
    try "\(beginMarker)\n\(endMarker)\n".write(
        to: root.appendingPathComponent("ADRs/README.md"),
        atomically: true,
        encoding: .utf8
    )
    defer { try? fm.removeItem(at: root) }

    let report = Indexer(development: root).run(check: false)
    let e = try #require(report.errors.first { $0.contains("Specs/README.md") })
    #expect(!e.hasSuffix("cannot be read"))
    #expect(e.lowercased().contains("format") || e.lowercased().contains("couldn"))
}

// MARK: - A number must match its folder or file exactly, not merely start it

@Test func refusesAFolderWhoseNumberOnlyStartsWithTheFeatureNumber() throws {
    // "0220-foo" begins with "022", so a prefix test accepted it and produced an
    // index row numbered 022 pointing at folder 0220.
    let root = try makeNumberedTree(folder: "0220-foo", feature: "022")
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("does not match folder") })
}

@Test func stillAcceptsAFolderWhoseNumberMatchesExactly() throws {
    let root = try makeNumberedTree(folder: "022-foo", feature: "022")
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(Indexer(development: root).run(check: false).errors.isEmpty)
}

@Test func refusesADecisionRecordWhoseNumberDisagreesWithItsFileName() throws {
    let root = try makeNumberedTree(folder: "001-x", feature: "001", adrFile: "0001-a.md", adrNumber: "0002")
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("does not match file") })
}

private func makeNumberedTree(
    folder: String,
    feature: String,
    adrFile: String = "0001-a.md",
    adrNumber: String = "0001"
) throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("num-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("Specs/\(folder)"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try "---\nfeature: \(feature)\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n"
        .write(to: root.appendingPathComponent("Specs/\(folder)/plan.md"), atomically: true, encoding: .utf8)
    try "---\nadr: \(adrNumber)\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\n---\n"
        .write(to: root.appendingPathComponent("ADRs/\(adrFile)"), atomically: true, encoding: .utf8)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
    }
    return root
}

// MARK: - A missing folder is reported as a missing folder

@Test func namesTheMissingFolderRatherThanAFileItNeverOpened() throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nofolder-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try "\(beginMarker)\n\(endMarker)\n".write(
        to: root.appendingPathComponent("ADRs/README.md"),
        atomically: true,
        encoding: .utf8
    )
    defer { try? fm.removeItem(at: root) } // Specs/ deliberately absent

    let report = Indexer(development: root).run(check: false)
    let e = try #require(report.errors.first { $0.contains("Specs") })
    // Pointing at Specs/README.md would name a file the tool never tried to open.
    #expect(!e.contains("README.md"))
    #expect(e.contains("Specs") && e.lowercased().contains("exist"))
}

// MARK: - Any unreadable document is reported, not just the ones with frontmatter

@Test func reportsAnUnreadableDocumentThatIsNeitherAPlanNorARecord() throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("corrupt-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("Specs"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(
            to: root.appendingPathComponent(p),
            atomically: true,
            encoding: .utf8
        )
    }
    try Data([0xFF, 0xFE, 0x00]).write(to: root.appendingPathComponent("constitution.md"))
    defer { try? fm.removeItem(at: root) }

    _ = Indexer(development: root).run(check: false) // make the indexes current
    let report = Indexer(development: root).run(check: true) // then check
    #expect(report.errors.contains { $0.contains("constitution.md") })
}

@Test func doesNotReportTheSameUnreadableFileTwice() throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dupe-\(UUID().uuidString)")
    try fm.createDirectory(at: root.appendingPathComponent("Specs/001-x"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "\(beginMarker)\n\(endMarker)\n".write(
            to: root.appendingPathComponent(p),
            atomically: true,
            encoding: .utf8
        )
    }
    try Data([0xFF, 0xFE, 0x00]).write(to: root.appendingPathComponent("Specs/001-x/plan.md"))
    defer { try? fm.removeItem(at: root) }

    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.filter { $0.contains("001-x/plan.md") }.count == 1)
}

// MARK: - The counter is global, even across branches

private func makeTree(files: [String: String]) throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("tree-\(UUID().uuidString)")
    for (path, body) in files {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try body.write(to: url, atomically: true, encoding: .utf8)
    }
    return root
}

@Test func twoFeaturesOrRecordsSharingANumberAreAnError() throws {
    // Two branches each add the next number and merge without conflict because
    // the file names differ — each file passes on its own. Without a global
    // check the index would carry two rows for one number and every numeric
    // reference to it would be ambiguous.
    let root = try makeTree(files: [
        "Specs/006-a/plan.md": "---\nfeature: 006\ntitle: a\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "Specs/006-b/plan.md": "---\nfeature: 006\ntitle: b\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0006-a.md": "---\nadr: 0006\ntitle: a\nstatus: Accepted\ndate: 2026-01-01\n---\n",
        "ADRs/0006-b.md": "---\nadr: 0006\ntitle: b\nstatus: Accepted\ndate: 2026-01-01\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.filter { $0.contains("already used") }.count == 2)
    #expect(report.errors.contains { $0.contains("006-b") && $0.contains("006-a") })
    #expect(report.errors.contains { $0.contains("0006-b") && $0.contains("0006-a") })
}

// MARK: - References must resolve

@Test func aPlanMayOnlyNameDecisionRecordsThatExist() throws {
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\nadrs: [9]\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("adrs: 9 names no decision record") })
}

@Test func aSupersededRecordMustNameItsReplacement() throws {
    // The README's contract: a record marked Superseded points at the record
    // that replaced it, rather than being edited or deleted.
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Superseded\ndate: 2026-01-01\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("names no replacement") })
}

@Test func supersedeReferencesMustNameExistingRecordsAndNotThemselves() throws {
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\nsupersedes: [9]\nsuperseded_by: 0009\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\nsupersedes: [2]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("supersedes: 9 names no decision record") })
    #expect(report.errors.contains { $0.contains("superseded_by '0009' names no decision record") })
    #expect(report.errors.contains { $0.contains("supersedes names this record itself") })
}

@Test func aConsistentSupersedeChainPasses() throws {
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\nadrs: [1]\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0002\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: t\nstatus: Accepted\ndate: 2026-01-02\nsupersedes: [1]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(Indexer(development: root).run(check: false).errors.isEmpty)
}

// MARK: - A cell must not end its own row

@Test func aNewlineInsideATitleCannotSplitItsTableRow() {
    // A folded YAML scalar (title: >) carries a real newline into the index;
    // rendered raw it ends the row mid-cell and the table checker then reports
    // the damage as a malformed row rather than preventing it.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "a\nb",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains("| 001 | a b |"))
    #expect(Tables.malformedRows(in: out).isEmpty)
}

// MARK: - Date fields are dates, not merely strings

@Test func dateFieldsMustBeRealCalendarDates() {
    // The fields stay text on purpose, but "2026-13-45" is well-formed YAML
    // that names no day — and would publish to the index unremarked.
    for bad in ["2026-13-45", "not-a-date", "2026-1-1", "2026-02-29"] {
        #expect(throws: (any Error).self) {
            try Frontmatter.decode(
                PlanFrontmatter.self,
                from: "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: \(bad)\n---\n"
            )
        }
    }
    #expect(throws: (any Error).self) {
        try Frontmatter.decode(
            ADRFrontmatter.self,
            from: "---\nadr: 1\ntitle: t\nstatus: Accepted\ndate: 2026-02-30\n---\n"
        )
    }
}

@Test func acceptsLeapDayOnlyInALeapYear() throws {
    // 2028 is a leap year; 2026 is not — the same "29" is only valid in one.
    let front = try Frontmatter.decode(
        PlanFrontmatter.self,
        from: "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2028-02-29\n---\n"
    )
    #expect(front.updated == "2028-02-29")
}

// MARK: - Zero-padded numbers are decimal, not octal

@Test func zeroPaddedReferencesDecodeAsDecimal() throws {
    // The template writes adrs: [0003, 0007] — where 0-prefixed digits happen
    // to agree. [0010] is the discriminating case: YAML 1.1 octal rules would
    // read it as 8, silently pointing the reference at the wrong record.
    let front = try Frontmatter.decode(
        PlanFrontmatter.self,
        from: "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\nadrs: [0010, 0008]\n---\n"
    )
    #expect(front.adrs == [10, 8])
    let adr = try Frontmatter.decode(
        ADRFrontmatter.self,
        from: "---\nadr: 2\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\nsupersedes: [0010]\n---\n"
    )
    #expect(adr.supersedes == [10])
}

// MARK: - A supersede chain must agree at both ends

@Test func aRecordCannotNameAReplacementWhileStillClaimingToStand() throws {
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\nsuperseded_by: 0002\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\nsupersedes: [1]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("superseded_by is set but status is 'Accepted'") })
}

@Test func aSupersedeChainMustPointBothWays() throws {
    // Each direction alone looks plausible; only reading both records shows the
    // disagreement.
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0002\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\nsupersedes: [3]\n---\n",
        "ADRs/0003-c.md": "---\nadr: 0003\ntitle: t\nstatus: Accepted\ndate: 2026-01-01\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    // 0001 points at 0002, which never claims it — and 0002 claims 0003, which
    // points nowhere.
    #expect(report.errors.contains { $0.contains("replacement 0002 does not list this record in supersedes") })
    #expect(report.errors.contains { $0.contains("supersedes 0003 but") && $0.contains("does not point back") })
}

@Test func aWrongStatusOnTheSupersededSideReportsOnceOnTheRightRecord() throws {
    // 0001 points back at 0002 — the only thing wrong is its status, which is
    // 0001's own field. One root cause, one error.
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: a\nstatus: Accepted\ndate: 2026-01-01\nsuperseded_by: 0002\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: b\nstatus: Accepted\ndate: 2026-01-02\nsupersedes: [1]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.count == 1)
    #expect(report.errors.contains { $0.contains("superseded_by is set but status is 'Accepted'") })
    #expect(!report.errors.contains { $0.contains("0002-b.md:") && $0.contains("supersedes") })
}

@Test func aSupersedesClaimAgainstARecordWithNoPointerIsTheMissingBackReference() throws {
    // 0001 has no superseded_by at all, so "does not point back" is accurate.
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: a\nstatus: Accepted\ndate: 2026-01-01\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: b\nstatus: Accepted\ndate: 2026-01-02\nsupersedes: [1]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.count == 1)
    #expect(report.errors.contains { $0.contains("supersedes 0001 but") && $0.contains("does not point back") })
}

@Test func aSupersedesClaimAgainstARecordPointingElsewhereSaysWhereItPoints() throws {
    // Two separate facts, two errors: 0001 names 0003 (which doesn't claim it),
    // and 0002 claims 0001 (which points at 0003, not back).
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: a\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0003\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: b\nstatus: Accepted\ndate: 2026-01-02\nsupersedes: [1]\n---\n",
        "ADRs/0003-c.md": "---\nadr: 0003\ntitle: c\nstatus: Accepted\ndate: 2026-01-03\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.count == 2)
    #expect(report.errors.contains { $0.contains("supersedes 0001, but 0001 names 0003 as its replacement") })
    #expect(report.errors.contains { $0.contains("replacement 0003 does not list this record in supersedes") })
}

@Test func aTwoRecordSupersedeLoopIsReportedOnce() throws {
    // Both records mark the other Superseded and list each other, so every
    // two-way check passes — but no decision is left standing.
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: a\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0002\nsupersedes: [2]\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: b\nstatus: Superseded\ndate: 2026-01-02\nsuperseded_by: 0001\nsupersedes: [1]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    let loops = report.errors.filter { $0.contains("never reaches a standing decision") }
    #expect(loops.count == 1)
    #expect(loops.first?.contains("0001 → 0002 → 0001") == true)
}

@Test func aLongerSupersedeLoopIsCaught() throws {
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0002-a.md": "---\nadr: 0002\ntitle: a\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0003\nsupersedes: [4]\n---\n",
        "ADRs/0003-b.md": "---\nadr: 0003\ntitle: b\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0004\nsupersedes: [2]\n---\n",
        "ADRs/0004-c.md": "---\nadr: 0004\ntitle: c\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0002\nsupersedes: [3]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("never reaches a standing decision") })
}

@Test func aChainEndingAtAStandingRecordPasses() throws {
    // 0001 -> 0002 -> 0003, where 0003 is Accepted: the walk runs through a
    // retired record and out the far end, so termination — not length — is the
    // property being checked.
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: a\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0002\n---\n",
        "ADRs/0002-b.md": "---\nadr: 0002\ntitle: b\nstatus: Superseded\ndate: 2026-01-02\nsuperseded_by: 0003\nsupersedes: [1]\n---\n",
        "ADRs/0003-c.md": "---\nadr: 0003\ntitle: c\nstatus: Accepted\ndate: 2026-01-03\nsupersedes: [2]\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(Indexer(development: root).run(check: false).errors.isEmpty)
}

@Test func aSelfPointerReportsItsOwnErrorAndNotALoop() throws {
    let root = try makeTree(files: [
        "Specs/001-x/plan.md": "---\nfeature: 001\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\n---\n",
        "ADRs/0001-a.md": "---\nadr: 0001\ntitle: t\nstatus: Superseded\ndate: 2026-01-01\nsuperseded_by: 0001\n---\n",
        "Specs/README.md": "\(beginMarker)\n\(endMarker)\n",
        "ADRs/README.md": "\(beginMarker)\n\(endMarker)\n"
    ])
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("names this record itself") })
    #expect(!report.errors.contains { $0.contains("never reaches") })
}

// MARK: - Cells are text, not HTML

@Test func angleBracketsInATitleAreEscapedSoGitHubDoesNotSwallowThem() {
    // Rendered as inline HTML, "Array<UInt8>" is a tag the table drops. The
    // entity form renders the text the author wrote.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "Adopt Array<UInt8> buffers",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains("Adopt Array&lt;UInt8&gt; buffers"))
    #expect(!out.contains("<UInt8>"))
}

@Test func angleBracketsInsideACodeSpanStayLiteral() {
    // Inside backticks an entity is not decoded — escaping there would print
    // "&lt;" where the author wrote "<".
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "Wrap `Array<UInt8>` in a helper",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains("`Array<UInt8>`"))
    #expect(!out.contains("&lt;"))
}

@Test func ampersandsAndBackslashesInsideACodeSpanStayLiteral() {
    // &amp; would print literally inside a span. The backslash is different:
    // the table parser still consumes `\\`, so the source needs `\\` for the
    // span to render one — "a\b" as the author wrote it.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "Use `a && b` and `a\\b`",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains("`a && b`"))
    #expect(out.contains(#"`a\\b`"#))
    #expect(!out.contains("&amp;"))
}

@Test func aBackslashPipeInsideACodeSpanDoesNotSplitItsCell() {
    // `\|` inside a span needs the backslash doubled for the table level too:
    // `x\\|y` splits the cell at a real divider; `x\\\|y` survives as x\|y.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: #"A `x\|y` combinator"#,
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains(#"`x\\\|y`"#))
    #expect(Tables.malformedRows(in: out).isEmpty)
}

@Test func aPipeInsideACodeSpanIsStillEscapedForTheTable() {
    // The table splits cells before inline parsing, so the pipe needs the
    // backslash everywhere; GFM strips it when rendering the span.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "A `x|y` combinator",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains(#"`x\|y`"#))
}

@Test func aLongerBacktickRunCanHoldAShorterOne() {
    // `` x ` y `` is one span: the closer must match the opener's length, so a
    // single backtick inside a double-backtick span is content.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "Read ``the `verbatim` form`` fully",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains("``the `verbatim` form``"))
}

@Test func anUnmatchedBacktickDoesNotStartASpan() {
    // A run with no closer is literal text — the `<T>` after it is ordinary
    // outside-span text and still needs its entity.
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "a ` dangling Array<T>",
        phase: "—",
        status: "Planned",
        link: "001-x/plan.md"
    )])
    #expect(out.contains("Array&lt;T&gt;"))
}

@Test func bracketsInsideACodeSpanAreNotEscapedInLinkText() {
    // Code spans bind more tightly than link-text brackets: `[x]` inside
    // backticks is text the span shows as written, so \[ would print literally.
    let out = Tables.adrTable([ADRRow(
        number: "0001",
        title: "See `[x]` for details",
        status: "Accepted",
        date: "2026-01-01",
        file: "0001-x.md"
    )])
    #expect(out.contains("[See `[x]` for details]("))
}
