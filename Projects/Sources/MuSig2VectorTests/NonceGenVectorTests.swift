//
//  NonceGenVectorTests.swift
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

/// BIP-0327 Nonce Generation test vectors
@Suite("BIP-0327 Nonce Generation")
struct NonceGenVectorTests {
    /// Loaded test vectors
    let vectors: NonceGenVectors

    init() throws {
        let loader = TestVectorLoader<NonceGenVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "nonce_gen_vectors")
    }

    /// Verifies `expected_pubnonce` and `expected_secnonce` for every vector the Swift
    /// API can express, skipping the rest with a stated reason.
    ///
    /// Coverage of the four-vector suite:
    /// - One case is fully reproducible at the Swift layer (only `rand_` and `pk` set;
    ///   every optional input is `null`).
    /// - One case carries `aggpk`, which upstream folds into nonce derivation through
    ///   `keyagg_cache` — an input ``P256K/MuSig/Nonce`` does not expose. The vendored
    ///   C suite verifies that case against this same pinned tree.
    /// - Two cases carry messages of 0 and 38 bytes. BIP-327 defines the nonce-gen
    ///   message as variable length, but `secp256k1_musig_nonce_gen` accepts exactly
    ///   32 bytes, so no binding can express them — upstream's C vector suite
    ///   (`test_case[2]`) skips them for the same reason.
    @Test("Nonce generation matches BIP-0327 expected nonces")
    func nonceGeneration() throws {
        var verified = 0
        var skipped: [String] = []

        for (index, testCase) in vectors.test_cases.enumerated() {
            if let reason = skipReason(for: testCase, index: index) {
                skipped.append(reason)
                continue
            }
            try verifyExactMatch(testCase)
            verified += 1
        }

        #expect(verified == 1, "1 of 4 cases is fully expressible at the Swift layer")
        #expect(
            skipped.count == vectors.test_cases.count - 1,
            "Skipped cases with stated reasons: \(skipped.joined(separator: " — "))"
        )
    }

    /// Returns the stated skip reason for a case the Swift API cannot express, or `nil`.
    private func skipReason(for testCase: NonceGenTestCase, index: Int) -> String? {
        // Variable-length messages are not representable in the fixed
        // 32-byte `msg32` parameter of `secp256k1_musig_nonce_gen`. (The empty
        // string decodes to zero bytes — checked on the hex without decoding.)
        if let msg = testCase.msg, msg.count / 2 != 32 {
            return "case \(index + 1): \(msg.count / 2)-byte message not representable in msg32"
        }
        // `keyagg_cache` entropy is not exposed by `Nonce.generate`.
        if testCase.aggpk != nil {
            return "case \(index + 1): aggpk → keyagg_cache input not exposed at the Swift layer"
        }
        return nil
    }

    /// Feeds a vector's `rand_` through ``P256K/MuSig/SessionSecretRand`` and checks the
    /// generated nonces against `expected_pubnonce` and `expected_secnonce`.
    private func verifyExactMatch(_ testCase: NonceGenTestCase) throws {
        let msgBytes = try testCase.msg.map { try $0.bytes }
        let randBytes = try testCase.rand_.bytes
        let pkBytes = try testCase.pk.bytes
        let publicKey = try P256K.Schnorr.PublicKey(dataRepresentation: pkBytes, format: .compressed)
        let secretKey = try testCase.sk.map { try P256K.Schnorr.PrivateKey(dataRepresentation: $0.bytes) }
        let extraInput = try testCase.extra_in.map { try $0.bytes }

        let nonceResult = try P256K.MuSig.Nonce.generate(
            sessionSecretRand: P256K.MuSig.SessionSecretRand(bytes: randBytes),
            secretKey: secretKey,
            publicKey: publicKey,
            msg32: msgBytes,
            extraInput32: extraInput
        )

        let expectedPubnonce = try testCase.expected_pubnonce.bytes
        let expectedSecnonce = try testCase.expected_secnonce.bytes

        #expect(
            Array(nonceResult.pubnonce.dataRepresentation) == expectedPubnonce,
            "pubnonce must equal expected_pubnonce"
        )

        // The vector's 97-byte spec-form secret nonce maps onto the internal
        // 132-byte `secp256k1_musig_secnonce` exactly as upstream's own vector
        // test checks it: k1‖k2 at data[4..<68], the parsed public key at
        // data[68..<132], and the 33-byte serialized public key at
        // expected_secnonce[64..<97].
        let secnonceBytes = Array(nonceResult.secnonce.data)
        let parsedPublicKey = Swift.withUnsafeBytes(of: publicKey.baseKey.rawRepresentation) { Array($0) }

        #expect(
            Array(secnonceBytes[4..<68]) == Array(expectedSecnonce[0..<64]),
            "secnonce k1‖k2 must equal expected_secnonce[0..<64]"
        )
        #expect(
            Array(secnonceBytes[68..<132]) == parsedPublicKey,
            "secnonce pubkey element must equal the parsed pk"
        )
        #expect(
            Array(expectedSecnonce[64..<97]) == pkBytes,
            "expected_secnonce pubkey element must equal the vector pk"
        )
    }

    @Test("Nonce generation is non-deterministic with random session randomness")
    func nonceNonDeterminism() throws {
        // Verify that generating nonces twice produces different results
        // (due to internally generated random session randomness)

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

        // Nonces should be different due to random session randomness
        #expect(
            Array(nonce1.pubnonce) != Array(nonce2.pubnonce),
            "Two nonce generations should produce different results"
        )
    }
}
