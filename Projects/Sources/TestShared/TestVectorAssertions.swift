//
//  TestVectorAssertions.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import Testing

/// Provides cryptographic test assertions with verbose diagnostics
public enum TestVectorAssertions {
    /// Asserts that two byte arrays are equal with verbose hex dump on failure
    /// - Parameters:
    ///   - expected: Expected byte array
    ///   - actual: Actual byte array
    ///   - context: Description of what is being compared (e.g., "signature r-component")
    ///   - vectorId: Test vector identifier for error reporting
    ///   - sourceLocation: Source location for error reporting
    public static func assertEqual(
        expected: [UInt8],
        actual: [UInt8],
        context: String,
        vectorId: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard expected != actual else { return }

        let message = formatMismatch(
            context: context,
            vectorId: vectorId,
            expected: expected,
            actual: actual
        )

        Issue.record(Comment(rawValue: message), sourceLocation: sourceLocation)
    }

    /// Asserts that two Data objects are equal with verbose hex dump on failure
    /// - Parameters:
    ///   - expected: Expected data
    ///   - actual: Actual data
    ///   - context: Description of what is being compared
    ///   - vectorId: Test vector identifier for error reporting
    ///   - sourceLocation: Source location for error reporting
    public static func assertEqual(
        expected: Data,
        actual: Data,
        context: String,
        vectorId: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        assertEqual(
            expected: Array(expected),
            actual: Array(actual),
            context: context,
            vectorId: vectorId,
            sourceLocation: sourceLocation
        )
    }

    /// Asserts that a signature verification result matches expected
    /// - Parameters:
    ///   - expected: Expected verification result (true = valid)
    ///   - actual: Actual verification result
    ///   - vectorId: Test vector identifier
    ///   - publicKey: Public key used (hex) for diagnostics
    ///   - message: Message signed (hex) for diagnostics
    ///   - signature: Signature verified (hex) for diagnostics
    ///   - sourceLocation: Source location for error reporting
    public static func assertVerification(
        expected: Bool,
        actual: Bool,
        vectorId: String,
        publicKey: String,
        message: String,
        signature: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard expected != actual else { return }

        let result = expected ? "VALID" : "INVALID"
        let actualResult = actual ? "VALID" : "INVALID"

        let diagnosticMessage = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ VERIFICATION MISMATCH - Vector: \(vectorId)
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ Expected: \(result)
        ║ Actual:   \(actualResult)
        ╠──────────────────────────────────────────────────────────────────────────────
        ║ Public Key: \(publicKey)
        ║ Message:    \(message)
        ║ Signature:  \(signature)
        ╚══════════════════════════════════════════════════════════════════════════════
        """

        Issue.record(Comment(rawValue: diagnosticMessage), sourceLocation: sourceLocation)
    }

    /// Asserts that an ECDH shared secret matches expected
    /// - Parameters:
    ///   - expected: Expected shared secret (hex)
    ///   - actual: Actual shared secret (hex)
    ///   - vectorId: Test vector identifier
    ///   - publicKey: Public key used (hex) for diagnostics
    ///   - sourceLocation: Source location for error reporting
    public static func assertSharedSecret(
        expected: String,
        actual: String,
        vectorId: String,
        publicKey: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard expected.lowercased() != actual.lowercased() else { return }

        let diagnosticMessage = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ SHARED SECRET MISMATCH - Vector: \(vectorId)
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ Expected: \(expected)
        ║ Actual:   \(actual)
        ╠──────────────────────────────────────────────────────────────────────────────
        ║ Public Key: \(publicKey)
        ╚══════════════════════════════════════════════════════════════════════════════
        """

        Issue.record(Comment(rawValue: diagnosticMessage), sourceLocation: sourceLocation)
    }

    /// Asserts that an operation should fail (for invalid test vectors)
    /// - Parameters:
    ///   - vectorId: Test vector identifier
    ///   - operation: Description of the operation that should have failed
    ///   - sourceLocation: Source location for error reporting
    public static func assertShouldHaveFailed(
        vectorId: String,
        operation: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let diagnosticMessage = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ EXPECTED FAILURE DID NOT OCCUR - Vector: \(vectorId)
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ Operation: \(operation)
        ║ Expected:  Operation should have thrown an error or returned invalid
        ║ Actual:    Operation succeeded when it should have failed
        ╚══════════════════════════════════════════════════════════════════════════════
        """

        Issue.record(Comment(rawValue: diagnosticMessage), sourceLocation: sourceLocation)
    }

    // MARK: - Private Helpers

    private static func formatMismatch(
        context: String,
        vectorId: String,
        expected: [UInt8],
        actual: [UInt8]
    ) -> String {
        var output = """

        ╔══════════════════════════════════════════════════════════════════════════════
        ║ MISMATCH: \(context) - Vector: \(vectorId)
        ╠══════════════════════════════════════════════════════════════════════════════
        ║ Expected (\(expected.count) bytes):
        \(hexDump(expected, prefix: "║   "))
        ╠──────────────────────────────────────────────────────────────────────────────
        ║ Actual (\(actual.count) bytes):
        \(hexDump(actual, prefix: "║   "))
        """

        // Add diff if lengths match
        if expected.count == actual.count {
            let diffIndices = zip(expected, actual).enumerated()
                .filter { $0.element.0 != $0.element.1 }
                .map { $0.offset }

            if !diffIndices.isEmpty {
                output += """

                ╠──────────────────────────────────────────────────────────────────────────────
                ║ Differences at byte indices: \(diffIndices.prefix(10).map(String.init).joined(separator: ", "))\(diffIndices.count > 10 ? "... (\(diffIndices.count) total)" : "")
                """
            }
        }

        output += "\n╚══════════════════════════════════════════════════════════════════════════════"

        return output
    }

    private static func hexDump(_ bytes: [UInt8], prefix: String, bytesPerLine: Int = 16) -> String {
        guard !bytes.isEmpty else { return "\(prefix)(empty)" }

        var lines: [String] = []

        for offset in stride(from: 0, to: bytes.count, by: bytesPerLine) {
            let lineBytes = bytes[offset..<min(offset + bytesPerLine, bytes.count)]
            let hex = lineBytes.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = lineBytes.map { byte -> Character in
                (0x20...0x7E).contains(byte) ? Character(UnicodeScalar(byte)) : "."
            }

            let hexPadded = hex.padding(toLength: bytesPerLine * 3 - 1, withPad: " ", startingAt: 0)
            lines.append(String(format: "%@%04x: %@  |%@|", prefix, offset, hexPadded, String(ascii)))
        }

        return lines.joined(separator: "\n")
    }
}

/// Extension to provide hex string conversion for byte arrays
public extension Array where Element == UInt8 {
    /// Returns a lowercase hex string representation
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// Extension to provide hex string conversion for Data
public extension Data {
    /// Returns a lowercase hex string representation
    var testHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
