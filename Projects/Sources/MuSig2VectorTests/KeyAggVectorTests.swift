//
//  KeyAggVectorTests.swift
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

/// BIP-0327 Key Aggregation test vectors
@Suite("BIP-0327 Key Aggregation")
struct KeyAggVectorTests {
    /// Loaded test vectors
    let vectors: KeyAggVectors

    init() throws {
        let loader = TestVectorLoader<KeyAggVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "key_agg_vectors")
    }

    @Test("Valid key aggregation succeeds and is deterministic")
    func validKeyAggregation() throws {
        for testCase in vectors.valid_test_cases {
            // Extract public keys for this test case
            let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
                let pubkeyBytes = try vectors.pubkeys[index].bytes
                return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
            }

            // Aggregate keys
            let aggregatedKey = try P256K.MuSig.aggregate(pubkeys)

            // Run aggregation again to verify determinism
            let aggregatedKey2 = try P256K.MuSig.aggregate(pubkeys)

            // Verify the two aggregations produce the same result
            #expect(
                aggregatedKey.xonly.bytes == aggregatedKey2.xonly.bytes,
                "Key aggregation should be deterministic for indices \(testCase.key_indices)"
            )

            // Verify the aggregated key is 32 bytes (x-only)
            #expect(
                aggregatedKey.xonly.bytes.count == 32,
                "Aggregated key should be 32-byte x-only"
            )
        }
    }

    @Test("Key aggregation produces consistent results regardless of input order")
    func keyAggregationOrderIndependent() throws {
        // Keys [0, 1, 2] and [2, 1, 0] should produce same result (library sorts internally)
        let indices1 = [0, 1, 2]
        let indices2 = [2, 1, 0]

        let pubkeys1 = try indices1.map { index -> P256K.Schnorr.PublicKey in
            let pubkeyBytes = try vectors.pubkeys[index].bytes
            return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
        }
        let pubkeys2 = try indices2.map { index -> P256K.Schnorr.PublicKey in
            let pubkeyBytes = try vectors.pubkeys[index].bytes
            return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
        }

        let agg1 = try P256K.MuSig.aggregate(pubkeys1)
        let agg2 = try P256K.MuSig.aggregate(pubkeys2)

        #expect(
            agg1.xonly.bytes == agg2.xonly.bytes,
            "Key aggregation should be order-independent"
        )
    }

    @Test("Invalid pubkeys are rejected")
    func invalidPubkeysRejected() throws {
        for testCase in vectors.error_test_cases {
            // Only test pubkey errors, not tweak errors
            guard testCase.error.contrib == "pubkey" else { continue }

            #expect(throws: (any Error).self, "Should reject invalid pubkeys") {
                let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
                    let pubkeyBytes = try vectors.pubkeys[index].bytes
                    return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
                }
                _ = try P256K.MuSig.aggregate(pubkeys)
            }
        }
    }
}
