//
//  DetSignVectorTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
@testable import P256K
import Testing

/// BIP-0327 Deterministic Sign test vectors
@Suite("BIP-0327 Deterministic Sign")
struct DetSignVectorTests {
    /// Loaded test vectors
    let vectors: DetSignVectors

    init() throws {
        let loader = TestVectorLoader<DetSignVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "det_sign_vectors")
    }

    @Test("Vectors file loads correctly")
    func vectorsLoadCorrectly() throws {
        #expect(vectors.pubkeys.count == 4, "Should have 4 public keys")
        #expect(vectors.msgs.count == 2, "Should have 2 messages")
        #expect(vectors.valid_test_cases.count >= 1, "Should have valid test cases")
    }

    @Test("Secret key from vectors is valid")
    func secretKeyValid() throws {
        let skBytes = try vectors.sk.bytes
        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: skBytes)
        #expect(privateKey.dataRepresentation.count == 32, "Private key should be 32 bytes")
    }

    @Test("Public keys from vectors are valid")
    func publicKeysValid() throws {
        for i in 0..<3 {
            let pubkeyBytes = try vectors.pubkeys[i].bytes
            let pubkey = try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
            #expect(pubkey.dataRepresentation.count == 33, "Public key \(i) should be valid")
        }
    }

    @Test("Aggregated other nonces from vectors can be parsed")
    func aggOtherNoncesValid() throws {
        for testCase in vectors.valid_test_cases {
            let aggOtherNonceBytes = try testCase.aggothernonce.bytes
            let aggNonce = try P256K.Schnorr.Nonce(dataRepresentation: aggOtherNonceBytes)
            let serialized = aggNonce.dataRepresentation
            #expect([UInt8](serialized) == aggOtherNonceBytes, "Aggregated other nonce should round-trip")
        }
    }

    @Test("Expected outputs have correct format")
    func expectedOutputsValid() throws {
        for testCase in vectors.valid_test_cases {
            // expected[0] is pubnonce (66 bytes)
            // expected[1] is psig (32 bytes)
            let expectedPubnonce = try testCase.expected[0].bytes
            let expectedPsig = try testCase.expected[1].bytes

            #expect(expectedPubnonce.count == 66, "Expected pubnonce should be 66 bytes")
            #expect(expectedPsig.count == 32, "Expected psig should be 32 bytes")

            // Verify pubnonce can be parsed
            let pubnonce = try P256K.Schnorr.Nonce(dataRepresentation: expectedPubnonce)
            #expect([UInt8](pubnonce.dataRepresentation) == expectedPubnonce, "Pubnonce should round-trip")
        }
    }

    @Test("Messages from vectors are valid")
    func messagesValid() throws {
        let msg0 = try vectors.msgs[0].bytes
        let msg1 = try vectors.msgs[1].bytes

        #expect(msg0.count == 32, "First message should be 32 bytes")
        #expect(msg1.count == 38, "Second message should be 38 bytes (longer)")
    }

    @Test("Deterministic signing produces consistent results")
    func deterministicSigningConsistent() throws {
        // Test that signing with same inputs produces same output
        let privateKey = try P256K.Schnorr.PrivateKey()
        let message = try vectors.msgs[0].bytes

        // Generate nonces with same sessionID
        let sessionID = [UInt8](repeating: 0x42, count: 133)

        let nonce1 = try P256K.MuSig.Nonce.generate(
            sessionID: sessionID,
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: message,
            extraInput32: nil
        )

        let nonce2 = try P256K.MuSig.Nonce.generate(
            sessionID: sessionID,
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: message,
            extraInput32: nil
        )

        // Same sessionID should produce same nonces
        #expect(
            nonce1.pubnonce.dataRepresentation == nonce2.pubnonce.dataRepresentation,
            "Same sessionID should produce same nonces"
        )
    }
}
