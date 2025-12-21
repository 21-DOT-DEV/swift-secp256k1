//
//  ECDSAWycheproofTests.swift
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

/// Wycheproof ECDSA Bitcoin test vectors for secp256k1
@Suite("Wycheproof ECDSA Bitcoin")
struct ECDSAWycheproofTests {
    /// Loaded test file
    let testFile: WycheproofECDSABitcoin

    init() throws {
        let loader = TestVectorLoader<WycheproofECDSABitcoin>(bundle: Bundle.module)
        self.testFile = try loader.load(from: "ecdsa_secp256k1_sha256_bitcoin_test")
    }

    @Test("All ECDSA vectors pass")
    func allECDSAVectors() throws {
        #expect(!testFile.testGroups.isEmpty, "No ECDSA test groups loaded")

        var passed = 0
        var failed = 0
        var skipped = 0

        for group in testFile.testGroups {
            for vector in group.tests {
                if shouldSkip(vector: vector) {
                    skipped += 1
                    continue
                }

                let result = testVector(vector, publicKey: group.publicKey)
                let expected = vector.result == .valid

                if result == expected {
                    passed += 1
                } else {
                    failed += 1
                }

                #expect(
                    result == expected,
                    "Vector tcId=\(vector.tcId) failed: expected \(vector.result), got \(result ? "valid" : "invalid"), comment: \(vector.comment)"
                )
            }
        }

        print("ECDSA Bitcoin Results: \(passed) passed, \(failed) failed, \(skipped) skipped")
    }

    @Test("Valid ECDSA signatures verify")
    func validSignatures() throws {
        let validVectors = testFile.testGroups.flatMap { group in
            group.tests.filter { $0.result == .valid }.map { (group.publicKey, $0) }
        }
        #expect(!validVectors.isEmpty, "No valid ECDSA vectors found")

        for (pubKey, vector) in validVectors {
            if shouldSkip(vector: vector) { continue }

            let result = testVector(vector, publicKey: pubKey)
            #expect(result, "Valid vector tcId=\(vector.tcId) should pass: \(vector.comment)")
        }
    }

    @Test("Invalid ECDSA signatures are rejected")
    func invalidSignatures() throws {
        let invalidVectors = testFile.testGroups.flatMap { group in
            group.tests.filter { $0.result == .invalid }.map { (group.publicKey, $0) }
        }
        #expect(!invalidVectors.isEmpty, "No invalid ECDSA vectors found")

        for (pubKey, vector) in invalidVectors {
            if shouldSkip(vector: vector) { continue }

            let result = testVector(vector, publicKey: pubKey)
            #expect(!result, "Invalid vector tcId=\(vector.tcId) should fail: \(vector.comment)")
        }
    }

    @Test("Signature malleability is rejected (Bitcoin low-S rule)")
    func signatureMalleabilityRejection() throws {
        let malleableVectors = testFile.testGroups.flatMap { group in
            group.tests.filter { $0.flags.contains("SignatureMalleabilityBitcoin") }.map { (group.publicKey, $0) }
        }

        #expect(!malleableVectors.isEmpty, "No signature malleability vectors found")

        for (pubKey, vector) in malleableVectors {
            let result = testVector(vector, publicKey: pubKey)
            #expect(!result, "Malleable signature tcId=\(vector.tcId) should be rejected")
        }
    }

    // MARK: - Private Helpers

    private func shouldSkip(vector: ECDSABitcoinTestVector) -> Bool {
        let unsupportedFlags: Set<String> = ["InvalidTypesInSignature"]
        return !Set(vector.flags).isDisjoint(with: unsupportedFlags)
    }

    private func testVector(_ vector: ECDSABitcoinTestVector, publicKey: ECDSAPublicKey) -> Bool {
        do {
            let pubKeyBytes = try publicKey.uncompressed.bytes
            guard pubKeyBytes.count == 65 && pubKeyBytes[0] == 0x04 else {
                return false
            }

            let messageBytes: [UInt8] = vector.msg.isEmpty ? [] : try vector.msg.bytes
            let sigBytes = try vector.sig.bytes

            let signingPubKey = try P256K.Signing.PublicKey(
                dataRepresentation: pubKeyBytes,
                format: .uncompressed
            )

            let signature = try P256K.Signing.ECDSASignature(derRepresentation: sigBytes)
            let messageHash = SHA256.hash(data: messageBytes)

            return signingPubKey.isValidSignature(signature, for: messageHash)
        } catch {
            return false
        }
    }
}
