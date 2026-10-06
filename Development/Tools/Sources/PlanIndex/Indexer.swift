//
//  Indexer.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026-present Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information

import Foundation

public let beginMarker = "<!-- BEGIN GENERATED INDEX -->"
public let endMarker = "<!-- END GENERATED INDEX -->"
public let softLineLimit = 250

public let specStatuses = ["Planned", "In Progress", "Implemented"]
public let adrStatuses = ["Proposed", "Accepted", "Superseded"]

public struct Report: Sendable {
    public var errors: [String] = []
    public var notes: [String] = []
    public var rewritten: [String] = []
    public var specCount = 0
    public var adrCount = 0
    public var isFailure: Bool {
        !errors.isEmpty
    }
}

public struct SpecRow: Equatable, Sendable {
    public let number: String, title: String, phase: String, status: String, link: String
}

public struct ADRRow: Equatable, Sendable {
    public let number: String, title: String, status: String, date: String, file: String
}

public enum Tables {
    /// Escaping happens here, at the moment a value becomes Markdown, rather than
    /// when the file is read. A title is data; this tool renders it to more than one
    /// place, and refusing a character because a table dislikes it would reject a
    /// value that is perfectly valid everywhere else.
    ///
    /// The escapes are split by context, because two parsers eat them at
    /// different levels. The table splits a row on unescaped pipes and unescapes
    /// `\\` and `\|` before the cell ever reaches inline parsing — so `\|` is
    /// needed everywhere, and `\` needs one doubling inside a code span for the
    /// table level to leave it alone. Outside a span the inline level eats
    /// another pair, so `\` is doubled twice there, and entities (`&amp;`,
    /// `&lt;`, `&gt;`) apply — inside a span they would print literally, since a
    /// code span decodes neither escapes nor entities. A newline always ends
    /// the row, wherever it sits.
    static func cell(_ s: String) -> String {
        render(s)
    }

    /// Text inside `[...]`: an unmatched bracket ends the link early — but only
    /// outside a code span, where the bracket is text the span shows as written.
    static func linkText(_ s: String) -> String {
        render(s, escapeBrackets: true)
    }

    /// A destination inside `(...)`: an unmatched parenthesis ends the link
    /// early. Destinations are not parsed for code spans, so the segment pass
    /// is skipped and the escaping applies to the whole value.
    static func linkDestination(_ s: String) -> String {
        render(s, codeSpans: false)
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    }

    /// Applies the escaping rules per segment: inline escaping outside code
    /// spans, table-level escaping everywhere. See `cell` for the rules.
    private static func render(_ s: String, escapeBrackets: Bool = false, codeSpans: Bool = true) -> String {
        (codeSpans ? splitAtCodeSpans(of: s) : [(text: s[...], inCode: false)])
            .map { escape($0.text, inCode: $0.inCode, escapeBrackets: escapeBrackets) }
            .joined()
    }

