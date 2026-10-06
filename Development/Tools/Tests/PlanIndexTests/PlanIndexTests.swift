//
//  PlanIndexTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026-present Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information

import Foundation
@testable import PlanIndex
import Testing

// MARK: - Schema

@Test func decodesARealPlanBlock() throws {
    let front = try Frontmatter.decode(PlanFrontmatter.self, from: """
    ---
    feature: 002
    title: Keep Screen Awake toggle
    phase: null
    status: Implemented
    updated: 2026-08-31
    adrs: [4]
    ---
    # body
    """)
    #expect(front.feature == "002") // leading zeros survive; no quoting needed
    #expect(front.updated == "2026-08-31") // stays text rather than becoming a date
    #expect(front.phase == nil)
    #expect(front.adrs == [4])
}

@Test func refusesAFieldTheSchemaDoesNotDeclare() {
    // 'adr' where 'adrs' was meant. Decoding ignores unrecognised fields by
    // default, so without the key-set check this would pass and be dropped.
    #expect(throws: Frontmatter.ParseError(
        "unknown field(s): adr"
    )) {
        try Frontmatter.decode(
            PlanFrontmatter.self,
            from:
            "---\nfeature: 002\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\nadr: [4]\n---\n"
        )
    }
}

@Test func reportsAMissingRequiredField() {
    #expect(throws: Frontmatter.ParseError(
        "frontmatter is missing required key 'status'"
    )) {
        try Frontmatter.decode(
            PlanFrontmatter.self,
            from:
            "---\nfeature: 002\ntitle: t\nphase: null\nupdated: 2026-01-01\n---\n"
        )
    }
}

@Test func decodesADecisionRecordIncludingItsSupersessionFields() throws {
    let front = try Frontmatter.decode(
        ADRFrontmatter.self,
        from:
        "---\nadr: 0001\ntitle: A choice\nstatus: Accepted\ndate: 2026-05-07\nsupersedes: []\nsuperseded_by: null\n---\n"
    )
    #expect(front.adr == "0001")
    #expect(front.supersedes == [])
    #expect(front.supersededBy == nil)
}

@Test func refusesAnUnknownFieldOnADecisionRecord() {
    #expect(throws: Frontmatter.ParseError("unknown field(s): supercedes")) {
        try Frontmatter.decode(
            ADRFrontmatter.self,
            from:
            "---\nadr: 1\ntitle: t\nstatus: Accepted\ndate: 2026-05-07\nsupercedes: []\n---\n"
        )
    }
}

@Test func refusesAMissingOrUnclosedBlock() {
    #expect(throws: Frontmatter.ParseError("missing frontmatter")) {
        try Frontmatter.decode(PlanFrontmatter.self, from: "# No frontmatter\n")
    }
}

// MARK: - Tables

@Test func rendersASpecTable() {
    let out = Tables.specTable([SpecRow(
        number: "001",
        title: "Icons",
        phase: "—",
        status: "In Progress",
        link: "001-icons/plan.md"
    )])
    #expect(out.contains("| 001 | Icons | — | In Progress | [plan.md](001-icons/plan.md) |"))
}

@Test func replacesOnlyTheBlockBetweenMarkers() throws {
    let text = "before\n\(beginMarker)\nstale\n\(endMarker)\nafter\n"
    let out = try #require(Tables.replacingIndex(in: text, with: "fresh"))
    #expect(out == "before\n\(beginMarker)\nfresh\n\(endMarker)\nafter\n")
}

@Test func refusesWhenAMarkerIsMissing() {
    #expect(Tables.replacingIndex(in: "no markers here", with: "x") == nil)
}

// MARK: - End to end, against real files in a temporary directory

private func makeTree(
    status: String = "Implemented",
    feature: String = "002",
    adrStatus: String = "Accepted",
    adrNumber: String = "1",
    omitADRDate: Bool = false
) throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("plan-index-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: root.appendingPathComponent("Specs/002-thing"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("Specs/_template"), withIntermediateDirectories: true)
    try fm.createDirectory(at: root.appendingPathComponent("ADRs"), withIntermediateDirectories: true)
    try """
    ---
    feature: \(feature)
    title: A thing
    phase: null
    status: \(status)
    updated: 2026-08-31
    ---
    # A thing
    """.write(to: root.appendingPathComponent("Specs/002-thing/plan.md"), atomically: true, encoding: .utf8)
    try "---\nfeature: NNN\ntitle: skeleton\nphase: null\nstatus: Planned\nupdated: YYYY-MM-DD\n---\n"
        .write(to: root.appendingPathComponent("Specs/_template/plan.md"), atomically: true, encoding: .utf8)
    let dateLine = omitADRDate ? "" : "date: 2026-05-07\n"
    try "---\nadr: \(adrNumber)\ntitle: A choice\nstatus: \(adrStatus)\n\(dateLine)---\n"
        .write(to: root.appendingPathComponent("ADRs/0001-a-choice.md"), atomically: true, encoding: .utf8)
    // Neither of these is a decision record and neither must be indexed.
    try "# not a record\n".write(to: root.appendingPathComponent("ADRs/NOTES.md"), atomically: true, encoding: .utf8)
    for p in ["Specs/README.md", "ADRs/README.md"] {
        try "# Index\n\n\(beginMarker)\n\(endMarker)\n".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
    }
    return root
}

