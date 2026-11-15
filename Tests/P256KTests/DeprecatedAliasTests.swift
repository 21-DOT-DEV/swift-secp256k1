//
//  DeprecatedAliasTests.swift
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

/// Equivalence pins for the `@available(*, deprecated, renamed:)` forwarders —
/// the old names must keep returning the same value, in their old shape, until
/// removal at 1.0. Upstream's own harness keeps the identical check ("Check that
/// deprecated alias gives the same result", `modules/schnorrsig/tests_impl.h`).
/// Each test is marked `@available(*, deprecated)` so exercising the aliases
/// emits no warnings; delete this suite with the aliases at 1.0.
struct DeprecatedAliasTestSuite {
    /// `P256K.Signing.XonlyKey.bytes` forwards to `dataRepresentation` as `[UInt8]`.
    @available(*, deprecated)
    @Test("Signing.XonlyKey.bytes returns dataRepresentation as [UInt8]")
    func signingXonlyBytesAlias() throws {
        let xonly = try P256K.Signing.PrivateKey().publicKey.xonly
        #expect(xonly.bytes == Array(xonly.dataRepresentation))
    }

    #if Xcode || ENABLE_MODULE_SCHNORRSIG
        /// `P256K.Schnorr.XonlyKey.bytes` forwards to `dataRepresentation` as `[UInt8]`.
        @available(*, deprecated)
        @Test("Schnorr.XonlyKey.bytes returns dataRepresentation as [UInt8]")
        func schnorrXonlyBytesAlias() throws {
            let xonly = try P256K.Schnorr.PrivateKey().xonly
            #expect(xonly.bytes == Array(xonly.dataRepresentation))
        }
    #endif

    #if Xcode || ENABLE_MODULE_MUSIG
        /// `P256K.MuSig.XonlyKey.bytes` forwards to `dataRepresentation` as `[UInt8]`.
        @available(*, deprecated)
        @Test("MuSig.XonlyKey.bytes returns dataRepresentation as [UInt8]")
        func musigXonlyBytesAlias() throws {
            let xonly = try P256K.MuSig.aggregate([P256K.Schnorr.PrivateKey().publicKey]).xonly
            #expect(xonly.bytes == Array(xonly.dataRepresentation))
        }
    #endif

    #if Xcode || ENABLE_MODULE_RECOVERY
        /// `P256K.Recovery.ECDSASignature.normalize` forwards to `signature` —
        /// the same standard-form signature, never low-S-normalized.
        @available(*, deprecated)
        @Test("ECDSASignature.normalize returns the same signature")
        func recoveryNormalizeAlias() throws {
            let recoverable = try P256K.Recovery.PrivateKey().signature(for: Data("deprecated alias".utf8))
            #expect(recoverable.normalize.dataRepresentation == recoverable.signature.dataRepresentation)
        }
    #endif

    /// The secp256k1 base point `G`: canonical compressed (`0x02`), canonical
    /// uncompressed (`0x04`), and legacy hybrid (`0x06`) — three encodings of
    /// the identical point, all accepted by `secp256k1_eckey_pubkey_parse`.
    private static let generatorX: [UInt8] = [
        0x79, 0xBE, 0x66, 0x7E, 0xF9, 0xDC, 0xBB, 0xAC, 0x55, 0xA0, 0x62, 0x95, 0xCE, 0x87, 0x0B, 0x07,
        0x02, 0x9B, 0xFC, 0xDB, 0x2D, 0xCE, 0x28, 0xD9, 0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98
    ]
    private static let generatorY: [UInt8] = [
        0x48, 0x3A, 0xDA, 0x77, 0x26, 0xA3, 0xC4, 0x65, 0x5D, 0xA4, 0xFB, 0xFC, 0x0E, 0x11, 0x08, 0xA8,
        0xFD, 0x17, 0xB4, 0x48, 0xA6, 0x85, 0x54, 0x19, 0x9C, 0x47, 0xD0, 0x8F, 0xFB, 0x10, 0xD4, 0xB8
    ]
    private static let generatorCompressed = [0x02] + generatorX
    private static let generatorUncompressed = [0x04] + generatorX + generatorY
    private static let generatorHybridEven = [0x06] + generatorX + generatorY

    /// Spec 005 (T007) — the deprecated `init(dataRepresentation:format:)`
    /// verifies the label agrees with the byte count, then forwards to
    /// `init(dataRepresentation:)`: every accepted input — both SEC1 lengths
    /// and the hybrid `0x06` form — produces a key byte-identical to what the
    /// inferred init builds, including the canonical `0x04` reserialization.
    @available(*, deprecated)
    @Test("Deprecated Signing init matches inferred init byte-for-byte")
    func signingDeprecatedInitParity() throws {
        for (bytes, format) in [
            (Self.generatorCompressed, P256K.Format.compressed),
            (Self.generatorUncompressed, P256K.Format.uncompressed),
            (Self.generatorHybridEven, P256K.Format.uncompressed)
        ] {
            let viaLabel = try P256K.Signing.PublicKey(dataRepresentation: bytes, format: format)
            let viaInferred = try P256K.Signing.PublicKey(dataRepresentation: bytes)
            #expect(viaLabel.dataRepresentation == viaInferred.dataRepresentation)
            #expect(viaLabel.format == viaInferred.format)
            #expect(viaLabel.xonly.dataRepresentation == viaInferred.xonly.dataRepresentation)
        }
    }