    private static func escape(_ text: Substring, inCode: Bool, escapeBrackets: Bool) -> String {
        // The backslash goes first: escaping it afterwards would consume the
        // escapes added before it. `&` likewise precedes the entities it
        // introduces. Inside a code span the table parser still consumes `\\`,
        // so one doubling is required even there; outside, the inline parser
        // consumes a second pair.
        var t = String(text)
            .replacingOccurrences(of: "\\", with: inCode ? "\\\\" : "\\\\\\\\")
        if !inCode {
            t = t.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            if escapeBrackets {
                t = t.replacingOccurrences(of: "[", with: "\\[")
                    .replacingOccurrences(of: "]", with: "\\]")
            }
        }
        return t.replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    /// Splits the value at backtick code spans. CommonMark's rule: an opening
    /// run of n backticks closes at the next run of exactly n — shorter and
    /// longer runs inside are content. A run with no matching closer is literal
    /// text, so it neither opens a span nor stops the scan for a later one.
    private static func splitAtCodeSpans(of s: String) -> [(text: Substring, inCode: Bool)] {
        var out: [(Substring, Bool)] = []
        var i = s.startIndex
        while i < s.endIndex {
            guard s[i] == "`" else {
                let j = s[i...].firstIndex(of: "`") ?? s.endIndex
                out.append((s[i..<j], false))
                i = j
                continue
            }
            var runEnd = i
            while runEnd < s.endIndex, s[runEnd] == "`" {
                runEnd = s.index(after: runEnd)
            }
            let n = s.distance(from: i, to: runEnd)
            var j = runEnd, closeEnd: String.Index?
            while j < s.endIndex {
                if s[j] == "`" {
                    var k = j
                    while k < s.endIndex, s[k] == "`" {
                        k = s.index(after: k)
                    }
                    if s.distance(from: j, to: k) == n {
                        closeEnd = k
                        break
                    }
                    j = k
                } else {
                    j = s.index(after: j)
                }
            }
            if let closeEnd {
                out.append((s[i..<closeEnd], true))
                i = closeEnd
            } else {
                out.append((s[i..<runEnd], false))
                i = runEnd
            }
        }
        return out
    }

    public static func specTable(_ rows: [SpecRow]) -> String {
        (["| # | Feature | Phase | Status | Plan |", "|---|---|---|---|---|"]
            + rows.map { "| \(cell($0.number)) | \(cell($0.title)) | \(cell($0.phase)) | \(cell($0.status)) | [plan.md](\(linkDestination($0.link))) |" })
            .joined(separator: "\n")
    }

    public static func adrTable(_ rows: [ADRRow]) -> String {
        (["| # | Decision | Status | Date |", "|---|---|---|---|"]
            + rows.map { "| \(cell($0.number)) | [\(linkText($0.title))](\(linkDestination($0.file))) | \(cell($0.status)) | \(cell($0.date)) |" })
            .joined(separator: "\n")
    }

    /// Counts dividers that are not escaped, so `\\|` inside a cell does not
    /// split it.
    static func columnCount(_ line: String) -> Int {
        var bars = 0, escaped = false
        for ch in line {
            if escaped {
                escaped = false
                continue
            }
            if ch == "\\" {
                escaped = true
                continue
            }
            if ch == "|" {
                bars += 1
            }
        }
        return max(0, bars - 1)
    }

    /// Rows whose column count disagrees with the header above them. A stray
    /// divider inside prose silently adds a column and renders the row wrong,
    /// which is how one such row survived at least one prior review.
    public static func malformedRows(in text: String) -> [(line: Int, columns: Int, expected: Int)] {
        var out: [(line: Int, columns: Int, expected: Int)] = []
        var expected: Int? = nil
        var rowsSeen = 0
        var fence: (marker: Character, length: Int)? = nil
        for (index, raw) in logicalLines(text).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            // A fenced code block can hold a table or a shell pipeline whose
            // leading bar is data, not structure; none of it is a row. The
            // closing fence must carry the same character, be at least as long
            // as the opening one, and hold no info string — a ``` line inside a
            // ```` ```` ```` fence is content, not a closer.
            if let first = line.first, first == "`" || first == "~",
               line.count >= 3, line.prefix(3).allSatisfy({ $0 == first }) {
                let run = line.prefix(while: { $0 == first })
                if let open = fence, open.marker == first, run.count >= open.length,
                   line.dropFirst(run.count).allSatisfy({ $0 == " " }) {
                    fence = nil
                } else if fence == nil {
                    fence = (first, run.count)
                }
                // A table cannot straddle a fence; without this reset the next
                // table's header was measured against the previous one's.
                expected = nil
                rowsSeen = 0
                continue
            }
            guard fence == nil else { continue }
            guard line.hasPrefix("|") else { expected = nil
                rowsSeen = 0
                continue
            }
            if expected == nil {
                // A prose line such as "| - an item" carries one divider and no
                // columns. Treating it as a header would measure every real row
                // that follows against nothing.
                let n = columnCount(line)
                if n > 0 {
                    expected = n
                    rowsSeen = 1
                }
                continue
            }
            // The row straight after the header is the delimiter, by definition of
            // the format. Recognising it by its punctuation instead meant a genuinely
            // malformed row like "| - |" was mistaken for one and never reported.
            if rowsSeen == 1 {
                rowsSeen = 2
                continue
            }
            let n = columnCount(line)
            if n != expected! {
                out.append((line: index + 1, columns: n, expected: expected!))
            }
        }
        return out
    }

