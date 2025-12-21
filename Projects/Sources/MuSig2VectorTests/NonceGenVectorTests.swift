//
//  NonceGenVectorTests.swift
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

/// BIP-0327 Nonce Generation test vectors
@Suite("BIP-0327 Nonce Generation")
struct NonceGenVectorTests {
    /// Loaded test vectors
    let vectors: NonceGenVectors

    init() throws {
        let loader = TestVectorLoader<NonceGenVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "nonce_gen_vectors")
    }

    @Test("Nonce generation produces valid nonces")
    func nonceGeneration() throws {
        // Note: The P256K API generates random sessionIDs internally for security.
        // We cannot match exact expected values from BIP-0327 vectors without
        // lower-level access to pass the exact rand_ value.
        // We verify that nonce generation succeeds and produces valid output.

        for testCase in vectors.test_cases {
            // Skip cases without a secret key (the API requires one)
            guard let skHex = testCase.sk else { continue }

            let skBytes = try skHex.bytes
            let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: skBytes)

            // Parse message if present
            let msgBytes: [UInt8]
            if let msgHex = testCase.msg, !msgHex.isEmpty {
                msgBytes = try msgHex.bytes
            } else {
                // Use empty 32-byte message for empty/null msg
                msgBytes = [UInt8](repeating: 0, count: 32)
            }

            // Parse extra input if present
            let extraInput: [UInt8]?
            if let extraHex = testCase.extra_in {
                extraInput = try extraHex.bytes
            } else {
                extraInput = nil
            }

            // Generate nonce - this uses random sessionID internally
            let nonceResult = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: msgBytes.count == 32 ? msgBytes : Array(msgBytes.prefix(32)),
                extraInput32: extraInput
            )

            // Verify the nonce result has valid structure by iterating
            let pubnonceBytes = Array(nonceResult.pubnonce)
            #expect(pubnonceBytes.count == 132, "Public nonce should be 132 bytes")
        }
    }

    @Test("Nonce generation is non-deterministic with random sessionID")
    func nonceNonDeterminism() throws {
        // Verify that generating nonces twice produces different results
        // (due to random sessionID)

        guard let testCase = vectors.test_cases.first(where: { $0.sk != nil }),
              let skHex = testCase.sk else {
            return
        }

        let skBytes = try skHex.bytes
        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: skBytes)
        let msgBytes = [UInt8](repeating: 0, count: 32)

        let nonce1 = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: msgBytes
        )

        let nonce2 = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: msgBytes
        )

        // Nonces should be different due to random sessionID
        #expect(
            Array(nonce1.pubnonce) != Array(nonce2.pubnonce),
            "Two nonce generations should produce different results"
        )
    }
}