    /// A byte count that disagrees with the `format:` label is rejected by the
    /// shim's `count == format.length` check before inference runs —
    /// `incorrectKeySize`, the same error class the pre-deprecation count
    /// check produced. Content is irrelevant here; the count check fires first.
    @available(*, deprecated)
    @Test(
        "Deprecated init throws incorrectKeySize when count disagrees with label",
        arguments: [
            (count: 33, format: P256K.Format.uncompressed),
            (count: 65, format: P256K.Format.compressed),
            (count: 64, format: P256K.Format.compressed),
            (count: 32, format: P256K.Format.uncompressed)
        ]
    )
    func mismatchedCountAndLabelThrows(count: Int, format: P256K.Format) {
        #expect(throws: secp256k1Error.incorrectKeySize) {
            try P256K.Signing.PublicKey(
                dataRepresentation: [UInt8](repeating: 0x02, count: count),
                format: format
            )
        }
    }

    #if Xcode || ENABLE_MODULE_SCHNORRSIG
        @available(*, deprecated)
        @Test("Deprecated Schnorr init matches inferred init byte-for-byte")
        func schnorrDeprecatedInitParity() throws {
            for (bytes, format) in [
                (Self.generatorCompressed, P256K.Format.compressed),
                (Self.generatorUncompressed, P256K.Format.uncompressed),
                (Self.generatorHybridEven, P256K.Format.uncompressed)
            ] {
                let viaLabel = try P256K.Schnorr.PublicKey(dataRepresentation: bytes, format: format)
                let viaInferred = try P256K.Schnorr.PublicKey(dataRepresentation: bytes)
                #expect(viaLabel.dataRepresentation == viaInferred.dataRepresentation)
                #expect(viaLabel.format == viaInferred.format)
            }
        }

        /// The shim's `count == format.length` check must exist on this shim
        /// too: a valid SEC1 count under the wrong label would otherwise pass
        /// inference and silently store the mismatched format.
        @available(*, deprecated)
        @Test(
            "Deprecated Schnorr init throws incorrectKeySize when count disagrees with label",
            arguments: [
                (count: 33, format: P256K.Format.uncompressed),
                (count: 65, format: P256K.Format.compressed)
            ]
        )
        func schnorrMismatchedCountAndLabelThrows(count: Int, format: P256K.Format) {
            #expect(throws: secp256k1Error.incorrectKeySize) {
                try P256K.Schnorr.PublicKey(
                    dataRepresentation: [UInt8](repeating: 0x02, count: count),
                    format: format
                )
            }
        }
    #endif

    #if Xcode || ENABLE_MODULE_MUSIG
        @available(*, deprecated)
        @Test("Deprecated MuSig init matches inferred init byte-for-byte")
        func musigDeprecatedInitParity() throws {
            for (bytes, format) in [
                (Self.generatorCompressed, P256K.Format.compressed),
                (Self.generatorUncompressed, P256K.Format.uncompressed),
                (Self.generatorHybridEven, P256K.Format.uncompressed)
            ] {
                let viaLabel = try P256K.MuSig.PublicKey(dataRepresentation: bytes, format: format)
                let viaInferred = try P256K.MuSig.PublicKey(dataRepresentation: bytes)
                #expect(viaLabel.dataRepresentation == viaInferred.dataRepresentation)
                #expect(viaLabel.format == viaInferred.format)
            }
        }

        /// The shim's `count == format.length` check must exist on this shim
        /// too: a valid SEC1 count under the wrong label would otherwise pass
        /// inference and silently store the mismatched format.
        @available(*, deprecated)
        @Test(
            "Deprecated MuSig init throws incorrectKeySize when count disagrees with label",
            arguments: [
                (count: 33, format: P256K.Format.uncompressed),
                (count: 65, format: P256K.Format.compressed)
            ]
        )
        func musigMismatchedCountAndLabelThrows(count: Int, format: P256K.Format) {
            #expect(throws: secp256k1Error.incorrectKeySize) {
                try P256K.MuSig.PublicKey(
                    dataRepresentation: [UInt8](repeating: 0x02, count: count),
                    format: format
                )
            }
        }
    #endif

    #if Xcode || ENABLE_MODULE_ECDH
        @available(*, deprecated)
        @Test("Deprecated KeyAgreement init matches inferred init byte-for-byte")
        func keyAgreementDeprecatedInitParity() throws {
            for (bytes, format) in [
                (Self.generatorCompressed, P256K.Format.compressed),
                (Self.generatorUncompressed, P256K.Format.uncompressed),
                (Self.generatorHybridEven, P256K.Format.uncompressed)
            ] {
                let viaLabel = try P256K.KeyAgreement.PublicKey(dataRepresentation: bytes, format: format)
                let viaInferred = try P256K.KeyAgreement.PublicKey(dataRepresentation: bytes)
                #expect(viaLabel.dataRepresentation == viaInferred.dataRepresentation)
            }
        }

        /// The shim's `count == format.length` check must exist on this shim
        /// too: a valid SEC1 count under the wrong label would otherwise pass
        /// inference and silently store the mismatched format.
        @available(*, deprecated)
        @Test(
            "Deprecated KeyAgreement init throws incorrectKeySize when count disagrees with label",
            arguments: [
                (count: 33, format: P256K.Format.uncompressed),
                (count: 65, format: P256K.Format.compressed)
            ]
        )
        func keyAgreementMismatchedCountAndLabelThrows(count: Int, format: P256K.Format) {
            #expect(throws: secp256k1Error.incorrectKeySize) {
                try P256K.KeyAgreement.PublicKey(
                    dataRepresentation: [UInt8](repeating: 0x02, count: count),
                    format: format
                )
            }
        }
    #endif

    /// Spec 005 (T008) — the deprecated `add(_:format:)` / `multiply(_:format:)`
    /// keep their signatures' semantics: `.compressed` is byte-identical to
    /// the new bare overloads, `.uncompressed` still stores a 65-byte key
    /// encoding the same point (the deprecated path remains the only way to
    /// store uncompressed until 1.0).
    @available(*, deprecated)
    @Test("Deprecated Signing tweak overloads match bare calls and preserve stored format")
    func signingTweakAliases() throws {
        let publicKey = try P256K.Signing.PrivateKey().publicKey
        let tweak = [UInt8](repeating: 0x01, count: P256K.ByteLength.dimension)

        let compressedAdd = try publicKey.add(tweak)
        #expect(try publicKey.add(tweak, format: .compressed).dataRepresentation == compressedAdd.dataRepresentation)
        let uncompressedAdd = try publicKey.add(tweak, format: .uncompressed)
        #expect(uncompressedAdd.format == .uncompressed)
        #expect(uncompressedAdd.dataRepresentation == compressedAdd.uncompressedRepresentation)

        let compressedMultiply = try publicKey.multiply(tweak)
        #expect(try publicKey.multiply(tweak, format: .compressed).dataRepresentation == compressedMultiply.dataRepresentation)
        let uncompressedMultiply = try publicKey.multiply(tweak, format: .uncompressed)
        #expect(uncompressedMultiply.format == .uncompressed)
        #expect(uncompressedMultiply.dataRepresentation == compressedMultiply.uncompressedRepresentation)
    }

    #if Xcode || ENABLE_MODULE_MUSIG
        /// Spec 005 (T008) — deprecated `add(_:format:)` keeps its semantics on
        /// the aggregate too: `.compressed` matches the bare overload, `.uncompressed`
        /// still stores a 65-byte key, and the updated key-aggregation cache still
        /// propagates — the uncompressed-stored result accepts a second tweak,
        /// which the bare `add(_:)` then stores compressed.
        @available(*, deprecated)
        @Test("Deprecated MuSig add matches bare call, preserves stored format and cache")
        func musigTweakAlias() throws {
            let aggregate = try P256K.MuSig.aggregate([
                P256K.Schnorr.PrivateKey().publicKey,
                P256K.Schnorr.PrivateKey().publicKey
            ])
            let tweak = [UInt8](repeating: 0x01, count: P256K.ByteLength.dimension)
            let secondTweak = [UInt8](repeating: 0x02, count: P256K.ByteLength.dimension)

            let compressed = try aggregate.add(tweak)
            #expect(try aggregate.add(tweak, format: .compressed).dataRepresentation == compressed.dataRepresentation)
            let uncompressed = try aggregate.add(tweak, format: .uncompressed)
            #expect(uncompressed.format == .uncompressed)
            #expect(uncompressed.dataRepresentation == compressed.uncompressedRepresentation)

            let rechained = try uncompressed.add(secondTweak)
            let expectedRechained = try compressed.add(secondTweak)
            #expect(rechained.format == .compressed)
            #expect(rechained.dataRepresentation == expectedRechained.dataRepresentation)

            // Signing-session checks resolve signers from `participants` — a
            // tweak that dropped the list would silently break later sessions.
            for tweaked in [compressed, uncompressed, rechained] {
                #expect(tweaked.participants.map(\.dataRepresentation) == aggregate.participants.map(\.dataRepresentation))
            }
        }
    #endif
}
