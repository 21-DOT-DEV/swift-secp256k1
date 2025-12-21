//
//  InvalidCurveTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import Testing

@testable import P256K

/// Tests for invalid curve attack vulnerabilities (IC-001 through IC-002).
///
/// These tests ensure the library correctly rejects points that are not on the secp256k1 curve,
/// which could leak private key information through invalid curve attacks on ECDH.
@Suite("Invalid Curve Attack Security Tests")
struct InvalidCurveTests {
    // MARK: - IC-001: Reject truncated public key

    @Test("IC-001: Reject truncated public key in ECDH")
    func rejectTruncatedKeyECDH() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.truncatedKey

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    @Test("IC-001: Reject truncated public key for Signing")
    func rejectTruncatedKeyForSigning() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.truncatedKey

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    // MARK: - IC-002: Reject invalid header byte

    @Test("IC-002: Reject invalid header byte in ECDH")
    func rejectInvalidHeaderECDH() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.invalidHeaderKey

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    @Test("IC-002: Reject invalid header byte for Signing")
    func rejectInvalidHeaderForSigning() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.invalidHeaderKey

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    // MARK: - ECDH with invalid public key should fail

    @Test("ECDH rejects truncated public key")
    func ecdhRejectsTruncatedKey() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.truncatedKey

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    @Test("ECDH rejects invalid header public key")
    func ecdhRejectsInvalidHeader() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.invalidHeaderKey

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    // MARK: - Positive test: Valid ECDH should succeed

    @Test("Valid ECDH key agreement should succeed")
    func validECDHSucceeds() throws {
        let alicePrivate = try P256K.KeyAgreement.PrivateKey()
        let bobPrivate = try P256K.KeyAgreement.PrivateKey()

        let alicePublic = alicePrivate.publicKey
        let bobPublic = bobPrivate.publicKey

        // Both parties compute shared secret
        let aliceShared = try alicePrivate.sharedSecretFromKeyAgreement(with: bobPublic)
        let bobShared = try bobPrivate.sharedSecretFromKeyAgreement(with: alicePublic)

        // Shared secrets should match
        #expect(
            aliceShared.bytes == bobShared.bytes,
            "ECDH shared secrets should match"
        )
    }

    @Test("ECDH with serialized/deserialized public key should succeed")
    func ecdhWithSerializedKeySucceeds() throws {
        let alicePrivate = try P256K.KeyAgreement.PrivateKey()
        let bobPrivate = try P256K.KeyAgreement.PrivateKey()

        // Serialize and deserialize Bob's public key (simulating network transmission)
        let bobPublicBytes = bobPrivate.publicKey.dataRepresentation
        let deserializedBobPublic = try P256K.KeyAgreement.PublicKey(
            dataRepresentation: bobPublicBytes,
            format: .compressed
        )

        // Alice computes shared secret with deserialized key
        let sharedSecret = try alicePrivate.sharedSecretFromKeyAgreement(with: deserializedBobPublic)

        #expect(sharedSecret.bytes.count > 0, "Shared secret should have bytes")
    }

    // MARK: - Edge case: All zeros x-coordinate

    @Test("Reject public key with all-zeros x-coordinate")
    func rejectAllZerosXCoordinate() throws {
        // x = 0 is not a valid x-coordinate on secp256k1
        var invalidPoint: [UInt8] = [0x02]
        invalidPoint.append(contentsOf: Array(repeating: 0x00, count: 32))

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    @Test("Reject public key with x-coordinate equal to field prime")
    func rejectXEqualToFieldPrime() throws {
        // x = p (field prime) is not valid
        var invalidPoint: [UInt8] = [0x02]
        invalidPoint.append(contentsOf: SecurityTestVectors.fieldPrime)

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    // MARK: - libsecp256k1 Invalid Point Test Vectors

    // From Vendor/secp256k1/src/tests.c

    @Test("Reject twist curve point (y² = x³ + 9)")
    func rejectTwistCurvePoint() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.twistCurvePoint

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .uncompressed
            )
        }
    }

    @Test("Reject x overflow point (x = p + 1)")
    func rejectXOverflowPoint() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.xOverflowPoint

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .uncompressed
            )
        }
    }

    @Test("Reject x = -1 point (on wrong curve)")
    func rejectXNegativeOnePoint() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.xNegativeOnePoint

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .uncompressed
            )
        }
    }

    @Test("Reject x = 0 with invalid y")
    func rejectXZeroInvalidY() throws {
        let invalidPoint = SecurityTestVectors.InvalidCurve.xZeroInvalidY

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PublicKey(
                dataRepresentation: invalidPoint,
                format: .uncompressed
            )
        }
    }
}
