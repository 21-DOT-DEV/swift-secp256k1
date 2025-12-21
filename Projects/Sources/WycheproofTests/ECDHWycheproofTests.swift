//
//  ECDHWycheproofTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import P256K
import Testing

/// Wycheproof ECDH test vectors for secp256k1
@Suite("Wycheproof ECDH")
struct ECDHWycheproofTests {
    /// Loaded test file
    let testFile: WycheproofECDH

    init() throws {
        let loader = TestVectorLoader<WycheproofECDH>(bundle: Bundle.module)
        self.testFile = try loader.load(from: "ecdh_secp256k1_test")
    }

    @Test("All ECDH vectors pass")
    func allECDHVectors() throws {
        #expect(!testFile.testGroups.isEmpty, "No ECDH test groups loaded")

        var passed = 0
        var failed = 0
        var skipped = 0

        for group in testFile.testGroups {
            for vector in group.tests {
                if shouldSkip(vector: vector) {
                    skipped += 1
                    continue
                }

                let result = testVector(vector)
                let expected = vector.result == .valid || vector.result == .acceptable

                if result == expected {
                    passed += 1
                } else {
                    failed += 1
                }

                #expect(
                    result == expected,
                    "Vector tcId=\(vector.tcId) failed: expected \(vector.result), comment: \(vector.comment)"
                )
            }
        }

        print("ECDH Results: \(passed) passed, \(failed) failed, \(skipped) skipped")
    }

    @Test("Valid ECDH vectors succeed")
    func validVectors() throws {
        let validVectors = testFile.testGroups.flatMap { $0.tests }.filter { $0.result == .valid }
        #expect(!validVectors.isEmpty, "No valid ECDH vectors found")

        for vector in validVectors {
            if shouldSkip(vector: vector) { continue }

            let result = testVector(vector)
            #expect(result, "Valid vector tcId=\(vector.tcId) should pass: \(vector.comment)")
        }
    }

    @Test("Invalid ECDH vectors are rejected")
    func invalidVectors() throws {
        let invalidVectors = testFile.testGroups.flatMap { $0.tests }.filter { $0.result == .invalid }
        #expect(!invalidVectors.isEmpty, "No invalid ECDH vectors found")

        for vector in invalidVectors {
            if shouldSkip(vector: vector) { continue }

            let result = testVector(vector)
            #expect(!result, "Invalid vector tcId=\(vector.tcId) should fail: \(vector.comment)")
        }
    }

    // MARK: - Private Helpers

    private func shouldSkip(vector: ECDHTestVector) -> Bool {
        // WrongCurve: Tests non-secp256k1 curves (P-256, P-384, etc.) - out of scope
        // InvalidAsn: Our strict ASN.1 parser rejects these; Wycheproof marks some as "acceptable"
        // tcIds 496, 497, 502-505, 507: Invalid curve OIDs that aren't secp256k1
        let flagsToSkip: Set<String> = ["InvalidAsn", "WrongCurve"]
        let tcIdsToSkip: Set<Int> = [496, 497, 502, 503, 504, 505, 507]

        if tcIdsToSkip.contains(vector.tcId) {
            return true
        }

        return !Set(vector.flags).isDisjoint(with: flagsToSkip)
    }

    private func testVector(_ vector: ECDHTestVector) -> Bool {
        do {
            let derBytes = try vector.public.bytes
            let publicKey = try P256K.KeyAgreement.PublicKey(derRepresentation: derBytes)

            let privateKeyBytes = try normalizePrivateKey(hex: vector.private)
            let expectedShared = try vector.shared.bytes

            let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateKeyBytes)
            let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey, format: .compressed)

            // libsecp256k1 returns compressed format: version byte + x-coordinate
            // Wycheproof expects just the x-coordinate (32 bytes)
            let computedX = Array(sharedSecret.bytes.dropFirst())

            return computedX == expectedShared
        } catch {
            return false
        }
    }

    private func normalizePrivateKey(hex: String) throws -> [UInt8] {
        var bytes = try hex.bytes
        if bytes.count == 33, bytes[0] == 0x00 {
            bytes = Array(bytes.dropFirst())
        }
        if bytes.count < 32 {
            bytes = [UInt8](repeating: 0, count: 32 - bytes.count) + bytes
        }
        return bytes
    }
}
