//
//  SecretRedactionTests.swift
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

/// The redaction contract: no string-rendering channel may emit secret bytes
/// for any copyable secret-bearing type. The `~Copyable` secret types
/// (`P256K.Schnorr.SecureNonce`, `P256K.MuSig.SessionSecretRand`, and the
/// `P256K.MuSig.NonceResult` that carries a `SecureNonce`) are deliberately
/// uncovered — the type system rejects them as arguments to
/// `String(describing:)`, `String(reflecting:)`, and string interpolation, so
/// the leak is impossible at compile time rather than merely absent at runtime.
/// `SecureBytes` joins the public types because every secret lives in it: its
/// bytes are tail-allocated `ManagedBuffer` elements, which no render channel
/// can reach, and this suite keeps that invariant from drifting silently.
struct SecretRedactionTestSuite {
    /// A valid 32-byte secp256k1 secret scalar, fixed so the absence checks are exact.
    private static let secretScalar = [UInt8](repeating: 0x11, count: 32)
    /// A 33-byte input standing in for the compressed-form shared point.
    private static let compressedSecret = [UInt8](1...33)
    /// A 65-byte input standing in for the uncompressed-form shared point.
    private static let uncompressedSecret = [UInt8](1...65)

    /// The encodings a render channel could use to expose a byte sequence:
    /// lowercase hex, a Swift collection literal, and Base64.
    private static func byteEncodings(of bytes: [UInt8]) -> [(name: String, value: String)] {
        [
            ("hex", bytes.map { String(format: "%02x", $0) }.joined()),
            ("collection literal", "[" + bytes.map(String.init).joined(separator: ", ") + "]"),
            ("base64", Data(bytes).base64EncodedString())
        ]
    }

    /// Asserts that every render channel — `String(describing:)`,
    /// `String(reflecting:)`, and `\(…)` interpolation — omits every byte
    /// encoding of `secretBytes` for `value`.
    private func assertRedacted(_ value: some Any, secretBytes: [UInt8]) {
        let renderings: [(channel: String, output: String)] = [
            ("String(describing:)", String(describing: value)),
            ("String(reflecting:)", String(reflecting: value)),
            ("interpolation", "\(value)")
        ]
        for (channel, output) in renderings {
            for encoding in Self.byteEncodings(of: secretBytes) {
                #expect(
                    !output.contains(encoding.value),
                    "\(channel) of \(type(of: value)) exposed secret bytes as \(encoding.name)"
                )
            }
        }
    }

    /// `SharedSecret`'s `CustomStringConvertible` once interpolated the
    /// complete ECDH shared secret as hex — audit finding B-1. The conformance
    /// now prints a byte count and nothing else.
    @Test("SharedSecret description reports a byte count, never the bytes")
    func sharedSecretRendersRedacted() {
        let compressed = SharedSecret(ss: SecureBytes(bytes: Self.compressedSecret), format: .compressed)
        let uncompressed = SharedSecret(ss: SecureBytes(bytes: Self.uncompressedSecret), format: .uncompressed)

        #expect(String(describing: compressed) == "SharedSecret representation contains 33 bytes.")
        #expect(String(describing: uncompressed) == "SharedSecret representation contains 65 bytes.")
        #expect(String(reflecting: compressed) == compressed.description)

        assertRedacted(compressed, secretBytes: Self.compressedSecret)
        assertRedacted(uncompressed, secretBytes: Self.uncompressedSecret)
    }

    @Test("Signing.PrivateKey renderings omit the secret scalar")
    func signingPrivateKeyRendersRedacted() throws {
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: Self.secretScalar)
        assertRedacted(privateKey, secretBytes: Self.secretScalar)
    }

    /// `SecureBytes` is internal, but it is the storage every secret-bearing
    /// type delegates to — a render regression here reopens the leak in all of
    /// them at once.
    @Test("SecureBytes renderings omit the stored bytes")
    func secureBytesRendersRedacted() {
        let secureBytes = SecureBytes(bytes: Self.secretScalar)
        assertRedacted(secureBytes, secretBytes: Array(secureBytes))
    }

    #if Xcode || ENABLE_MODULE_ECDH
        @Test("KeyAgreement.PrivateKey renderings omit the secret scalar")
        func keyAgreementPrivateKeyRendersRedacted() throws {
            let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: Self.secretScalar)
            assertRedacted(privateKey, secretBytes: Self.secretScalar)
        }
    #endif

    #if Xcode || ENABLE_MODULE_SCHNORRSIG
        @Test("Schnorr.PrivateKey renderings omit the secret scalar")
        func schnorrPrivateKeyRendersRedacted() throws {
            let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: Self.secretScalar)
            assertRedacted(privateKey, secretBytes: Self.secretScalar)
        }
    #endif

    #if Xcode || ENABLE_MODULE_RECOVERY
        @Test("Recovery.PrivateKey renderings omit the secret scalar")
        func recoveryPrivateKeyRendersRedacted() throws {
            let privateKey = try P256K.Recovery.PrivateKey(dataRepresentation: Self.secretScalar)
            assertRedacted(privateKey, secretBytes: Self.secretScalar)
        }
    #endif
}
