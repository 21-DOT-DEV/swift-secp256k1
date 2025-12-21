//
//  NonceAggVectorTests.swift
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

/// BIP-0327 Nonce Aggregation test vectors
@Suite("BIP-0327 Nonce Aggregation")
struct NonceAggVectorTests {
    /// Loaded test vectors
    let vectors: NonceAggVectors

    init() throws {
        let loader = TestVectorLoader<NonceAggVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "nonce_agg_vectors")
    }

    @Test("Valid nonce aggregation matches expected output")
    func validNonceAggregation() throws {
        for testCase in vectors.valid_test_cases {
            // Parse public nonces from vector data
            let pubnonces = try testCase.pnonce_indices.map { index -> P256K.Schnorr.Nonce in
                let pnonceHex = vectors.pnonces[index]
                let pnonceBytes = try pnonceHex.bytes
                return try P256K.Schnorr.Nonce(dataRepresentation: pnonceBytes)
            }

            // Aggregate the nonces
            let aggregatedNonce = try P256K.MuSig.Nonce(aggregating: pubnonces)

            // Serialize and compare with expected
            let serialized = aggregatedNonce.dataRepresentation
            let expectedBytes = try testCase.expected.bytes

            #expect(
                [UInt8](serialized) == expectedBytes,
                "Aggregated nonce should match expected for indices \(testCase.pnonce_indices)"
            )
        }
    }

    @Test("Invalid nonces are rejected")
    func invalidNoncesRejected() throws {
        for errorCase in vectors.error_test_cases {
            // Try to parse invalid pnonces - should fail
            var parseSucceeded = true

            do {
                for index in errorCase.pnonce_indices {
                    let pnonceHex = vectors.pnonces[index]
                    let pnonceBytes = try pnonceHex.bytes
                    _ = try P256K.Schnorr.Nonce(dataRepresentation: pnonceBytes)
                }
            } catch {
                parseSucceeded = false
            }

            // If the error is about invalid contribution, parsing should fail
            if errorCase.error.type == "invalid_contribution" {
                #expect(!parseSucceeded, "Invalid nonce should be rejected: \(errorCase.comment ?? "")")
            }
        }
    }

    @Test("Nonce serialization round-trips correctly")
    func nonceSerializationRoundTrip() throws {
        // Test that we can parse, serialize, and re-parse a nonce
        let pnonceHex = vectors.pnonces[0]
        let pnonceBytes = try pnonceHex.bytes

        let nonce = try P256K.Schnorr.Nonce(dataRepresentation: pnonceBytes)
        let serialized = nonce.dataRepresentation
        let reparsed = try P256K.Schnorr.Nonce(dataRepresentation: serialized)
        let reserialized = reparsed.dataRepresentation

        #expect([UInt8](serialized) == pnonceBytes, "Nonce should round-trip correctly")
    }

    @Test("Aggregated nonce serialization round-trips correctly")
    func aggNonceSerializationRoundTrip() throws {
        // Use a valid test case to get an expected aggregated nonce
        guard let testCase = vectors.valid_test_cases.first else {
            return
        }

        let expectedBytes = try testCase.expected.bytes
        let aggNonce = try P256K.MuSig.Nonce(dataRepresentation: expectedBytes)
        let serialized = aggNonce.dataRepresentation
        let reparsed = try P256K.MuSig.Nonce(dataRepresentation: serialized)
        let reserialized = reparsed.dataRepresentation

        #expect(serialized == reserialized, "Aggregated nonce should round-trip correctly")
        #expect([UInt8](serialized) == expectedBytes, "Serialized should match original")
    }
}
