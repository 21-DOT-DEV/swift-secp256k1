//
//  Schema.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026-present Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information

import Foundation
import YAML

/// A coding key that accepts any name, used only to see which fields a document
/// actually carried before the typed fields are read.
struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

/// Refuses any field the schema does not declare.
///
/// Decoding ignores unrecognised fields by default, which would let `adr:` pass
/// silently where `adrs:` was meant — the field would simply never arrive and the
/// mistake would never be reported. Checking the key set first closes that.
func rejectUnknownFields(_ decoder: Decoder, known: [String]) throws {
    let seen = try Set(decoder.container(keyedBy: AnyKey.self).allKeys.map(\.stringValue))
    let unknown = seen.subtracting(Set(known)).sorted()
    guard unknown.isEmpty else {
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "unknown field(s): \(unknown.joined(separator: ", "))"
        ))
    }
}

/// "2026-13-45" is well-formed YAML and a useless date. The date fields stay
/// text by design (see `updated`), but a text field still has to name a real
/// day. The shape and the calendar are both checked by hand: `DateComponents`
/// would happily roll an impossible day into the next month and call it valid.
private func isISODate(_ s: String) -> Bool {
    let parts = s.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
          parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
          parts.allSatisfy({ $0.allSatisfy(\.isNumber) }),
          let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
          (1...12).contains(month)
    else { return false }
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    let daysInMonth = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return day >= 1 && day <= daysInMonth[month - 1]
}

/// Raises a decode failure on a date field that is not a real calendar date.
func requireISODate(_ value: String, field: String) throws {
    guard isISODate(value) else {
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "field '\(field)' is not a calendar date (YYYY-MM-DD)"
        ))
    }
}

/// The block at the top of a `Specs/NNN-slug/plan.md`.
///
/// Every field is text. That is checked, not assumed: `feature: 002` decodes with
/// its leading zeros intact, and `updated: 2026-08-31` stays text rather than
/// becoming a date, so neither needs quoting in the files.
public struct PlanFrontmatter: Decodable, Sendable {
    public let feature: String
    public let title: String
    public let phase: String?
    public let status: String
    public let updated: String
    public let adrs: [Int]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case feature, title, phase, status, updated, adrs
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownFields(decoder, known: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.feature = try c.decode(String.self, forKey: .feature)
        self.title = try c.decode(String.self, forKey: .title)
        self.phase = try c.decodeIfPresent(String.self, forKey: .phase)
        self.status = try c.decode(String.self, forKey: .status)
        self.updated = try c.decode(String.self, forKey: .updated)
        try requireISODate(updated, field: "updated")
        self.adrs = try c.decodeIfPresent([Int].self, forKey: .adrs)
    }
}

/// The block at the top of an `ADRs/NNNN-slug.md`.
public struct ADRFrontmatter: Decodable, Sendable {
    public let adr: String
    public let title: String
    public let status: String
    public let date: String
    public let supersedes: [Int]?
    public let supersededBy: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case adr, title, status, date, supersedes
        case supersededBy = "superseded_by"
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownFields(decoder, known: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.adr = try c.decode(String.self, forKey: .adr)
        self.title = try c.decode(String.self, forKey: .title)
        self.status = try c.decode(String.self, forKey: .status)
        self.date = try c.decode(String.self, forKey: .date)
        try requireISODate(date, field: "date")
        self.supersedes = try c.decodeIfPresent([Int].self, forKey: .supersedes)
        self.supersededBy = try c.decodeIfPresent(String.self, forKey: .supersededBy)
    }
}

public enum Frontmatter {
    public struct ParseError: Error, Equatable {
        public let reason: String
        public init(_ reason: String) {
            self.reason = reason
        }
    }

    /// Splits the leading `---` fenced block off a document and decodes it.
    public static func decode<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        // A file written on Windows ends its lines with a carriage return before the
        // newline, which made every fence comparison below miss and reported a
        // perfectly good document as having no frontmatter at all.
        let text = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard text.hasPrefix("---\n") else { throw ParseError("missing frontmatter") }

        // Everything after the opening marker. Searching inside this slice rather
        // than the whole document is what makes the arithmetic safe: a match can
        // never land before the content starts. Searching the whole document found
        // the opening marker's own newline when the block was empty, producing a
        // backwards range that killed the process instead of reporting the problem.
        let rest = text[text.index(text.startIndex, offsetBy: 4)...]

        // Exactly the fence, not merely starting with it: a body line such as
        // "---foo" was being reported as an empty block rather than as a document
        // whose frontmatter is never closed.
        if rest.prefix(while: { $0 != "\n" }) == "---" {
            throw ParseError("frontmatter is empty")
        }

        // The terminator is a line that is exactly three dashes: either followed by a
        // newline, or ending the document. Matching "\n---" anywhere accepted a
        // horizontal rule or a line such as "--- notes" in the body, so a document
        // that never closed its frontmatter parsed anyway, from whatever came first.
        let close: Range<Substring.Index>
        if let terminator = rest.range(of: "\n---\n") {
            close = terminator
        } else if rest.hasSuffix("\n---"), let last = rest.range(of: "\n---", options: .backwards) {
            close = last
        } else {
            throw ParseError("frontmatter is not closed with ---")
        }

        let block = String(rest[rest.startIndex..<close.lowerBound])
        guard !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ParseError("frontmatter is empty")
        }
        do {
            return try YAMLDecoder().decode(T.self, from: block)
        } catch let error as DecodingError {
            throw ParseError(describe(error))
        } catch {
            throw ParseError("\(error)")
        }
    }

    static func describe(_ error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, _):
            return "frontmatter is missing required key '\(key.stringValue)'"
        case let .dataCorrupted(ctx):
            return ctx.debugDescription
        case let .typeMismatch(type, ctx):
            let field = ctx.codingPath.last?.stringValue ?? "?"
            return "field '\(field)' is not a \(type)"
        case let .valueNotFound(_, ctx):
            return "field '\(ctx.codingPath.last?.stringValue ?? "?")' has no value"
        @unknown default:
            return "\(error)"
        }
    }
}
