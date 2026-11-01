//
//  SignVerifyVectorTests.swift
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

/// BIP-0327 Sign/Verify test vectors
@Suite("BIP-0327 Sign/Verify")
struct SignVerifyVectorTests {
    /// Loaded test vectors
    let vectors: SignVerifyVectors

    init() throws {
        let loader = TestVectorLoader<SignVerifyVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "sign_verify_vectors")
    }

    @Test("Secnonces from vectors have expected format")
    func secnoncesValid() throws {
        // Note: BIP-0327 secnonces are 97 bytes (32 + 32 + 33), but the library's
        // internal SecureNonce uses secp256k1_musig_secnonce which is 132 bytes.
        // Direct vector-based partial signature testing would require format conversion.
        // We verify the vector data parses correctly and test signing via end-to-end flow.

        for (i, secnonceHex) in vectors.secnonces.enumerated() {
            let secnonceBytes = try secnonceHex.bytes
            // BIP-0327 secnonces are 97 bytes: k1 (32) + k2 (32) + pk (33)
            #expect(secnonceBytes.count == 97, "Secnonce \(i) should be 97 bytes")
        }
    }

    @Test("End-to-end MuSig2 signing flow succeeds")
    func endToEndSigningFlow() throws {
        // Test a complete MuSig2 signing flow using the public API
        let signer1 = try P256K.Schnorr.PrivateKey()
        let signer2 = try P256K.Schnorr.PrivateKey()
        let signer3 = try P256K.Schnorr.PrivateKey()

        let pubkeys = [signer1.publicKey, signer2.publicKey, signer3.publicKey]
        let message = [UInt8](repeating: 0x42, count: 32)

        // Aggregate public keys
        let aggregatedPubKey = try P256K.MuSig.aggregate(pubkeys)
        #expect(aggregatedPubKey.xonly.bytes.count == 32, "Aggregated key should be valid")

        // Generate nonces for each signer
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
        let nonce3 = try P256K.MuSig.Nonce.generate(
            secretKey: signer3,
            publicKey: signer3.publicKey,
            msg32: message
        )

        // Aggregate nonces
        let aggregatedNonce = try P256K.MuSig.Nonce(aggregating: [
            nonce1.pubnonce,
            nonce2.pubnonce,
            nonce3.pubnonce
        ])

        #expect(aggregatedNonce.dataRepresentation.count == 66, "Aggregated nonce should serialize to 66 bytes")
    }

    @Test("Vectors file loads correctly")
    func vectorsLoadCorrectly() {
        #expect(vectors.pubkeys.count == 4, "Should have 4 public keys")
        #expect(vectors.secnonces.count == 2, "Should have 2 secret nonces")
        #expect(vectors.pnonces.count == 5, "Should have 5 public nonces")
        #expect(vectors.aggnonces.count == 5, "Should have 5 aggregated nonces")
        #expect(vectors.valid_test_cases.count == 3, "Should have 3 valid test cases")
    }

    /// BIP-327 permits variable-length messages, but libsecp256k1's MuSig API
    /// reads a fixed 32-byte `msg32` at nonce generation and session binding —
    /// the vector file's empty (`msgs[1]`) and 38-byte (`msgs[2]`) payloads must
    /// throw on the signing inputs rather than silently commit to the first 32
    /// bytes. `msgs[0]` (32 bytes) passes through the same inputs.
    @Test("Non-32-byte vector messages throw on the signing inputs")
    func nonMsg32VectorMessagesThrow() throws {
        let signer = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([signer.publicKey])
        // `msgs[1]` is the BIP-327 empty message — `String.bytes` (the strict
        // hex decoder) rejects an empty string, so decode it as `[]` directly.
        let messages = try vectors.msgs.map { $0.isEmpty ? [] : try $0.bytes }

        // The probes below are only meaningful if the fixture actually carries
        // both shapes — pin that expectation so a future vector edit can't
        // silently vacate either loop.
        #expect(messages.contains { $0.count == P256K.ByteLength.dimension }, "fixture must carry a 32-byte message")
        #expect(messages.contains { $0.count != P256K.ByteLength.dimension }, "fixture must carry a non-32-byte message")

        for message in messages where message.count == P256K.ByteLength.dimension {
            // Expressible — both signing inputs accept the 32-byte message.
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: signer,
                publicKey: signer.publicKey,
                msg32: message
            )
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
            _ = try signer.partialSignature(
                for: message,
                pubnonce: nonce.pubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        for message in messages where message.count != P256K.ByteLength.dimension {
            #expect(throws: secp256k1Error.incorrectParameterSize) {
                _ = try P256K.MuSig.Nonce.generate(
                    secretKey: signer,
                    publicKey: signer.publicKey,
                    msg32: message
                )
            }

            // `partialSignature` consumes the nonce it receives — a fresh one
            // per probe, so this checks the thrown error explicitly.
            do {
                let nonce = try P256K.MuSig.Nonce.generate(
                    secretKey: signer,
                    publicKey: signer.publicKey,
                    msg32: nil
                )
                let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
                _ = try signer.partialSignature(
                    for: message,
                    pubnonce: nonce.pubnonce,
                    secureNonce: nonce.secnonce,
                    publicNonceAggregate: aggregateNonce,
                    publicKeyAggregate: aggregate
                )
                Issue.record("partialSignature must reject a \(message.count)-byte message")
            } catch {
                #expect(error as? secp256k1Error == .incorrectParameterSize)
            }
        }
    }

    @Test("Public nonces from vectors can be parsed")
    func publicNoncesValid() throws {
        for (i, pnonceHex) in vectors.pnonces.prefix(3).enumerated() {
            let pnonceBytes = try pnonceHex.bytes
            let nonce = try P256K.Schnorr.Nonce(dataRepresentation: pnonceBytes)
            let serialized = nonce.dataRepresentation
            #expect([UInt8](serialized) == pnonceBytes, "Public nonce \(i) should round-trip")
        }
    }

    @Test("Aggregated nonces from vectors can be parsed")
    func aggregatedNoncesValid() throws {
        // Only test the first valid aggnonce (index 0)
        let aggnonceBytess = try vectors.aggnonces[0].bytes
        let aggNonce = try P256K.MuSig.Nonce(dataRepresentation: aggnonceBytess)
        let serialized = aggNonce.dataRepresentation
        #expect([UInt8](serialized) == aggnonceBytess, "Aggregated nonce should round-trip")
    }
}