@Test func generatesBothIndexesAndSkipsTheTemplate() throws {
    let root = try makeTree()
    defer { try? FileManager.default.removeItem(at: root) }

    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.isEmpty)
    #expect(report.specCount == 1) // _template is not a feature
    #expect(report.adrCount == 1)

    let specs = try String(contentsOf: root.appendingPathComponent("Specs/README.md"), encoding: .utf8)
    #expect(specs.contains("| 002 | A thing | — | Implemented | [plan.md](002-thing/plan.md) |"))
    let adrs = try String(contentsOf: root.appendingPathComponent("ADRs/README.md"), encoding: .utf8)
    #expect(adrs.contains("| 0001 | [A choice](0001-a-choice.md) | Accepted | 2026-05-07 |"))
}

@Test func checkModeFailsWhenTheIndexIsStale() throws {
    let root = try makeTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: true)
    #expect(report.isFailure)
    #expect(report.errors.contains { $0.contains("index is out of date") })
}

@Test func rejectsAStatusOutsideTheThreeAllowedValues() throws {
    let root = try makeTree(status: "Shipped")
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("status 'Shipped' is not one of") })
}

@Test func rejectsAFeatureNumberThatDisagreesWithItsFolder() throws {
    let root = try makeTree(feature: "007")
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("does not match folder") })
}

@Test func aSecondRunReportsNothingToDo() throws {
    let root = try makeTree()
    defer { try? FileManager.default.removeItem(at: root) }
    _ = Indexer(development: root).run(check: false)
    let second = Indexer(development: root).run(check: true)
    #expect(!second.isFailure)
    #expect(second.rewritten.isEmpty)
}

// MARK: - Decision records

@Test func rejectsADecisionRecordStatusOutsideTheThreeAllowedValues() throws {
    let root = try makeTree(adrStatus: "Draft")
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("status 'Draft' is not one of") })
}

@Test func reportsADecisionRecordMissingARequiredKey() throws {
    let root = try makeTree(omitADRDate: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.errors.contains { $0.contains("missing required key 'date'") })
}

@Test func skipsFilesInTheDecisionRecordsFolderThatAreNotNumbered() throws {
    let root = try makeTree()
    defer { try? FileManager.default.removeItem(at: root) }
    let report = Indexer(development: root).run(check: false)
    #expect(report.adrCount == 1) // NOTES.md and README.md are not records
    let index = try String(contentsOf: root.appendingPathComponent("ADRs/README.md"), encoding: .utf8)
    #expect(!index.contains("NOTES"))
}

@Test func padsDecisionRecordNumbersToFourDigits() throws {
    let root = try makeTree(adrNumber: "7")
    defer { try? FileManager.default.removeItem(at: root) }
    _ = Indexer(development: root).run(check: false)
    let index = try String(contentsOf: root.appendingPathComponent("ADRs/README.md"), encoding: .utf8)
    #expect(index.contains("| 0007 |"))
}

@Test func rendersADecisionRecordTable() {
    let out = Tables.adrTable([ADRRow(
        number: "0002",
        title: "A choice",
        status: "Superseded",
        date: "2026-05-07",
        file: "0002-a-choice.md"
    )])
    #expect(out.contains("| 0002 | [A choice](0002-a-choice.md) | Superseded | 2026-05-07 |"))
}

// MARK: - Nesting

@Test func aNestedFieldIsRefusedBecauseTheSchemaDoesNotDeclareIt() {
    #expect(throws: Frontmatter.ParseError("unknown field(s): nested")) {
        try Frontmatter.decode(
            PlanFrontmatter.self,
            from:
            "---\nfeature: 1\ntitle: t\nphase: null\nstatus: Planned\nupdated: 2026-01-01\nnested:\n  a: b\n---\n"
        )
    }
}
