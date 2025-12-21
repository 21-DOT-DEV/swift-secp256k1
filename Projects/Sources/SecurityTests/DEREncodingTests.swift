//
//  DEREncodingTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import Testing

@testable import P256K

/// Tests for DER encoding strictness vulnerabilities (DE-001 through DE-004).
///
/// These tests ensure the library correctly rejects non-strict DER encodings
/// that could lead to signature malleability or parsing vulnerabilities
/// (CVE-2020-14966, CVE-2020-13822, CVE-2019-14859, CVE-2016-1000342).
@Suite("DER Encoding Security Tests")
struct DEREncodingTests {
    // MARK: - DE-001: Reject BER padding

    @Test("DE-001: Reject DER signature with BER-style length padding")
    func rejectBERPadding() throws {
        let berPaddedSignature = SecurityTestVectors.DEREncoding.berPadding

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: berPaddedSignature)
        }
    }

    // MARK: - DE-002: Reject unnecessary 0x00 prefix

    @Test("DE-002: Reject DER signature with unnecessary leading zero")
    func rejectUnnecessaryPadding() throws {
        let paddedSignature = SecurityTestVectors.DEREncoding.unnecessaryPadding

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: paddedSignature)
        }
    }

    // MARK: - DE-003: Reject non-minimal length encoding

    @Test("DE-003: Reject DER signature with non-minimal length encoding")
    func rejectNonMinimalLength() throws {
        let nonMinimalSignature = SecurityTestVectors.DEREncoding.nonMinimalLength

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: nonMinimalSignature)
        }
    }

    // MARK: - DE-004: Accept strict DER

    @Test("DE-004: Accept properly formatted strict DER signature")
    func acceptStrictDER() throws {
        let validDER = SecurityTestVectors.DEREncoding.validStrictDER

        // This should parse successfully
        let signature = try P256K.Signing.ECDSASignature(derRepresentation: validDER)

        // Verify we can get the compact representation
        let compact = try signature.compactRepresentation
        #expect(compact.count == 64, "Compact signature should be 64 bytes")
    }

    // MARK: - Additional DER edge cases

    @Test("Empty DER signature should be rejected")
    func rejectEmptyDER() throws {
        let emptySignature: [UInt8] = []

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: emptySignature)
        }
    }

    @Test("Truncated DER signature should be rejected")
    func rejectTruncatedDER() throws {
        // Just the sequence header, no content
        let truncatedSignature: [UInt8] = [0x30, 0x44]

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: truncatedSignature)
        }
    }

    @Test("DER signature with wrong tag should be rejected")
    func rejectWrongTag() throws {
        // Use 0x31 (SET) instead of 0x30 (SEQUENCE)
        var wrongTag = SecurityTestVectors.DEREncoding.validStrictDER
        wrongTag[0] = 0x31

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: wrongTag)
        }
    }

    @Test("DER signature with wrong integer tag should be rejected")
    func rejectWrongIntegerTag() throws {
        // Use 0x03 (BIT STRING) instead of 0x02 (INTEGER) for r
        var wrongIntTag = SecurityTestVectors.DEREncoding.validStrictDER
        wrongIntTag[2] = 0x03

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: wrongIntTag)
        }
    }

    // MARK: - Round-trip test

    @Test("DER encoding round-trip should preserve signature")
    func derRoundTrip() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let message = "test message for DER round-trip".data(using: .utf8)!

        // Create a signature
        let signature = try privateKey.signature(for: message)

        // Get DER representation
        let derBytes = try signature.derRepresentation

        // Parse it back
        let parsedSignature = try P256K.Signing.ECDSASignature(derRepresentation: derBytes)

        // Compact representations should match
        let originalCompact = try signature.compactRepresentation
        let parsedCompact = try parsedSignature.compactRepresentation

        #expect(originalCompact == parsedCompact, "DER round-trip should preserve signature")
    }
}
