//
//  NonceSecurityTests.swift
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

/// Tests for nonce security vulnerabilities (NS-001 through NS-003).
///
/// These tests ensure the library correctly implements deterministic nonces (RFC 6979)
/// and prevents nonce reuse in MuSig2 operations.
///
/// Note on NS-002: SecureNonce reuse is prevented at compile-time by Swift's type system.
/// The `consuming` keyword on `partialSignature` ensures the nonce cannot be used twice.
/// This is stronger than a runtime check - it's enforced by the compiler.
@Suite("Nonce Security Tests")
struct NonceSecurityTests {
    // MARK: - NS-001: Deterministic nonce (RFC 6979)

    @Test("NS-001: ECDSA signatures are deterministic (RFC 6979)")
    func ecdsaDeterministicNonce() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let message = SecurityTestVectors.NonceSecurity.testMessage
        let digest = SHA256.hash(data: Data(message))

        // Sign the same message twice
        let signature1 = try privateKey.signature(for: digest)
        let signature2 = try privateKey.signature(for: digest)

        // Both signatures should be identical (deterministic nonce)
        let compact1 = try signature1.compactRepresentation
        let compact2 = try signature2.compactRepresentation

        #expect(compact1 == compact2, "RFC 6979 deterministic nonces should produce identical signatures")
    }

    @Test("NS-001: Different messages produce different signatures")
    func differentMessagesDifferentSignatures() throws {
        let privateKey = try P256K.Signing.PrivateKey()

        let message1 = "first message".data(using: .utf8)!
        let message2 = "second message".data(using: .utf8)!

        let digest1 = SHA256.hash(data: message1)
        let digest2 = SHA256.hash(data: message2)

        let signature1 = try privateKey.signature(for: digest1)
        let signature2 = try privateKey.signature(for: digest2)

        let compact1 = try signature1.compactRepresentation
        let compact2 = try signature2.compactRepresentation

        #expect(compact1 != compact2, "Different messages should produce different signatures")
    }

    @Test("NS-001: Different keys produce different signatures for same message")
    func differentKeysDifferentSignatures() throws {
        let privateKey1 = try P256K.Signing.PrivateKey()
        let privateKey2 = try P256K.Signing.PrivateKey()

        let message = "same message".data(using: .utf8)!
        let digest = SHA256.hash(data: message)

        let signature1 = try privateKey1.signature(for: digest)
        let signature2 = try privateKey2.signature(for: digest)

        let compact1 = try signature1.compactRepresentation
        let compact2 = try signature2.compactRepresentation

        #expect(compact1 != compact2, "Different keys should produce different signatures")
    }

    // MARK: - NS-002: MuSig2 SecureNonce is non-copyable

    @Test("NS-002: SecureNonce is compile-time protected against reuse")
    func secureNonceCompileTimeProtection() throws {
        // This test documents that SecureNonce reuse is prevented by the Swift type system.
        //
        // The `P256K.Schnorr.SecureNonce` type is marked as `~Copyable`, and the
        // `partialSignature` method takes it as `consuming`. This means:
        //
        // 1. SecureNonce cannot be copied (no implicit or explicit copy)
        // 2. After passing to partialSignature, the nonce is consumed and cannot be reused
        // 3. Attempting to use it twice is a COMPILE-TIME ERROR, not a runtime error
        //
        // This is actually stronger security than a runtime check because:
        // - The vulnerability is caught during development, not in production
        // - There's no possibility of a race condition or logic error allowing reuse
        // - The Swift compiler guarantees this invariant
        //
        // Example of what would NOT compile:
        // ```
        // let nonce = try P256K.MuSig.Nonce.generate(...)
        // let sig1 = try privateKey.partialSignature(..., secureNonce: nonce.secnonce, ...)
        // let sig2 = try privateKey.partialSignature(..., secureNonce: nonce.secnonce, ...) // ERROR!
        // ```

        // We can verify the type exists and is used correctly
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.publicKey
        let msg32 = SecurityTestVectors.NonceSecurity.testMessageHash

        // Generate a nonce (this succeeds)
        let nonceResult = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32
        )

        // The secnonce exists and has the expected internal structure
        // We can't directly inspect it (it's opaque), but we can verify generation succeeded
        #expect(nonceResult.pubnonce.pubnonce.count > 0, "Nonce generation should produce valid pubnonce")

        // Note: We don't actually consume the nonce in this test because that would
        // require a full MuSig2 signing session. The compile-time guarantee is the test.
    }

    // MARK: - NS-003: Constant session ID produces deterministic nonces

    @Test("NS-003: Constant session ID with same inputs produces same nonce")
    func constantSessionIDProducesSameNonce() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.publicKey
        let msg32 = SecurityTestVectors.NonceSecurity.testMessageHash
        let constantSessionID = SecurityTestVectors.NonceSecurity.constantSessionID

        // Extend to expected size (133 bytes based on the API)
        var sessionID = constantSessionID
        sessionID.append(contentsOf: Array(repeating: 0x00, count: 133 - constantSessionID.count))

        // Generate nonces with the same session ID
        let nonce1 = try P256K.MuSig.Nonce.generate(
            sessionID: sessionID,
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32,
            extraInput32: nil
        )

        let nonce2 = try P256K.MuSig.Nonce.generate(
            sessionID: sessionID,
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32,
            extraInput32: nil
        )

        // With deterministic inputs, nonces should be identical
        // This demonstrates why unique session IDs are critical
        let pubnonce1 = nonce1.pubnonce.dataRepresentation
        let pubnonce2 = nonce2.pubnonce.dataRepresentation

        #expect(
            pubnonce1 == pubnonce2,
            "Same session ID + inputs should produce same nonce (demonstrating importance of randomness)"
        )
    }

    @Test("NS-003: Different session IDs produce different nonces")
    func differentSessionIDsProduceDifferentNonces() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.publicKey
        let msg32 = SecurityTestVectors.NonceSecurity.testMessageHash

        // Two different session IDs (extended to 133 bytes)
        var sessionID1 = Array(repeating: UInt8(0x01), count: 133)
        var sessionID2 = Array(repeating: UInt8(0x02), count: 133)

        let nonce1 = try P256K.MuSig.Nonce.generate(
            sessionID: sessionID1,
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32,
            extraInput32: nil
        )

        let nonce2 = try P256K.MuSig.Nonce.generate(
            sessionID: sessionID2,
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32,
            extraInput32: nil
        )

        let pubnonce1 = nonce1.pubnonce.dataRepresentation
        let pubnonce2 = nonce2.pubnonce.dataRepresentation

        #expect(
            pubnonce1 != pubnonce2,
            "Different session IDs should produce different nonces"
        )
    }

    @Test("NS-003: Default nonce generation uses randomness")
    func defaultNonceGenerationUsesRandomness() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let publicKey = privateKey.publicKey
        let msg32 = SecurityTestVectors.NonceSecurity.testMessageHash

        // Use the default generate() which internally uses SecureBytes for randomness
        let nonce1 = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32
        )

        let nonce2 = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: publicKey,
            msg32: msg32
        )

        let pubnonce1 = nonce1.pubnonce.dataRepresentation
        let pubnonce2 = nonce2.pubnonce.dataRepresentation

        #expect(
            pubnonce1 != pubnonce2,
            "Default nonce generation should use randomness and produce different nonces"
        )
    }
}
