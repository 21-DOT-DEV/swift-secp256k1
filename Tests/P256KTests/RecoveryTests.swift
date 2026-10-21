//
//  RecoveryTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

@testable import P256K
import Testing
import XCTest

/// A 20-byte `Digest` conformer used to exercise the fixed-32-byte input guards
/// on digest-taking APIs (e.g. `Insecure.SHA1Digest`-shaped inputs).
private struct ShortDigest: Digest {
    static let byteCount = 20
    var bytes: [UInt8] = .init(repeating: 0xAA, count: byteCount)

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

struct RecoveryTestSuite {
    @Test("Recovery signing test with expected recovery signature verification")
    func recoverySigningTest() throws {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedRecoverySignature = "dLXvu5gAKdfwfMP6EZsblf8XiIe5GbYO9PKU4JXh+axWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+AE="
        let expectedSignature = "dLXvu5gAKdfwfMP6EZsblf8XiIe5GbYO9PKU4JXh+axWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = privateKey.signature(for: messageData)

        // Verify the recovery signature matches the expected output
        #expect(recoverySignature.dataRepresentation.base64EncodedString() == expectedRecoverySignature)

        let signature = recoverySignature.normalize

        // Verify the signature matches the expected output
        #expect(signature.dataRepresentation.base64EncodedString() == expectedSignature)
        #expect(signature.derRepresentation.base64EncodedString() == expectedDerSignature)
    }

    @Test("Public key recovery test")
    func publicKeyRecoveryTest() throws {
        let expectedRecoverySignature = "dLXvu5gAKdfwfMP6EZsblf8XiIe5GbYO9PKU4JXh+axWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+AE="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = privateKey.signature(for: messageData)

        // Verify the recovery signature matches the expected output
        #expect(recoverySignature.dataRepresentation.base64EncodedString() == expectedRecoverySignature)

        let publicKey = try P256K.Recovery.PublicKey(messageData, signature: recoverySignature)

        // Verify the recovered public key matches the expected public key
        #expect(publicKey.dataRepresentation == privateKey.publicKey.dataRepresentation)
    }

    @Test("Recoverable signature init rejects an out-of-range recovery ID")
    func invalidRecoveryIdThrows() {
        // Recovery IDs are 0–3. A byte ≥ 4 previously slipped past init into
        // `secp256k1_ecdsa_recover`, where it either tripped an upstream
        // assertion (VERIFY builds) or silently selected a different candidate
        // key — and it triggered `ARG_CHECK` → process abort at parse time.
        var wireBytes = Data(repeating: 0, count: P256K.ByteLength.signature)
        wireBytes.append(4)

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Recovery.ECDSASignature(dataRepresentation: wireBytes)
        }

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Recovery.ECDSASignature(
                compactRepresentation: Data(repeating: 0, count: P256K.ByteLength.signature),
                recoveryId: 5
            )
        }

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Recovery.ECDSASignature(
                compactRepresentation: Data(repeating: 0, count: P256K.ByteLength.signature),
                recoveryId: -1
            )
        }
    }

    @Test("Recoverable signature init rejects wrong byte counts")
    func invalidSignatureSizeThrows() {
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Recovery.ECDSASignature(dataRepresentation: Data(repeating: 0, count: P256K.ByteLength.signature))
        }

        // A short compact input previously reached the C parser, which reads a
        // fixed 64 bytes — an out-of-bounds read.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Recovery.ECDSASignature(
                compactRepresentation: Data(repeating: 0, count: 32),
                recoveryId: 0
            )
        }
    }

    @Test("Recoverable signature init rejects overflowing scalars")
    func overflowingScalarThrows() throws {
        // r = curve order n (0xFF…4141), s = 1, recid = 0 — a 65-byte blob that
        // parses-shaped but whose r is not a valid scalar.
        let curveOrderBytes = try "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141".bytes
        var wireBytes = Data(curveOrderBytes)
        wireBytes.append(contentsOf: Data(repeating: 0, count: 31) + [1])
        wireBytes.append(0)

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Recovery.ECDSASignature(dataRepresentation: wireBytes)
        }
    }

    @Test("Public key recovery throws on an unrecoverable signature")
    func unrecoverableSignatureThrows() throws {
        // r = 0, s = 0, recid = 0 parses cleanly, but `secp256k1_ecdsa_recover`
        // rejects zero scalars. This must surface a thrown error — previously
        // it reached `fatalError` and terminated the process.
        var wireBytes = Data(repeating: 0, count: P256K.ByteLength.signature)
        wireBytes.append(0)
        let signature = try P256K.Recovery.ECDSASignature(dataRepresentation: wireBytes)
        let messageData = "attacker-controlled bytes".data(using: .utf8)!

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Recovery.PublicKey(messageData, signature: signature)
        }
    }

    @Test("Recovery signing accepts a non-32-byte digest via SEC1 normalization")
    func shortDigestSigns() throws {
        let privateKey = try P256K.Recovery.PrivateKey()

        // `secp256k1_ecdsa_sign_recoverable` reads exactly 32 bytes — the digest
        // is reduced to the SEC1 §4.1.3 msg32 value (integer value for shorter
        // digests) instead of being rejected or read out of bounds.
        let signature = privateKey.signature(for: ShortDigest())

        // Recovery over the same normalized digest reproduces the signing key.
        let recovered = try P256K.Recovery.PublicKey(ShortDigest(), signature: signature)
        #expect(recovered.dataRepresentation == privateKey.publicKey.dataRepresentation)
    }

    @Test("Public key recovery over a normalized digest yields a valid key")
    func shortDigestRecovery() throws {
        let privateKey = try P256K.Recovery.PrivateKey()
        let messageData = "We're all Satoshi.".data(using: .utf8)!
        let signature = privateKey.signature(for: messageData)

        // The normalized ShortDigest is a different message — recovery produces
        // a well-formed public key that is simply not the signer's.
        let recovered = try P256K.Recovery.PublicKey(ShortDigest(), signature: signature)
        #expect(recovered.dataRepresentation.count == 33)
    }

    @Test("Recoverable signature round-trips through compactRepresentation")
    func compactRoundTrip() throws {
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = privateKey.signature(for: messageData)
        let compact = recoverySignature.compactRepresentation

        // recid = 1 for this known vector
        #expect(compact.recoveryId == 1)

        let restored = try P256K.Recovery.ECDSASignature(
            compactRepresentation: compact.signature,
            recoveryId: compact.recoveryId
        )

        #expect(restored.dataRepresentation == recoverySignature.dataRepresentation)
    }
}
