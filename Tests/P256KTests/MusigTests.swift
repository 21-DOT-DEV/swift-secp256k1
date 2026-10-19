//
//  MusigTests.swift
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

struct MuSigTestSuite {
    @Test("MuSig Signing and Verification")
    func musig() throws {
        // Test MuSig aggregate
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try P256K.MuSig.aggregate(publicKeys)

        // Create a message to sign
        let message = "Hello, MuSig!".data(using: .utf8)!
        let messageHash = SHA256.hash(data: message)

        // Generate nonces for each signer
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: Array(messageHash)
        )

        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: Array(messageHash)
        )

        let thirdNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[2],
            publicKey: privateKeys[2].publicKey,
            msg32: Array(messageHash)
        )

        // Extract public nonces
        let publicNonces = [firstNonce.pubnonce, secondNonce.pubnonce, thirdNonce.pubnonce]

        // Aggregate public nonces
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: publicNonces)

        // Create partial signatures
        let firstPartialSignature = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            xonlyKeyAggregate: aggregate.xonly
        )

        let secondPartialSignature = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let thirdPartialSignature = try privateKeys[2].partialSignature(
            for: messageHash,
            pubnonce: thirdNonce.pubnonce,
            secureNonce: thirdNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // Uncomment to see expected error
//        let forthPartialSignature = try privateKeys[1].partialSignature(
//            for: messageHash,
//            pubnonce: thirdNonce.pubnonce,
//            secureNonce: thirdNonce.secnonce,
//            publicNonceAggregate: aggregateNonce,
//            publicKeyAggregate: aggregate
//        )

        // Aggregate partial signatures
        _ = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature, thirdPartialSignature])

        // Verify the signature
        #expect(try aggregate.isValidSignature(firstPartialSignature, publicKey: #require(publicKeys.first), nonce: #require(publicNonces.first), for: messageHash), "MuSig signature verification failed.")
    }

    @Test("MuSig nonce generated without a secret key still signs")
    func musigNonceWithoutSecretKey() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try P256K.MuSig.aggregate(publicKeys)

        let message = "Hello, keyless MuSig nonce!".data(using: .utf8)!
        let messageHash = SHA256.hash(data: message)

        // secp256k1_musig_nonce_gen accepts a NULL secret key — passing nil
        // must reach the C layer as NULL, not crash.
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: nil,
            publicKey: privateKeys[0].publicKey,
            msg32: Array(messageHash)
        )

        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: Array(messageHash)
        )

        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

        let firstPartialSignature = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let secondPartialSignature = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let signature = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature])

        #expect(try aggregate.xonly.isValidSignature(signature, for: messageHash), "MuSig signature from a nil-secret-key nonce failed to verify.")
    }

    @Test("MuSig nonce generation rejects malformed input sizes")
    func musigNonceGenerationRejectsBadSizes() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()

        // A present-but-short msg32 must throw, not reach C as a truncated 32-byte read.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: [UInt8](repeating: 0x00, count: 16)
            )
        }

        // A present-but-short extraInput32 must throw, not reach C as a truncated 32-byte read.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: nil,
                extraInput32: [UInt8](repeating: 0xAA, count: 16)
            )
        }

        // SessionSecretRand enforces the exact 32-byte session_secrand32 contract at construction.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.SessionSecretRand(bytes: [UInt8](repeating: 0x01, count: 16))
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.SessionSecretRand(bytes: [UInt8](repeating: 0x01, count: 33))
        }
    }

    @Test("MuSig nonce generated without a message still signs")
    func musigNonceWithoutMessage() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try P256K.MuSig.aggregate(publicKeys)

        let message = "Hello, messageless MuSig nonce!".data(using: .utf8)!
        let messageHash = SHA256.hash(data: message)

        // secp256k1_musig_nonce_gen accepts NULL msg32 — the message binds
        // later at secp256k1_musig_nonce_process inside partialSignature.
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: nil
        )

        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: nil
        )

        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

        let firstPartialSignature = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let secondPartialSignature = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let signature = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature])

        #expect(
            try aggregate.xonly.isValidSignature(signature, for: messageHash),
            "MuSig signature from message-free nonces failed to verify."
        )
    }

    @Test("Caller-supplied session randomness produces a deterministic public nonce")
    func musigDeterministicPubnonce() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let sessionRandBytes = [UInt8](repeating: 0x42, count: P256K.MuSig.SessionSecretRand.byteCount)
        let messageHash = SHA256.hash(data: Data())

        let first = try P256K.MuSig.Nonce.generate(
            sessionSecretRand: P256K.MuSig.SessionSecretRand(bytes: sessionRandBytes),
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: Array(messageHash),
            extraInput32: nil
        )

        let second = try P256K.MuSig.Nonce.generate(
            sessionSecretRand: P256K.MuSig.SessionSecretRand(bytes: sessionRandBytes),
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: Array(messageHash),
            extraInput32: nil
        )

        #expect(first.pubnonce.dataRepresentation == second.pubnonce.dataRepresentation)
    }

    @Test("MuSig tweaks reject non-32-byte tweaks")
    func musigTweaksRejectBadSizes() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let shortTweak = [UInt8](repeating: 0x01, count: 16)

        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try aggregate.add(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try aggregate.xonly.add(shortTweak)
        }
    }

    @Test("MuSig partial signing rejects non-32-byte digests")
    func musigPartialSignatureRejectsShortDigest() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))

        // secp256k1_musig_nonce_process reads exactly 32 bytes of msg32 — a
        // shorter Digest must throw before reaching C. The ~Copyable NonceResult
        // is created inside the closure so nothing noncopyable is captured.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: privateKeys[0],
                publicKey: privateKeys[0].publicKey,
                msg32: nil
            )
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
            _ = try privateKeys[0].partialSignature(
                for: ShortDigest([UInt8](repeating: 0x01, count: 16)),
                pubnonce: nonce.pubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }
}

/// A 16-byte digest stub used to verify `partialSignature` rejects non-32-byte
/// digests before the bytes reach `secp256k1_musig_nonce_process`.
private struct ShortDigest: Digest {
    static var byteCount: Int {
        16
    }

    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var description: String {
        "ShortDigest: \(bytes.map { String(format: "%02x", $0) }.joined())"
    }

    func makeIterator() -> IndexingIterator<[UInt8]> {
        bytes.makeIterator()
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}
