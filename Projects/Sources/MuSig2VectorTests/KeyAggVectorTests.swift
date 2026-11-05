//
//  KeyAggVectorTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
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

    @Test("Valid key aggregation matches BIP-0327 expected aggregates")
    func validKeyAggregation() throws {
        for testCase in vectors.valid_test_cases {
            // Extract public keys for this test case
            let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
                let pubkeyBytes = try vectors.pubkeys[index].bytes
                return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
            }
            let expected = try testCase.expected.bytes

            // Aggregate keys
            let aggregatedKey = try P256K.MuSig.aggregate(pubkeys)

            // The aggregate's x-only form must equal the vector's expected key —
            // only an order-preserving BIP-327 KeyAgg reproduces these values.
            #expect(
                Array(aggregatedKey.xonly.dataRepresentation) == expected,
                "Aggregate x-only key must equal expected for indices \(testCase.key_indices)"
            )

            // Run aggregation again to verify determinism
            let aggregatedKey2 = try P256K.MuSig.aggregate(pubkeys)

            // Verify the two aggregations produce the same result
            #expect(
                aggregatedKey.xonly.dataRepresentation == aggregatedKey2.xonly.dataRepresentation,
                "Key aggregation should be deterministic for indices \(testCase.key_indices)"
            )
        }
    }

    @Test("Key aggregation preserves the caller's key order")
    func keyAggregationPreservesOrder() throws {
        // BIP-327 assigns coefficient 1 to the second *distinct* key, so
        // [0, 1, 2] and [2, 1, 0] are different aggregates — the two valid cases
        // carrying those index lists assert their distinct `expected` values in
        // `validKeyAggregation` above.
        let pubkeys = try [0, 1, 2].map { index -> P256K.Schnorr.PublicKey in
            let pubkeyBytes = try vectors.pubkeys[index].bytes
            return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
        }

        let forward = try P256K.MuSig.aggregate(pubkeys)
        let reversed = try P256K.MuSig.aggregate(Array(pubkeys.reversed()))

        #expect(
            forward.xonly.dataRepresentation != reversed.xonly.dataRepresentation,
            "Reversing the key order must produce a different aggregate"
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
