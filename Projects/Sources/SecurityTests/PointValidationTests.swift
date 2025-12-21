//
//  PointValidationTests.swift
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

/// Tests for point validation vulnerabilities (PV-001 through PV-004).
///
/// These tests ensure the library correctly rejects invalid elliptic curve points
/// that could lead to security vulnerabilities if accepted.
@Suite("Point Validation Security Tests")
struct PointValidationTests {
    // MARK: - PV-001: Reject point at infinity

    @Test("PV-001: Reject compressed point at infinity")
    func rejectCompressedInfinity() throws {
        let invalidPoint = SecurityTestVectors.PointValidation.infinityCompressed

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    @Test("PV-001: Reject uncompressed point at infinity")
    func rejectUncompressedInfinity() throws {
        let invalidPoint = SecurityTestVectors.PointValidation.infinityUncompressed

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .uncompressed
            )
        }
    }

    // MARK: - PV-002: Reject point not on curve (twist/invalid-curve)

    @Test("PV-002: Reject twist curve point")
    func rejectTwistPoint() throws {
        let invalidPoint = SecurityTestVectors.PointValidation.twistPoint

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    // MARK: - PV-003: Reject invalid x-coordinate

    @Test("PV-003: Reject x-coordinate greater than field prime")
    func rejectInvalidXCoordinate() throws {
        let invalidPoint = SecurityTestVectors.PointValidation.invalidXCoordinate

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .compressed
            )
        }
    }

    // MARK: - PV-004: Reject invalid y-coordinate

    @Test("PV-004: Reject y-coordinate not satisfying curve equation")
    func rejectInvalidYCoordinate() throws {
        let invalidPoint = SecurityTestVectors.PointValidation.invalidYCoordinate

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PublicKey(
                dataRepresentation: invalidPoint,
                format: .uncompressed
            )
        }
    }

    // MARK: - Positive test: Valid point should succeed

    @Test("Valid compressed public key should be accepted")
    func acceptValidCompressedKey() throws {
        let validPoint = SecurityTestVectors.PointValidation.validCompressedKey

        let publicKey = try P256K.Signing.PublicKey(
            dataRepresentation: validPoint,
            format: .compressed
        )

        #expect(publicKey.dataRepresentation.count == 33)
    }
}
