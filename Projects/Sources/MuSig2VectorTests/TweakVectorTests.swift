//
//  TweakVectorTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
@testable import P256K
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

    /// Drives every valid case's `expected` partial signature through the real
    /// pipeline: ordered aggregation → the case's tweak chain → `partialSignature`
    /// with the vector's materialized secret nonce. BIP-327 partial signatures
    /// commit to the key order and every applied tweak, so these are end-to-end
    /// checks on ordering *and* the tweak chain — reachable now that
    /// `aggregate(_:)` preserves the caller's key order.
    @Test("Tweak chains produce the expected partial signatures")
    func tweakChainingProducesExpectedSignatures() throws {
        let specSecnonce = try vectors.secnonce.bytes
        let secretKey = try P256K.Schnorr.PrivateKey(dataRepresentation: vectors.sk.bytes)
        let digest = try SHA256Digest(vectors.msg.bytes)
        let aggregateNonce = try P256K.MuSig.Nonce(dataRepresentation: vectors.aggnonce.bytes)

        for testCase in vectors.valid_test_cases {
            // Aggregate the case's public keys in the listed order, then apply
            // every tweak in sequence — the same pipeline `invalidTweaks` uses.
            let pubkeys = try testCase.key_indices.map { index -> P256K.Schnorr.PublicKey in
                let pubkeyBytes = try vectors.pubkeys[index].bytes
                return try P256K.Schnorr.PublicKey(dataRepresentation: pubkeyBytes, format: .compressed)
            }

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

            // `signer_index` selects the signer's position in the case's key and
            // nonce lists; the vector's `sk` is that signer's secret key.
            let signerPublicKey = pubkeys[testCase.signer_index]
            let pubnonce = try P256K.Schnorr.Nonce(
                dataRepresentation: vectors.pnonces[testCase.nonce_indices[testCase.signer_index]].bytes
            )

            // Fixture consistency: the spec secnonce embeds the signer's
            // serialized public key at bytes [64..<97].
            #expect(
                Array(specSecnonce[64..<97]) == Array(signerPublicKey.dataRepresentation),
                "Vector secnonce must be bound to the signer's public key"
            )

            // The vector's 97-byte spec-form secret nonce maps onto the
            // 132-byte `secp256k1_musig_secnonce` as upstream's own vector test
            // lays it out — the same mapping `NonceGenVectorTests` verifies in
            // reverse: magic prefix at data[0..<4] (`secnonce_load` checks it
            // inside `ARG_CHECK`), k1‖k2 at data[4..<68], and the 64-byte parsed
            // public key at data[68..<132].
            let parsedPublicKey = Swift.withUnsafeBytes(of: signerPublicKey.baseKey.rawRepresentation) { Array($0) }
            var secnonceBytes = [UInt8](repeating: 0, count: 132)
            secnonceBytes[0..<4] = [0x22, 0x0E, 0xDC, 0xF1]
            secnonceBytes[4..<68] = specSecnonce[0..<64]
            secnonceBytes[68..<132] = parsedPublicKey[...]

            let partialSignature = try secretKey.partialSignature(
                for: digest,
                pubnonce: pubnonce,
                secureNonce: P256K.Schnorr.SecureNonce(SecureBytes(bytes: secnonceBytes), publicKey: signerPublicKey),
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: currentKey
            )

            #expect(
                try Array(partialSignature.dataRepresentation) == (testCase.expected.bytes),
                "Partial signature must equal expected: \(testCase.comment ?? "")"
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