    /// Swaps the block between the markers. Returns nil when a marker is absent,
    /// which is an error rather than something to paper over.
    public static func replacingIndex(in text: String, with table: String) -> String? {
        guard let b = text.range(of: beginMarker), let e = text.range(of: endMarker), b.upperBound <= e.lowerBound
        else { return nil }
        return text.replacingCharacters(
            in: b.lowerBound..<e.upperBound,
            with: "\(beginMarker)\n\(table)\n\(endMarker)"
        )
    }
}

public struct Indexer {
    let development: URL
    let fm = FileManager.default
    let writeFile: (String, URL) throws -> Void

    /// Normalised once, here, so every path derived from it shares one form. Mixing
    /// a relative or unresolved base with the absolute, symlink-resolved paths the
    /// directory walker returns produced relative paths that pointed nowhere.
    ///
    /// `writeFile` is a seam for tests: a write failure must be reportable on any
    /// platform, and permission bits cannot supply one when the suite runs as
    /// root — root writes anyway.
    public init(
        development: URL,
        writeFile: @escaping (String, URL) throws -> Void = {
            try $0.write(to: $1, atomically: true, encoding: .utf8)
        }
    ) {
        self.development = development.absoluteURL.resolvingSymlinksInPath().standardizedFileURL
        self.writeFile = writeFile
    }

