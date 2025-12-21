//
//  ScalarValidationTests.swift
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

/// Tests for scalar validation vulnerabilities (SV-001 through SV-003).
///
/// These tests ensure the library correctly validates private key scalars
/// to prevent weak key attacks and out-of-range values.
@Suite("Scalar Validation Security Tests")
struct ScalarValidationTests {
    // MARK: - SV-001: Reject zero private key

    @Test("SV-001: Reject zero private key for Signing")
    func rejectZeroPrivateKeyForSigning() throws {
        let zeroKey = SecurityTestVectors.ScalarValidation.zeroKey

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PrivateKey(dataRepresentation: zeroKey)
        }
    }

    @Test("SV-001: Reject zero private key for KeyAgreement")
    func rejectZeroPrivateKeyForKeyAgreement() throws {
        let zeroKey = SecurityTestVectors.ScalarValidation.zeroKey

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PrivateKey(dataRepresentation: zeroKey)
        }
    }

    @Test("SV-001: Reject zero private key for Schnorr")
    func rejectZeroPrivateKeyForSchnorr() throws {
        let zeroKey = SecurityTestVectors.ScalarValidation.zeroKey

        #expect(throws: (any Error).self) {
            _ = try P256K.Schnorr.PrivateKey(dataRepresentation: zeroKey)
        }
    }

    // MARK: - SV-002: Reject scalar ≥ group order

    @Test("SV-002: Reject scalar equal to curve order for Signing")
    func rejectScalarEqualToOrderForSigning() throws {
        let invalidKey = SecurityTestVectors.ScalarValidation.scalarEqualToOrder

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PrivateKey(dataRepresentation: invalidKey)
        }
    }

    @Test("SV-002: Reject scalar greater than curve order for Signing")
    func rejectScalarGreaterThanOrderForSigning() throws {
        let invalidKey = SecurityTestVectors.ScalarValidation.scalarGreaterThanOrder

        #expect(throws: (any Error).self) {
            _ = try P256K.Signing.PrivateKey(dataRepresentation: invalidKey)
        }
    }

    @Test("SV-002: Reject scalar equal to curve order for KeyAgreement")
    func rejectScalarEqualToOrderForKeyAgreement() throws {
        let invalidKey = SecurityTestVectors.ScalarValidation.scalarEqualToOrder

        #expect(throws: (any Error).self) {
            _ = try P256K.KeyAgreement.PrivateKey(dataRepresentation: invalidKey)
        }
    }

    @Test("SV-002: Reject scalar equal to curve order for Schnorr")
    func rejectScalarEqualToOrderForSchnorr() throws {
        let invalidKey = SecurityTestVectors.ScalarValidation.scalarEqualToOrder

        #expect(throws: (any Error).self) {
            _ = try P256K.Schnorr.PrivateKey(dataRepresentation: invalidKey)
        }
    }

    // MARK: - SV-003: Accept max valid scalar (n - 1)

    @Test("SV-003: Accept maximum valid scalar for Signing")
    func acceptMaxValidScalarForSigning() throws {
        let maxValid = SecurityTestVectors.ScalarValidation.maxValidScalar

        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: maxValid)

        #expect(privateKey.dataRepresentation.count == 32)
    }

    @Test("SV-003: Accept maximum valid scalar for KeyAgreement")
    func acceptMaxValidScalarForKeyAgreement() throws {
        let maxValid = SecurityTestVectors.ScalarValidation.maxValidScalar

        let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: maxValid)

        #expect(privateKey.rawRepresentation.count == 32)
    }

    @Test("SV-003: Accept maximum valid scalar for Schnorr")
    func acceptMaxValidScalarForSchnorr() throws {
        let maxValid = SecurityTestVectors.ScalarValidation.maxValidScalar

        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: maxValid)

        #expect(privateKey.dataRepresentation.count == 32)
    }

    // MARK: - Positive test: Valid private key should succeed

    @Test("Valid private key should be accepted")
    func acceptValidPrivateKey() throws {
        let validKey = SecurityTestVectors.ScalarValidation.validPrivateKey

        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: validKey)

        #expect(privateKey.dataRepresentation.count == 32)
    }
}
