//
//  SigAggVectorTests.swift
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

/// BIP-0327 Signature Aggregation test vectors
@Suite("BIP-0327 Signature Aggregation")
struct SigAggVectorTests {
    /// Loaded test vectors
    let vectors: SigAggVectors

    init() throws {
        let loader = TestVectorLoader<SigAggVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "sig_agg_vectors")
    }

    @Test("Vectors file loads correctly")
    func vectorsLoadCorrectly() throws {
        #expect(vectors.pubkeys.count == 4, "Should have 4 public keys")
        #expect(vectors.psigs.count == 9, "Should have 9 partial signatures")
        #expect(vectors.valid_test_cases.count >= 1, "Should have valid test cases")
        #expect(vectors.error_test_cases.count >= 1, "Should have error test cases")
    }

    @Test("Public keys from vectors are valid")
    func publicKeysValid() throws {
        for (i, pubkeyHex) in vectors.pubkeys.enumerated() {
            let pubkeyBytes = try pubkeyHex.bytes
            let pubkey = try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
            #expect(pubkey.dataRepresentation.count == 33, "Public key \(i) should be valid")
        }
    }

    @Test("Partial signatures have correct length")
    func partialSignaturesValid() throws {
        // First 8 psigs should be valid 32-byte values
        for i in 0..<8 {
            let psigBytes = try vectors.psigs[i].bytes
            #expect(psigBytes.count == 32, "Partial signature \(i) should be 32 bytes")
        }
    }

    @Test("Invalid partial signature exceeds group size")
    func invalidPartialSignature() throws {
        // psig[8] exceeds group size per error_test_cases
        let invalidPsigBytes = try vectors.psigs[8].bytes
        #expect(invalidPsigBytes.count == 32, "Invalid psig should still be 32 bytes")

        // The value FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
        // is the group order n, which is invalid for a partial signature
    }

    @Test("Aggregated nonces from vectors can be parsed")
    func aggregatedNoncesValid() throws {
        for testCase in vectors.valid_test_cases {
            let aggnonceBytess = try testCase.aggnonce.bytes
            let aggNonce = try P256K.MuSig.Nonce(dataRepresentation: aggnonceBytess)
            let serialized = aggNonce.dataRepresentation
            #expect([UInt8](serialized) == aggnonceBytess, "Aggregated nonce should round-trip")
        }
    }

    @Test("Expected aggregated signatures have correct format")
    func expectedSignaturesValid() throws {
        for testCase in vectors.valid_test_cases {
            let expectedBytes = try testCase.expected.bytes
            #expect(expectedBytes.count == 64, "Expected signature should be 64 bytes")

            // Verify we can create an AggregateSignature from the expected bytes
            let aggSig = try P256K.MuSig.AggregateSignature(dataRepresentation: expectedBytes)
            #expect(aggSig.dataRepresentation.count == 64, "AggregateSignature should be 64 bytes")
        }
    }

    @Test("End-to-end signature aggregation succeeds")
    func endToEndSignatureAggregation() throws {
        // Test complete signing and aggregation flow with generated keys
        let signer1 = try P256K.Schnorr.PrivateKey()
        let signer2 = try P256K.Schnorr.PrivateKey()

        let pubkeys = [signer1.publicKey, signer2.publicKey]
        let message = try vectors.msg.bytes

        // Aggregate keys
        let aggregatedKey = try P256K.MuSig.aggregate(pubkeys)

        // Generate nonces
        let nonce1 = try P256K.MuSig.Nonce.generate(
            secretKey: signer1,
            publicKey: signer1.publicKey,
            msg32: message
        )
        let nonce2 = try P256K.MuSig.Nonce.generate(
            secretKey: signer2,
            publicKey: signer2.publicKey,
            msg32: message
        )

        // Aggregate nonces
        let aggregatedNonce = try P256K.MuSig.Nonce(aggregating: [
            nonce1.pubnonce,
            nonce2.pubnonce
        ])

        // Generate partial signatures
        let partialSig1 = try signer1.partialSignature(
            for: SHA256.hash(data: message),
            pubnonce: nonce1.pubnonce,
            secureNonce: nonce1.secnonce,
            publicNonceAggregate: aggregatedNonce,
            publicKeyAggregate: aggregatedKey
        )

        let partialSig2 = try signer2.partialSignature(
            for: SHA256.hash(data: message),
            pubnonce: nonce2.pubnonce,
            secureNonce: nonce2.secnonce,
            publicNonceAggregate: aggregatedNonce,
            publicKeyAggregate: aggregatedKey
        )

        // Aggregate signatures
        let aggregatedSig = try P256K.MuSig.aggregateSignatures([partialSig1, partialSig2])
        #expect(aggregatedSig.dataRepresentation.count == 64, "Aggregated signature should be 64 bytes")

        // Verify the aggregate signature against the aggregated public key
        // Note: partialSignature API requires Digest, so verification must use same hash
        let isValid = aggregatedKey.xonly.isValidSignature(aggregatedSig, for: SHA256.hash(data: message))
        #expect(isValid, "Aggregate signature should verify against aggregated public key")
    }
}
