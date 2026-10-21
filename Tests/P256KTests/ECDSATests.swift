//
//  ECDSATests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
@testable import P256K
import Testing

/// A 20-byte `Digest` conformer used to exercise SEC1 digest normalization on
/// digest-taking APIs (e.g. `Insecure.SHA1Digest`-shaped inputs).
private struct ShortDigest: Digest {
    static let byteCount = 20
    var bytes: [UInt8] = .init(repeating: 0xAA, count: byteCount)

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

/// A 48-byte `Digest` conformer (e.g. `SHA384Digest`-shaped input) used to
/// exercise leftmost-32-byte truncation on digest-taking APIs.
private struct LongDigest: Digest {
    static let byteCount = 48
    var bytes: [UInt8] = .init(repeating: 0xBB, count: byteCount)

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}

struct ECDSATestSuite {
    @Test("Signing test with expected signature verification")
    func signingECDSA() throws {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedSignature = "dLXvu5gAKdfwfMP6EZsblf8XiIe5GbYO9PKU4JXh+axWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = privateKey.signature(for: messageData)

        // Verify the signature matches the expected output
        #expect(signature.dataRepresentation.base64EncodedString() == expectedSignature)
        #expect(signature.derRepresentation.base64EncodedString() == expectedDerSignature)
    }

    @Test("Signature Verification Test")
    func verifyingTest() throws {
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = privateKey.signature(for: messageData)

        // Verify that the public key is valid for the generated signature
        #expect(privateKey.publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    @Test("DER Signature Verification Test")
    func verifyingDER() throws {
        let expectedDerSignature = try #require(Data(
            base64Encoded: "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A==",
            options: .ignoreUnknownCharacters
        ))
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try P256K.Signing.ECDSASignature(derRepresentation: expectedDerSignature)

        // Convert XCTAssertTrue to #expect
        #expect(privateKey.publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    @Test("Verify invalid raw signature initialization throws correct error")
    func invalidRawSignature() {
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Signing.ECDSASignature(dataRepresentation: Data())
        }
    }

    @Test("Verify invalid DER signature initialization throws correct error")
    func invalidDerSignature() {
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: Data())
        }
    }

    @Test("Verify compact signature initialization rejects non-64-byte input")
    func invalidCompactSignature() {
        // `secp256k1_ecdsa_signature_parse_compact` reads a fixed 64 bytes —
        // a shorter input is an out-of-bounds read, not a parse failure.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Signing.ECDSASignature(compactRepresentation: Data(count: 16))
        }
    }

    @Test("Signing with PEM representation")
    func signingPEM() throws {
        let privateKeyString = """
        -----BEGIN EC PRIVATE KEY-----
        MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
        oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
        2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END EC PRIVATE KEY-----
        """

        let expectedDerSignature = "MEQCIC8k5whKPsPg7XtWTInvhGL4iEU6lP6yPdpEXXZ2mOhFAiAZ3Po9tEDV8mQ8LDzwF0nhPmAn9VLYG8bkuY6PKruZNQ=="
        let privateKey = try P256K.Signing.PrivateKey(pemRepresentation: privateKeyString)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = privateKey.signature(for: messageData)

        // Verify the signature matches the expected output
        #expect(signature.derRepresentation.base64EncodedString() == expectedDerSignature, "Signature DER representation mismatch")
    }

    @Test("Signing accepts a non-32-byte digest via SEC1 normalization")
    func shortDigestSigns() throws {
        let privateKey = try P256K.Signing.PrivateKey()

        // `secp256k1_ecdsa_sign` reads exactly 32 bytes — the digest is reduced
        // to the SEC1 §4.1.3 msg32 value (integer value for shorter digests)
        // instead of being rejected or read out of bounds.
        let signature = privateKey.signature(for: ShortDigest())

        #expect(privateKey.publicKey.isValidSignature(signature, for: ShortDigest()))
    }

    @Test("A longer digest is truncated to its leftmost 32 bytes")
    func longDigestTruncates() throws {
        let privateKey = try P256K.Signing.PrivateKey()

        // Signing over a longer digest signs its leftmost 32 bytes — the same
        // reduction Go crypto/ecdsa and OpenSSL apply — and the same reduction
        // applies at verification, so the signature round-trips.
        let signature = privateKey.signature(for: LongDigest())

        #expect(privateKey.publicKey.isValidSignature(signature, for: LongDigest()))
        #expect(privateKey.publicKey.isValidSignature(signature, for: ShortDigest()) == false)
    }

    @Test("Verification applies the same digest normalization as signing")
    func shortDigestVerifyFails() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let messageData = try #require("We're all Satoshi.".data(using: .utf8))
        let signature = privateKey.signature(for: SHA256.hash(data: messageData))

        // The normalized ShortDigest is a different message than the SHA-256 hash
        // that was signed, so verification honestly reports invalid.
        #expect(privateKey.publicKey.isValidSignature(signature, for: ShortDigest()) == false)
    }

    @Test("dataRepresentation is the canonical compact wire form")
    func canonicalDataRepresentation() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let messageData = try #require("We're all Satoshi.".data(using: .utf8))
        let signature = privateKey.signature(for: SHA256.hash(data: messageData))

        // The stored bytes are the 64-byte `r || s` wire form — identical to
        // compactRepresentation — and round-trip through both public inits.
        #expect(signature.dataRepresentation == signature.compactRepresentation)

        let restored = try P256K.Signing.ECDSASignature(dataRepresentation: signature.dataRepresentation)
        #expect(restored.dataRepresentation == signature.dataRepresentation)
        #expect(restored.derRepresentation == signature.derRepresentation)
    }

    @Test("Signature initialization rejects out-of-range scalars")
    func outOfRangeScalarSignature() throws {
        // r = curve order (n) and beyond must fail parse_compact, not reach the
        // DER/verify paths — FFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 is n.
        let nBytes = try ("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141" +
            "0000000000000000000000000000000000000000000000000000000000000001").bytes
        let nData = Data(nBytes)

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Signing.ECDSASignature(dataRepresentation: nData)
        }

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Signing.ECDSASignature(dataRepresentation: Data(repeating: 0xFF, count: 64))
        }
    }

    @Test("Verifying with PEM representation")
    func verifyingPEM() throws {
        let publicKeyString = """
        -----BEGIN PUBLIC KEY-----
        MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMA
        cjHIrTDS6HEELgguOatmFBOp2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END PUBLIC KEY-----
        """

        let expectedSignature = "MEQCIEwVxXLE/mwaRzxLvz9VIcMtHaa/Wf1WRxiBJ6NEuWHeAiAQWf2oqqBqEtBABbmwsXqjCJFvsaPt8o+VaOthto1kWQ=="
        let expectedDerSignature = try #require(Data(base64Encoded: expectedSignature, options: .ignoreUnknownCharacters))

        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!
        let signature = try P256K.Signing.ECDSASignature(derRepresentation: expectedDerSignature)
        let publicKey = try P256K.Signing.PublicKey(pemRepresentation: publicKeyString)

        #expect(publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)), "Signature validation failed")
    }
}
