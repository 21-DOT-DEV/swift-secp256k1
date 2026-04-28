#!/usr/bin/env swift

//
//  rewrite-docc-shared-paths.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license. See LICENSE for details.
//
//  Rewrites SharedSourcesPlugin's plugin-output paths back to canonical
//  Sources/Shared/ paths inside a generated DocC archive.
//
//  Why this exists:
//
//    Plugins/SharedSourcesPlugin/Plugin.swift `cp`s every Sources/Shared/*.swift
//    into each target's plugin work directory before compilation, so DocC's
//    symbol-graph extractor records the COPIED path:
//
//      .build/plugins/outputs/swift-secp256k1/<TARGET>/destination/SharedSourcesPlugin/<File>.swift
//
//    `--source-service-base-url` then prepends a GitHub URL in front of that
//    path, producing a 404 link for every Shared/ symbol in the released
//    archive. We rewrite the recorded path to the file's actual location
//    under Sources/Shared/<...>/<File>.swift so the GitHub URL resolves.
//
//    Tested 2026-04-27: replacing `cp` with `ln -s` in the plugin does NOT
//    fix this — swift-symbolgraph-extract records the symlink path, not the
//    target. Post-processing is the remaining path.
//
//  Usage:
//
//      swift Scripts/rewrite-docc-shared-paths.swift \
//          <path/to/Target.doccarchive> \
//          <path/to/Sources/Shared>
//
//  Exit codes:
//      0  success
//      1  usage error
//      2  I/O failure or duplicate basenames in Sources/Shared/
//      3  archive references a basename not present in Sources/Shared/
//

import Foundation

// MARK: - Pattern

/// Matches the broken plugin-output path in DocC's `remoteSource.url` strings.
///
/// DocC encodes forward slashes as `\/` in JSON; the alternation `(?:\\/|/)`
/// accepts both forms so we're robust if DocC ever stops escaping. Capture
/// group 1 is the filename basename (e.g. `Context.swift` or
/// `ECDSA+PrivateKey.swift`), which we look up in the basename → relative
/// path map built from `Sources/Shared/`.
let brokenPathPattern = #/\.build(?:\\/|/)plugins(?:\\/|/)outputs(?:\\/|/)swift-secp256k1(?:\\/|/)[^/"#\\]+(?:\\/|/)destination(?:\\/|/)SharedSourcesPlugin(?:\\/|/)([^/"#\\]+\.swift)/#

// MARK: - Types

struct ScriptError: Error, CustomStringConvertible {
    var description: String
}

struct RewriteStats {
    var filesScanned = 0
    var filesRewritten = 0
    var occurrencesRewritten = 0
    var unmappedBasenames: Set<String> = []
}

// MARK: - Indexing

/// Walks `root` and returns a `basename → repo-relative path` map.
///
/// Fails on duplicate basenames: the upstream `cp` in
/// `Plugins/SharedSourcesPlugin/Plugin.swift` would silently last-write-wins,
/// so a collision is a corruption risk we want to surface here, not later.
func indexSharedSources(at root: URL) throws -> [String: String] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw ScriptError(description: "failed to enumerate \(root.path)")
    }

    let cwd = FileManager.default.currentDirectoryPath + "/"
    var index: [String: String] = [:]
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        let basename = url.lastPathComponent
        let absolute = url.standardizedFileURL.path
        let relative = absolute.hasPrefix(cwd) ? String(absolute.dropFirst(cwd.count)) : absolute
        if let existing = index[basename] {
            throw ScriptError(
                description:
                "duplicate basename \(basename) in Sources/Shared/ (\(existing) vs \(relative))"
            )
        }
        index[basename] = relative
    }
    return index
}

// MARK: - Rewrite

/// Walks `<archive>/data/**/*.json` and rewrites broken plugin-output paths
/// in place. Any basename referenced in the archive but not in `basenames` is
/// recorded in `stats.unmappedBasenames`; callers should treat a non-empty
/// set as fatal — the archive would still ship broken links.
func rewriteArchive(at archive: URL, basenames: [String: String]) throws -> RewriteStats {
    let dataRoot = archive.appending(path: "data")
    guard FileManager.default.fileExists(atPath: dataRoot.path) else {
        throw ScriptError(description: "archive data dir not found: \(dataRoot.path)")
    }
    guard let enumerator = FileManager.default.enumerator(
        at: dataRoot,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw ScriptError(description: "failed to enumerate \(dataRoot.path)")
    }

    var stats = RewriteStats()
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "json" {
        stats.filesScanned += 1
        let original = try String(contentsOf: fileURL, encoding: .utf8)

        var fileOccurrences = 0
        let rewritten = original.replacing(brokenPathPattern) { match in
            let basename = String(match.output.1)
            guard let realRel = basenames[basename] else {
                stats.unmappedBasenames.insert(basename)
                return String(match.output.0)
            }
            fileOccurrences += 1
            // Preserve DocC's JSON-escaped form so the spliced substring
            // remains a syntactically valid JSON string.
            return realRel.replacingOccurrences(of: "/", with: ##"\/"##)
        }

        if fileOccurrences > 0 {
            try rewritten.write(to: fileURL, atomically: true, encoding: .utf8)
            stats.filesRewritten += 1
            stats.occurrencesRewritten += fileOccurrences
        }
    }
    return stats
}

// MARK: - Main

func reportError(_ message: String) {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write(Data("usage: \(args[0]) <archive.doccarchive> <Sources/Shared>\n".utf8))
    exit(1)
}

let archiveURL = URL(fileURLWithPath: args[1])
let sharedURL = URL(fileURLWithPath: args[2])

let basenames: [String: String]
do {
    basenames = try indexSharedSources(at: sharedURL)
} catch {
    reportError("\(error)")
    exit(2)
}

print("Indexed \(basenames.count) shared sources from \(args[2])")

let stats: RewriteStats
do {
    stats = try rewriteArchive(at: archiveURL, basenames: basenames)
} catch {
    reportError("\(error)")
    exit(2)
}

print("Scanned \(stats.filesScanned) JSON files; rewrote \(stats.filesRewritten) (\(stats.occurrencesRewritten) occurrences)")

if !stats.unmappedBasenames.isEmpty {
    let list = stats.unmappedBasenames.sorted().joined(separator: ", ")
    reportError("\(stats.unmappedBasenames.count) basename(s) referenced in archive but not found in \(args[2]): \(list)")
    exit(3)
}

print("Zero-ghost guard passed")
