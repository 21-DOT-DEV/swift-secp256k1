//
//  SignatureMalleabilityTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import CryptoKit
import Foundation
import Testing

@testable import P256K

/// Tests for signature malleability vulnerabilities (SM-001 through SM-002).
///
/// These tests ensure the library correctly enforces low-s signatures
/// to prevent transaction malleability attacks (BIP-62, BIP-66, BIP-146).
///
/// Note: SM-003 (normalize then verify) is skipped because `secp256k1_ecdsa_signature_normalize`
/// is not exposed in the Swift API. libsecp256k1 auto-normalizes during signing.
@Suite("Signature Malleability Security Tests")
struct SignatureMalleabilityTests {
    // MARK: - SM-001: Reject high-s signature

    @Test("SM-001: High-s compact signature should fail verification")
    func rejectHighSSignature() throws {
        let highSSignature = SecurityTestVectors.SignatureMalleability.highSSignature

        // Create a valid keypair for verification
        let privateKey = try P256K.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let message = "test message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        // Attempt to create signature from high-s bytes
        // The signature parsing should succeed, but verification should fail
        // because libsecp256k1 enforces low-s in verification
        do {
            let signature = try P256K.Signing.ECDSASignature(compactRepresentation: highSSignature)

            // Verification of a high-s signature should fail
            let isValid = publicKey.isValidSignature(signature, for: digest)
            #expect(!isValid, "High-s signature should not verify")
        } catch {
            // Parsing might also fail, which is acceptable
            // Either way, the high-s signature is rejected
        }
    }

    // MARK: - SM-002: Accept low-s signature

    @Test("SM-002: Library-generated signatures should always be low-s")
    func libraryGeneratesLowSSignatures() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let message = "test message for low-s verification".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        // Sign the message
        let signature = try privateKey.signature(for: digest)

        // Get the compact representation to check s value
        let compactSig = try signature.compactRepresentation

        // Extract s value (last 32 bytes of compact signature)
        let sBytes = Array(compactSig.suffix(32))

        // s should be <= n/2 (low-s)
        let halfOrder = SecurityTestVectors.SignatureMalleability.halfOrder

        // Compare s with n/2
        var sIsLow = true
        for i in 0..<32 {
            if sBytes[i] < halfOrder[i] {
                break
            } else if sBytes[i] > halfOrder[i] {
                sIsLow = false
                break
            }
        }

        #expect(sIsLow, "Library should generate low-s signatures")

        // Verify the signature works
        let isValid = publicKey.isValidSignature(signature, for: digest)
        #expect(isValid, "Low-s signature should verify successfully")
    }

    @Test("SM-002: Multiple signatures should all be low-s")
    func multipleSignaturesAreLowS() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let halfOrder = SecurityTestVectors.SignatureMalleability.halfOrder

        // Sign multiple different messages
        for i in 0..<10 {
            let message = "test message \(i)".data(using: .utf8)!
            let digest = SHA256.hash(data: message)
            let signature = try privateKey.signature(for: digest)
            let compactSig = try signature.compactRepresentation
            let sBytes = Array(compactSig.suffix(32))

            // Check s <= n/2
            var sIsLow = true
            for j in 0..<32 {
                if sBytes[j] < halfOrder[j] {
                    break
                } else if sBytes[j] > halfOrder[j] {
                    sIsLow = false
                    break
                }
            }

            #expect(sIsLow, "Signature \(i) should be low-s")
        }
    }
}
