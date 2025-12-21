//
//  ZeroSignatureTests.swift
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

/// Tests for zero/invalid signature value vulnerabilities (ZS-001 through ZS-004).
///
/// These tests ensure the library correctly rejects signatures with zero or invalid
/// r/s values, which could lead to signature forgery (e.g., CVE-2022-21449 "Psychic Signatures").
@Suite("Zero Signature Security Tests")
struct ZeroSignatureTests {
    // MARK: - Test Setup

    /// Creates a valid keypair for verification tests
    private func createTestKeypair() throws -> (P256K.Signing.PrivateKey, P256K.Signing.PublicKey) {
        let privateKey = try P256K.Signing.PrivateKey()
        return (privateKey, privateKey.publicKey)
    }

    // MARK: - ZS-001: Reject r=0 signature

    @Test("ZS-001: Reject ECDSA signature with r=0")
    func rejectZeroRSignature() throws {
        let (_, publicKey) = try createTestKeypair()
        let zeroRSignature = SecurityTestVectors.ZeroSignature.zeroR
        let message = "test message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        do {
            let signature = try P256K.Signing.ECDSASignature(compactRepresentation: zeroRSignature)
            let isValid = publicKey.isValidSignature(signature, for: digest)
            #expect(!isValid, "Signature with r=0 should not verify")
        } catch {
            // Parsing failure is also acceptable - signature is rejected
        }
    }

    // MARK: - ZS-002: Reject s=0 signature

    @Test("ZS-002: Reject ECDSA signature with s=0")
    func rejectZeroSSignature() throws {
        let (_, publicKey) = try createTestKeypair()
        let zeroSSignature = SecurityTestVectors.ZeroSignature.zeroS
        let message = "test message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        do {
            let signature = try P256K.Signing.ECDSASignature(compactRepresentation: zeroSSignature)
            let isValid = publicKey.isValidSignature(signature, for: digest)
            #expect(!isValid, "Signature with s=0 should not verify")
        } catch {
            // Parsing failure is also acceptable - signature is rejected
        }
    }

    // MARK: - ZS-003: Reject "Psychic Signature" (r=0, s=0)

    @Test("ZS-003: Reject psychic signature (r=0, s=0) - CVE-2022-21449")
    func rejectPsychicSignature() throws {
        let (_, publicKey) = try createTestKeypair()
        let psychicSignature = SecurityTestVectors.ZeroSignature.psychicSignature
        let message = "any message at all".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        do {
            let signature = try P256K.Signing.ECDSASignature(compactRepresentation: psychicSignature)
            let isValid = publicKey.isValidSignature(signature, for: digest)
            #expect(!isValid, "Psychic signature (r=0, s=0) should not verify for any message")
        } catch {
            // Parsing failure is also acceptable - signature is rejected
        }
    }

    @Test("ZS-003: Psychic signature should fail for multiple messages")
    func psychicSignatureFailsForAllMessages() throws {
        let (_, publicKey) = try createTestKeypair()
        let psychicSignature = SecurityTestVectors.ZeroSignature.psychicSignature

        // Try verifying the psychic signature against multiple different messages
        let messages = [
            "hello world",
            "transfer 1000 BTC",
            "admin access granted",
            "",
            String(repeating: "x", count: 1000)
        ]

        for message in messages {
            let digest = SHA256.hash(data: Data(message.utf8))

            do {
                let signature = try P256K.Signing.ECDSASignature(compactRepresentation: psychicSignature)
                let isValid = publicKey.isValidSignature(signature, for: digest)
                #expect(!isValid, "Psychic signature should not verify for message: \(message.prefix(20))")
            } catch {
                // Parsing failure is expected and acceptable
            }
        }
    }

    // MARK: - ZS-004: Reject Schnorr with zero R

    @Test("ZS-004: Reject Schnorr signature with zero R point")
    func rejectSchnorrZeroR() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.xonly
        let schnorrZeroR = SecurityTestVectors.ZeroSignature.schnorrZeroR
        let message = "test message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        do {
            let signature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: schnorrZeroR)
            let isValid = publicKey.isValidSignature(signature, for: digest)
            #expect(!isValid, "Schnorr signature with R=0 should not verify")
        } catch {
            // Parsing failure is also acceptable - signature is rejected
        }
    }

    // MARK: - Positive test: Valid signatures should verify

    @Test("Valid ECDSA signature should verify")
    func validECDSASignatureVerifies() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let message = "valid test message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        let signature = try privateKey.signature(for: digest)
        let isValid = publicKey.isValidSignature(signature, for: digest)

        #expect(isValid, "Valid ECDSA signature should verify")
    }

    @Test("Valid Schnorr signature should verify")
    func validSchnorrSignatureVerifies() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.xonly
        let message = "valid test message".data(using: .utf8)!

        let signature = try privateKey.signature(for: message)
        let isValid = publicKey.isValidSignature(signature, for: message)

        #expect(isValid, "Valid Schnorr signature should verify")
    }
}
