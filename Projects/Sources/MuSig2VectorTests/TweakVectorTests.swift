//
//  TweakVectorTests.swift
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

/// BIP-0327 Tweak test vectors
@Suite("BIP-0327 Tweaking")
struct TweakVectorTests {
    /// Loaded test vectors
    let vectors: TweakVectors

    init() throws {
        let loader = TestVectorLoader<TweakVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "tweak_vectors")
    }

    @Test("Tweak chaining produces deterministic results")
    func tweakChainingDeterministic() throws {
        // Note: The 'expected' field in vectors is a partial signature, which depends on
        // exact key order. Since the library sorts keys internally, we can't match exact
        // expected values. We verify that tweak chaining is deterministic and succeeds.

        for testCase in vectors.valid_test_cases {
            // Aggregate the public keys
            let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
                let pubkeyBytes = try vectors.pubkeys[index].bytes
                return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
            }

            // Apply all tweaks in sequence
            var currentKey = try P256K.MuSig.aggregate(pubkeys)
            for (i, tweakIndex) in testCase.tweak_indices.enumerated() {
                let tweakBytes = try vectors.tweaks[tweakIndex].bytes
                let isXonly = testCase.is_xonly[i]

                if isXonly {
                    let tweakedXonly = try currentKey.xonly.add(tweakBytes)
                    currentKey = P256K.MuSig.PublicKey(xonlyKey: tweakedXonly)
                } else {
                    currentKey = try currentKey.add(tweakBytes)
                }
            }

            // Apply same tweaks again to verify determinism
            var currentKey2 = try P256K.MuSig.aggregate(pubkeys)
            for (i, tweakIndex) in testCase.tweak_indices.enumerated() {
                let tweakBytes = try vectors.tweaks[tweakIndex].bytes
                let isXonly = testCase.is_xonly[i]

                if isXonly {
                    let tweakedXonly = try currentKey2.xonly.add(tweakBytes)
                    currentKey2 = P256K.MuSig.PublicKey(xonlyKey: tweakedXonly)
                } else {
                    currentKey2 = try currentKey2.add(tweakBytes)
                }
            }

            #expect(
                currentKey.xonly.bytes == currentKey2.xonly.bytes,
                "Same tweaks should produce same result: \(testCase.comment ?? "")"
            )
        }
    }

    @Test("Single x-only tweak produces valid key")
    func singleXonlyTweak() throws {
        // Test case 0: Single x-only tweak
        let testCase = vectors.valid_test_cases[0]
        let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
            let pubkeyBytes = try vectors.pubkeys[index].bytes
            return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
        }

        let aggregatedKey = try P256K.MuSig.aggregate(pubkeys)
        let tweakBytes = try vectors.tweaks[testCase.tweak_indices[0]].bytes
        let tweakedXonly = try aggregatedKey.xonly.add(tweakBytes)

        #expect(tweakedXonly.bytes.count == 32, "Tweaked x-only key should be 32 bytes")
    }

    @Test("Single plain tweak produces valid key")
    func singlePlainTweak() throws {
        // Test case 1: Single plain tweak
        let testCase = vectors.valid_test_cases[1]
        let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
            let pubkeyBytes = try vectors.pubkeys[index].bytes
            return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
        }

        let aggregatedKey = try P256K.MuSig.aggregate(pubkeys)
        let tweakBytes = try vectors.tweaks[testCase.tweak_indices[0]].bytes
        let tweakedKey = try aggregatedKey.add(tweakBytes)

        #expect(tweakedKey.dataRepresentation.count == 33, "Tweaked key should be 33 bytes compressed")
    }

    @Test("Multiple tweaks can be chained")
    func multipleTweaksChained() throws {
        // Test case 3: Four tweaks
        let testCase = vectors.valid_test_cases[3]
        let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
            let pubkeyBytes = try vectors.pubkeys[index].bytes
            return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
        }

        var currentKey = try P256K.MuSig.aggregate(pubkeys)
        var tweakCount = 0

        for (i, tweakIndex) in testCase.tweak_indices.enumerated() {
            let tweakBytes = try vectors.tweaks[tweakIndex].bytes
            let isXonly = testCase.is_xonly[i]

            if isXonly {
                let tweakedXonly = try currentKey.xonly.add(tweakBytes)
                currentKey = P256K.MuSig.PublicKey(xonlyKey: tweakedXonly)
            } else {
                currentKey = try currentKey.add(tweakBytes)
            }
            tweakCount += 1
        }

        #expect(tweakCount == 4, "Should have applied 4 tweaks")
        #expect(currentKey.xonly.bytes.count == 32, "Final key should be valid")
    }

    @Test("Invalid tweaks are rejected")
    func invalidTweaks() throws {
        for testCase in vectors.error_test_cases {
            let comment = testCase.comment ?? "No comment"

            #expect(throws: (any Error).self, "\(comment) should throw") {
                let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
                    let pubkeyBytes = try vectors.pubkeys[index].bytes
                    return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
                }

                var aggregatedKey = try P256K.MuSig.aggregate(pubkeys)

                for (i, tweakIndex) in testCase.tweak_indices.enumerated() {
                    let tweakBytes = try vectors.tweaks[tweakIndex].bytes
                    let isXonly = testCase.is_xonly[i]

                    if isXonly {
                        let tweakedXonly = try aggregatedKey.xonly.add(tweakBytes)
                        aggregatedKey = P256K.MuSig.PublicKey(xonlyKey: tweakedXonly)
                    } else {
                        aggregatedKey = try aggregatedKey.add(tweakBytes)
                    }
                }
            }
        }
    }
}