    func read(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    /// Names the folder that was actually read, so an error never points at a
    /// directory the tool did not open.
    func rel(_ url: URL) -> String {
        // Both sides are resolved first. The directory walker hands back paths with
        // symlinks already followed while the base path is as given, so on a system
        // where /tmp points at /private/tmp the prefix failed to strip and produced a
        // mangled path that pointed nowhere.
        let base = development.path
        let full = url.absoluteURL.resolvingSymlinksInPath().standardizedFileURL.path
        let suffix = full.hasPrefix(base + "/") ? String(full.dropFirst(base.count + 1)) : full
        return development.lastPathComponent + "/" + suffix
    }

    func noteIfLong(_ url: URL, _ text: String, into report: inout Report) {
        let n = logicalLines(text).count
        if n > softLineLimit {
            report.notes.append("\(rel(url)): \(n) lines (over the \(softLineLimit)-line advisory mark)")
        }
    }

    /// Returns nil when the folder itself could not be listed, which is a different
    /// problem from an empty folder and must not be reported as a missing index file.
    public func collectSpecs(into report: inout Report) -> [SpecRow]? {
        let specs = development.appendingPathComponent("Specs")
        let dirs: [String]
        do { dirs = try fm.contentsOfDirectory(atPath: specs.path).sorted() }
        catch {
            report.errors.append("\(rel(specs)): \((error as NSError).localizedDescription)")
            return nil
        }
        // The numbers a plan's `adrs:` list may legitimately name. Taken from the
        // record files on disk rather than their frontmatter: a reference resolves
        // to a record that exists, so the file name is the claim that matters.
        // nil when the folder cannot be listed — collectADRs reports that itself.
        let recordNumbers = adrNumberSet()
        // Two branches can each add the next number and merge cleanly because the
        // names differ; the counter must still be global. A duplicate is an error
        // naming both folders, and the late row never reaches the index.
        var seen: [String: String] = [:]
        var rows: [SpecRow] = []
        for name in dirs where !name.hasPrefix("_") && !name.hasPrefix(".") {
            let dir = specs.appendingPathComponent(name)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let plan = dir.appendingPathComponent("plan.md")
            let text: String
            do { text = try read(plan) }
            catch {
                // "Absent" is claimed only when the file really is absent. Anything
                // else reports the system's own reason, which already separates
                // missing, forbidden and malformed in plain words.
                report.errors.append(fm.fileExists(atPath: plan.path)
                    ? "\(rel(plan)): \((error as NSError).localizedDescription)"
                    : "\(rel(dir)): has no plan.md")
                continue
            }
            let front: PlanFrontmatter
            do { front = try Frontmatter.decode(PlanFrontmatter.self, from: text) }
            catch { report.errors.append("\(rel(plan)): \((error as? Frontmatter.ParseError)?.reason ?? "\(error)")")
                continue
            }

            let padded = String(repeating: "0", count: max(0, 3 - front.feature.count)) + front.feature
            // The whole leading run of digits, not merely a prefix: "0220-foo" starts
            // with "022", so a prefix test paired feature 022 with folder 0220 and
            // published a row whose number and link disagreed.
            if String(name.prefix(while: \.isNumber)) != padded {
                report.errors.append("\(rel(plan)): feature '\(front.feature)' does not match folder '\(name)'")
            }
            if !specStatuses.contains(front.status) {
                report.errors.append("\(rel(plan)): status '\(front.status)' is not one of \(specStatuses)")
            }
            if let prior = seen.updateValue(name, forKey: padded) {
                report.errors.append(
                    "\(rel(dir)): number \(padded) is already used by \(rel(specs.appendingPathComponent(prior)))"
                )
                continue
            }
            if let wanted = front.adrs, let recordNumbers {
                for ref in wanted where !recordNumbers.contains(pad4(ref)) {
                    report.errors.append("\(rel(plan)): adrs: \(ref) names no decision record")
                }
            }
            noteIfLong(plan, text, into: &report)
            rows.append(SpecRow(
                number: padded,
                title: front.title,
                phase: front.phase ?? "—",
                status: front.status,
                link: "\(name)/plan.md"
            ))
        }
        return rows
    }

    /// The digit runs of the record files on disk — what a `supersedes:` or
    /// `adrs:` reference resolves to. nil when the folder cannot be listed.
    private func adrNumberSet() -> Set<String>? {
        let dir = development.appendingPathComponent("ADRs")
        guard let listing = try? fm.contentsOfDirectory(atPath: dir.path) else { return nil }
        return Set(listing.filter { $0.hasSuffix(".md") && $0.first?.isNumber == true }
            .map { String($0.prefix(while: \.isNumber)) })
    }

    /// A numeric reference means the four-digit record number: 6 -> "0006".
    private func pad4(_ n: Int) -> String {
        let s = String(n)
        return String(repeating: "0", count: max(0, 4 - s.count)) + s
    }

    /// Returns nil when the folder itself could not be listed. See `collectSpecs`.
    public func collectADRs(into report: inout Report) -> [ADRRow]? {
        let adrs = development.appendingPathComponent("ADRs")
        let listing: [String]
        do { listing = try fm.contentsOfDirectory(atPath: adrs.path) }
        catch {
            report.errors.append("\(rel(adrs)): \((error as NSError).localizedDescription)")
            return nil
        }
        let files = listing.filter { $0.hasSuffix(".md") && $0.first?.isNumber == true }.sorted()
        // What a supersede reference may point at: the numbers on disk. See
        // collectSpecs for why the counter must be global across files.
        let numbers = Set(files.map { String($0.prefix(while: \.isNumber)) })
        var seen: [String: String] = [:]
        // Number -> decoded record, for the second pass below: a supersede chain
        // is only sound when both records agree on it, and that agreement cannot
        // be checked until every frontmatter block has been read.
        var fronts: [String: (name: String, front: ADRFrontmatter)] = [:]
        var rows: [ADRRow] = []
        for name in files {
            let url = adrs.appendingPathComponent(name)
            let text: String
            do { text = try read(url) }
            catch {
                // Skipping silently would make an unreadable record indistinguishable
                // from one that was never written.
                report.errors.append("\(rel(url)): \((error as NSError).localizedDescription)")
                continue
            }
            let front: ADRFrontmatter
            do { front = try Frontmatter.decode(ADRFrontmatter.self, from: text) }
            catch { report.errors.append("\(rel(url)): \((error as? Frontmatter.ParseError)?.reason ?? "\(error)")")
                continue
            }

            if !adrStatuses.contains(front.status) {
                report.errors.append("\(rel(url)): status '\(front.status)' is not one of \(adrStatuses)")
            }
            let paddedADR = String(repeating: "0", count: max(0, 4 - front.adr.count)) + front.adr
            // Same trap as the feature number: without this a record numbered 0002
            // inside 0001-a.md produced a row whose number and link disagreed.
            if String(name.prefix(while: \.isNumber)) != paddedADR {
                report.errors.append("\(rel(url)): adr '\(front.adr)' does not match file '\(name)'")
            }
            if let prior = seen.updateValue(name, forKey: paddedADR) {
                report.errors.append(
                    "\(rel(url)): number \(paddedADR) is already used by \(rel(adrs.appendingPathComponent(prior)))"
                )
                continue
            }
            for ref in front.supersedes ?? [] {
                let target = pad4(ref)
                if target == paddedADR {
                    report.errors.append("\(rel(url)): supersedes names this record itself")
                } else if !numbers.contains(target) {
                    report.errors.append("\(rel(url)): supersedes: \(ref) names no decision record")
                }
            }
            if let by = front.supersededBy {
                // The leading digits carry the number, so "0006" and
                // "0006-its-slug" both resolve to record 0006.
                let digits = String(by.prefix(while: \.isNumber))
                if digits.isEmpty {
                    report.errors.append("\(rel(url)): superseded_by '\(by)' names no record number")
                } else {
                    let target = String(repeating: "0", count: max(0, 4 - digits.count)) + digits
                    if target == paddedADR {
                        report.errors.append("\(rel(url)): superseded_by names this record itself")
                    } else if !numbers.contains(target) {
                        report.errors.append("\(rel(url)): superseded_by '\(by)' names no decision record")
                    }
                }
            }
            // The README's contract: a record marked Superseded points at the
            // record that replaced it. Without the check a record could be
            // retired while pointing nowhere. The converse holds too — a record
            // that names a replacement while claiming to still stand is just as
            // broken.
            if front.status == "Superseded", front.supersededBy == nil {
                report.errors.append("\(rel(url)): is Superseded but names no replacement (superseded_by)")
            }
            if front.status != "Superseded", front.supersededBy != nil {
                report.errors.append(
                    "\(rel(url)): superseded_by is set but status is '\(front.status)'"
                )
            }
            noteIfLong(url, text, into: &report)
            fronts[paddedADR] = (name, front)
            rows.append(ADRRow(
                number: paddedADR,
                title: front.title,
                status: front.status,
                date: front.date,
                file: name
            ))
        }
        // Second pass: the checks that need a peer's frontmatter. A chain is
        // sound only when the superseded record points at its replacement AND
        // the replacement points back — either side naming without the other
        // lets the two records quietly disagree.
        for (paddedADR, entry) in fronts.sorted(by: { $0.key < $1.key }) {
            let url = adrs.appendingPathComponent(entry.name)
            if entry.front.status == "Superseded", let by = entry.front.supersededBy {
                let digits = String(by.prefix(while: \.isNumber))
                let target = String(repeating: "0", count: max(0, 4 - digits.count)) + digits
                if let peer = fronts[target], target != paddedADR,
                   !(peer.front.supersedes ?? []).contains(where: { pad4($0) == paddedADR }) {
                    report.errors.append(
                        "\(rel(url)): replacement \(target) does not list this record in supersedes"
                    )
                }
            }
            for ref in entry.front.supersedes ?? [] {
                let target = pad4(ref)
                guard let peer = fronts[target], target != paddedADR else { continue }
                // Judge only what this field asserts: that the superseded record
                // points back at this one. The peer's status is the peer's own
                // field — when it is wrong the check above has already said so on
                // the peer's record, and reporting it here would print "does not
                // point back" beside a pointer that does exist.
                let back = peer.front.supersededBy.map { String($0.prefix(while: \.isNumber)) } ?? ""
                let backPadded = String(repeating: "0", count: max(0, 4 - back.count)) + back
                if backPadded != paddedADR {
                    report.errors.append(
                        peer.front.supersededBy == nil
                            ? "\(rel(url)): supersedes \(target) but \(rel(adrs.appendingPathComponent(peer.name))) does not point back"
                            : "\(rel(url)): supersedes \(target), but \(target) names \(peer.front.supersededBy!) as its replacement"
                    )
                }
            }
        }
        // Finally, every superseded_by chain must end at a record that still
        // stands. Each record names at most one replacement, so the only way a
        // walk fails to end is a loop — which retires every decision on it and
        // leaves nothing standing. resolved memoises finished records so a loop
        // is reported once, not once per member.
        var resolved: Set<String> = []
        for start in fronts.keys.sorted() where !resolved.contains(start) {
            var chain: [String] = []
            var loop: [String]? = nil
            var cur = start
            while let entry = fronts[cur], entry.front.status == "Superseded",
                  let by = entry.front.supersededBy {
                let digits = String(by.prefix(while: \.isNumber))
                let target = String(repeating: "0", count: max(0, 4 - digits.count)) + digits
                // A missing, empty or self target already carries its own error.
                guard !digits.isEmpty, target != cur, fronts[target] != nil else { break }
                chain.append(cur)
                if let hit = chain.firstIndex(of: target) {
                    loop = Array(chain[hit...]) + [target]
                    break
                }
                guard !resolved.contains(target) else { break }
                cur = target
            }
            if let loop {
                let entry = fronts[loop.dropLast().min()!]!
                report.errors.append(
                    "\(rel(adrs.appendingPathComponent(entry.name))): supersede chain never reaches a standing decision (\(loop.joined(separator: " → "))) — to bring back an earlier decision, add a new record that supersedes the current one"
                )
            }
            resolved.formUnion(chain)
            resolved.insert(start)
        }
        return rows
    }

    func write(_ table: String, into url: URL, check: Bool, into report: inout Report) {
        let text: String
        do { text = try read(url) }
        catch {
            report.errors.append("\(rel(url)): \((error as NSError).localizedDescription)")
            return
        }
        guard let updated = Tables.replacingIndex(in: text, with: table) else {
            report.errors.append("\(rel(url)): missing the generated-index markers")
            return
        }
        guard updated != text else { return }
        if check {
            report.errors.append("\(rel(url)): index is out of date (run: swift run --package-path Development/Tools plans)")
        } else {
            do {
                try writeFile(updated, url)
                report.rewritten.append(rel(url))
            } catch {
                // "Could not be written" tells nobody whether the disk is full, the
                // file is read-only, or the folder is not writable.
                report.errors.append("\(rel(url)): \((error as NSError).localizedDescription)")
            }
        }
    }

    /// Every document in the tree, not just the generated ones: a stray divider in
    /// hand-written prose breaks its row exactly the same way.
    func checkTableShapes(into report: inout Report) {
        guard let walker = fm.enumerator(at: development, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in walker {
            guard url.pathExtension == "md", !url.path.contains("/.build/") else { continue }
            let text: String
            do { text = try read(url) }
            catch {
                // Previously skipped with a comment claiming these were reported
                // elsewhere. That was only true for plans, records and the two index
                // files; a corrupt charter or roadmap page vanished without a word.
                report.errors.append("\(rel(url)): \((error as NSError).localizedDescription)")
                continue
            }
            for row in Tables.malformedRows(in: text) {
                report.errors.append(
                    "\(rel(url)):\(row.line): table row has \(row.columns) columns, header has \(row.expected)"
                )
            }
        }
    }

    public func run(check: Bool) -> Report {
        var report = Report()
        let specs = collectSpecs(into: &report)
        let adrs = collectADRs(into: &report)
        report.specCount = specs?.count ?? 0
        report.adrCount = adrs?.count ?? 0
        // A folder that could not be listed has already been reported; writing an
        // index into it would only add a second message about the same problem.
        if let specs {
            write(Tables.specTable(specs), into: development.appendingPathComponent("Specs/README.md"), check: check, into: &report)
        }
        if let adrs {
            write(Tables.adrTable(adrs), into: development.appendingPathComponent("ADRs/README.md"), check: check, into: &report)
        }
        // After the writes, so an index this run has just corrected is not also
        // reported as malformed.
        checkTableShapes(into: &report)
        // One file can be reached by two passes; a reader does not need telling twice.
        var seen = Set<String>()
        report.errors = report.errors.filter { seen.insert($0).inserted }
        return report
    }
}

/// \r\n is one Character, so `split(separator: "\n")` never fires on a
/// Windows-ending file — every line-based check would see a single "line" and
/// silently pass. Substring replacement is cluster-proof; the second pass also
/// flattens the lone-\r endings of pre-OS X vintage.
private func logicalLines(_ text: String) -> [Substring] {
    text.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
}
