//
//  SilentPaymentsAPIShapeTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(ZKP)
    @testable import ZKP
#else
    @testable import P256K
#endif

import Foundation
import Testing

/// Regression tests for the API surface used by the
/// [`SilentPayments` DocC article](https://docs.21.dev/documentation/p256k/silentpayments).
///
/// Validates that the BIP-352 sender + receiver flows shown in the article
/// compile against the published P256K API and that the math closes
/// (Bob's reconstruction of `P_0` matches Alice's-derived destination key).
/// This is an API-shape test, not a BIP-352 conformance test — it does not
/// validate against the BIP's official test vectors.
struct SilentPaymentsAPIShapeSuite {
    @Test("BIP-352 single-input sender/receiver round-trip closes")
    func bip352SingleInputRoundTrip() throws {
        // ───── Setup ─────
        // Alice (sender) holds a single input.
        let aliceSigningKey = try P256K.Signing.PrivateKey()

        // Bob (receiver) splits scan and spend keys; the spend key is what
        // the receiver tweaks to produce P_k. Both keys live in this test;
        // a real wallet keeps b_spend in cold storage.
        let bobScanKey = try P256K.KeyAgreement.PrivateKey()
        let bobSpendPrivateKey = try P256K.Signing.PrivateKey()
        let bobSpendBytes = bobSpendPrivateKey.publicKey.dataRepresentation

        // Both views of B_spend (article shows that we materialize both views
        // when B is also being used as an ECDH peer; here only signing-side
        // is needed since b_scan handles ECDH on the receiver side).
        let bobSpendKey = try P256K.Signing.PublicKey(
            dataRepresentation: bobSpendBytes,
            format: .compressed
        )

        // For the sender flow, Alice ECDHs against B_scan (Bob's published scan key).
        // Materialize both views of the same compressed point.
        let bobScanPubBytes = bobScanKey.publicKey.dataRepresentation
        let bobScanECDHKey = try P256K.KeyAgreement.PublicKey(
            dataRepresentation: bobScanPubBytes,
            format: .compressed
        )

        // Synthetic 36-byte outpoint (txid is 32 bytes, vout is 4 bytes; little-endian per BIP-352).
        let smallestOutpoint = Data(repeating: 0xAB, count: 36)

        // ───── Sender (Alice) ─────

        // Step 1: input_hash = hash_BIP0352/Inputs(outpoint_L || A)
        let inputHashInput = smallestOutpoint + aliceSigningKey.publicKey.dataRepresentation
        let inputHash = try SHA256.taggedHash(
            tag: #require("BIP0352/Inputs".data(using: .utf8)),
            data: inputHashInput
        )

        // Step 2: ECDH between (input_hash * a) and B_scan.
        let aliceTweakedPrivateKey = try aliceSigningKey.multiply(Array(inputHash))
        let aliceTweakedECDHKey = try P256K.KeyAgreement.PrivateKey(
            dataRepresentation: aliceTweakedPrivateKey.dataRepresentation
        )
        let aliceSharedPoint = aliceTweakedECDHKey.sharedSecretFromKeyAgreement(with: bobScanECDHKey)

        // Step 3: shared_secret_k = hash_BIP0352/SharedSecret(sharedPoint || ser_32(k))
        let k: UInt32 = 0
        let kBytes = withUnsafeBytes(of: k.bigEndian) { Data($0) }
        let aliceSharedSecret = try SHA256.taggedHash(
            tag: #require("BIP0352/SharedSecret".data(using: .utf8)),
            data: Data(aliceSharedPoint.bytes) + kBytes
        )

        // Step 4: P_0 = B_spend + sharedSecret·G — derive the BIP-341 x-only output key.
        let destination = try bobSpendKey.add(Array(aliceSharedSecret))
        let destinationXonly = destination.xonly.bytes

        #expect(destinationXonly.count == 32, "BIP-341 taproot x-only output key is 32 bytes")

        // ───── Receiver (Bob) ─────

        // Bob extracts A from the transaction. Round-trip via dataRepresentation
        // to produce the KeyAgreement.PublicKey form used for ECDH.
        let summedInputPubKey = try P256K.KeyAgreement.PublicKey(
            dataRepresentation: aliceSigningKey.publicKey.dataRepresentation,
            format: .compressed
        )

        // Step 1: reproduce input_hash with the summed input pubkey (A).
        let bobInputHashInput = smallestOutpoint + summedInputPubKey.dataRepresentation
        let bobInputHash = try SHA256.taggedHash(
            tag: #require("BIP0352/Inputs".data(using: .utf8)),
            data: bobInputHashInput
        )

        #expect(
            Data(Array(bobInputHash)) == Data(Array(inputHash)),
            "Sender and receiver compute identical input_hash"
        )

        // Step 2: ECDH on Bob's side: input_hash·b_scan·A
        // Note: KeyAgreement.PrivateKey exposes raw bytes via `rawRepresentation`,
        // not `dataRepresentation` (the only such asymmetry in the public API).
        let tweakedScanKey = try P256K.Signing.PrivateKey(
            dataRepresentation: bobScanKey.rawRepresentation
        ).multiply(Array(bobInputHash))
        let tweakedScanECDH = try P256K.KeyAgreement.PrivateKey(
            dataRepresentation: tweakedScanKey.dataRepresentation
        )
        let bobSharedPoint = tweakedScanECDH.sharedSecretFromKeyAgreement(with: summedInputPubKey)

        #expect(
            Data(aliceSharedPoint.bytes) == Data(bobSharedPoint.bytes),
            "ECDH produces identical shared point on both sides — the BIP-352 core invariant"
        )

        // Step 3: derive shared_secret_0 on Bob's side.
        let bobSharedSecret = try SHA256.taggedHash(
            tag: #require("BIP0352/SharedSecret".data(using: .utf8)),
            data: Data(bobSharedPoint.bytes) + kBytes
        )

        // Step 4: candidate_0 = B_spend + bobSharedSecret·G
        let candidate = try bobSpendKey.add(Array(bobSharedSecret))
        let candidateXonly = candidate.xonly.bytes

        #expect(
            candidateXonly == destinationXonly,
            "Receiver reconstructs the same destination output as the sender derived"
        )
    }
}
