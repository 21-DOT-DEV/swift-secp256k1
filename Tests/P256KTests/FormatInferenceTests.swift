//
//  FormatInferenceTests.swift
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

/// Spec 005 (T005–T007) — `P256K.Format.inferred(serializedPublicKeyCount:)`
/// maps a serialized public-key byte count to its format: 33 → `.compressed`,
/// 65 → `.uncompressed`, and throws `incorrectKeySize` for anything else.
/// `init(dataRepresentation:)` applies that inference end-to-end: accepting
/// both SEC1 lengths, canonicalizing the legacy hybrid `0x06`/`0x07` encodings
/// the upstream parser tolerates at 65 bytes, and rejecting every other count
/// with the same `incorrectKeySize` the explicit `count == format.length`
/// check produced on the `format:`-labeled initializers it replaced.
struct FormatInferenceTestSuite {
    /// The secp256k1 base point `G` in three encodings: canonical compressed
    /// (`0x02` — its Y is even), canonical uncompressed (`0x04`), and the
    /// legacy hybrid form (`0x06` — uncompressed X‖Y carrying the same
    /// even-Y parity bit). All three encode the identical point; upstream's
    /// `secp256k1_eckey_pubkey_parse` accepts each.
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

    /// The negated base point `−G`: same X coordinate, Y = `p − G.y` — odd,
    /// so its consistent hybrid tag is `0x07` (the even-Y case covered by
    /// `generatorHybridEven` uses `0x06`).
    private static let negGeneratorY: [UInt8] = [
        0xB7, 0xC5, 0x25, 0x88, 0xD9, 0x5C, 0x3B, 0x9A, 0xA2, 0x5B, 0x04, 0x03, 0xF1, 0xEE, 0xF7, 0x57,
        0x02, 0xE8, 0x4B, 0xB7, 0x59, 0x7A, 0xAB, 0xE6, 0x63, 0xB8, 0x2F, 0x6F, 0x04, 0xEF, 0x27, 0x77
    ]
    private static let negGeneratorUncompressed = [0x04] + generatorX + negGeneratorY
    private static let negGeneratorHybridOdd = [0x07] + generatorX + negGeneratorY

    /// The two SEC1 lengths `secp256k1_ec_pubkey_parse` accepts map to their formats.
    @Test("33 bytes infers .compressed, 65 bytes infers .uncompressed")
    func infersFormatsFromSec1Lengths() throws {
        #expect(try P256K.Format.inferred(serializedPublicKeyCount: 33) == .compressed)
        #expect(try P256K.Format.inferred(serializedPublicKeyCount: 65) == .uncompressed)
    }

    /// Every other count — zero, negative, the 32-byte x-only / private-key
    /// length, and off-by-one neighbors of the two valid lengths — throws
    /// `incorrectKeySize`.
    @Test("Non-SEC1 counts throw incorrectKeySize", arguments: [-1, 0, 1, 32, 34, 64, 66, 128])
    func rejectsNonSec1Counts(count: Int) {
        #expect(throws: secp256k1Error.incorrectKeySize) {
            try P256K.Format.inferred(serializedPublicKeyCount: count)
        }
    }

    /// The inference is wired through the public initializer, not just the
    /// internal helper: 33 bytes constructs a `.compressed`-storing key that
    /// echoes those bytes back, 65 bytes a `.uncompressed`-storing one.
    @Test("init(dataRepresentation:) infers format from byte count")
    func initInfersFormatFromCount() throws {
        let compressed = try P256K.Signing.PublicKey(dataRepresentation: Self.generatorCompressed)
        #expect(compressed.format == .compressed)
        #expect(compressed.dataRepresentation == Data(Self.generatorCompressed))

        let uncompressed = try P256K.Signing.PublicKey(dataRepresentation: Self.generatorUncompressed)
        #expect(uncompressed.format == .uncompressed)
        #expect(uncompressed.dataRepresentation == Data(Self.generatorUncompressed))
    }

    /// Other lengths never reach the parser — the same `incorrectKeySize`
    /// `Format.inferred` reports, surfaced through the public init.
    @Test(
        "init(dataRepresentation:) rejects non-SEC1 lengths",
        arguments: [0, 1, 32, 34, 64, 66, 128]
    )
    func initRejectsNonSec1Lengths(count: Int) {
        #expect(throws: secp256k1Error.incorrectKeySize) {
            try P256K.Signing.PublicKey(dataRepresentation: [UInt8](repeating: 0x02, count: count))
        }
    }

    /// A hybrid `0x06` encoding is parse-time tolerance, not a stored form:
    /// the tag is consumed by `secp256k1_ec_pubkey_parse` and the stored point
    /// reserializes canonically, so every accessor — `dataRepresentation`,
    /// `uncompressedRepresentation`, `xonly` — is byte-identical to the same
    /// point ingested as `0x04`.
    @Test("Hybrid 0x06 input canonicalizes to 0x04")
    func hybridInputCanonicalizes() throws {
        let hybrid = try P256K.Signing.PublicKey(dataRepresentation: Self.generatorHybridEven)
        let canonical = try P256K.Signing.PublicKey(dataRepresentation: Self.generatorUncompressed)

        #expect(hybrid.format == .uncompressed)
        #expect(hybrid.dataRepresentation == Data(Self.generatorUncompressed))
        #expect(hybrid.dataRepresentation == canonical.dataRepresentation)
        #expect(hybrid.uncompressedRepresentation == canonical.uncompressedRepresentation)
        #expect(hybrid.xonly.dataRepresentation == canonical.xonly.dataRepresentation)
    }

    /// The other parity branch: a `0x07` hybrid on an odd-Y point (`−G`) is
    /// likewise accepted and canonicalized — the parser's parity check is a
    /// consistency gate, not a `0x06`-only admission.
    @Test("Hybrid 0x07 input canonicalizes to 0x04")
    func hybridOddInputCanonicalizes() throws {
        let hybrid = try P256K.Signing.PublicKey(dataRepresentation: Self.negGeneratorHybridOdd)
        let canonical = try P256K.Signing.PublicKey(dataRepresentation: Self.negGeneratorUncompressed)

        #expect(hybrid.format == .uncompressed)
        #expect(hybrid.dataRepresentation == Data(Self.negGeneratorUncompressed))
        #expect(hybrid.dataRepresentation == canonical.dataRepresentation)
        #expect(hybrid.uncompressedRepresentation == canonical.uncompressedRepresentation)
        #expect(hybrid.xonly.dataRepresentation == canonical.xonly.dataRepresentation)
    }

    /// A hybrid tag whose parity bit contradicts the Y coordinate fails
    /// upstream's consistency check (`secp256k1_eckey_pubkey_parse`), surfacing
    /// as `underlyingCryptoError` — a parse failure, not a size failure.
    /// `G`'s Y is even, so `0x07` mislabels it.
    @Test("Parity-inconsistent hybrid tag throws underlyingCryptoError")
    func inconsistentHybridThrows() {
        var mislabeled = Self.generatorHybridEven
        mislabeled[0] = 0x07
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            try P256K.Signing.PublicKey(dataRepresentation: mislabeled)
        }
    }

    /// A count that matches an SEC1 length but encodes garbage passes the
    /// count check and fails inside `secp256k1_ec_pubkey_parse` instead —
    /// `underlyingCryptoError`, a different error class than the size check's,
    /// keeping the two failure modes distinguishable at the API boundary.
    @Test("Valid-length unparseable bytes throw underlyingCryptoError")
    func validLengthGarbageThrowsUnderlyingCryptoError() {
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            try P256K.Signing.PublicKey(
                dataRepresentation: [UInt8](repeating: 0xFF, count: P256K.Format.compressed.length)
            )
        }
    }

    // All four public-key types route byte-ingest through the same
    // canonicalizing path — proven per type so wiring can't drift between
    // modules: 33/65 accepted, hybrid ingested to the canonical `0x04` form.
    #if Xcode || ENABLE_MODULE_SCHNORRSIG
        @Test("Schnorr inferred init accepts both lengths and canonicalizes hybrid")
        func schnorrInferredInit() throws {
            let compressed = try P256K.Schnorr.PublicKey(dataRepresentation: Self.generatorCompressed)
            #expect(compressed.format == .compressed)
            #expect(compressed.dataRepresentation == Data(Self.generatorCompressed))

            let hybrid = try P256K.Schnorr.PublicKey(dataRepresentation: Self.generatorHybridEven)
            #expect(hybrid.format == .uncompressed)
            #expect(hybrid.dataRepresentation == Data(Self.generatorUncompressed))
        }
    #endif

    #if Xcode || ENABLE_MODULE_MUSIG
        @Test("MuSig inferred init accepts both lengths and canonicalizes hybrid")
        func musigInferredInit() throws {
            let compressed = try P256K.MuSig.PublicKey(dataRepresentation: Self.generatorCompressed)
            #expect(compressed.format == .compressed)
            #expect(compressed.dataRepresentation == Data(Self.generatorCompressed))

            let hybrid = try P256K.MuSig.PublicKey(dataRepresentation: Self.generatorHybridEven)
            #expect(hybrid.format == .uncompressed)
            #expect(hybrid.dataRepresentation == Data(Self.generatorUncompressed))
        }
    #endif

    #if Xcode || ENABLE_MODULE_ECDH
        @Test("KeyAgreement inferred init accepts both lengths and canonicalizes hybrid")
        func keyAgreementInferredInit() throws {
            let compressed = try P256K.KeyAgreement.PublicKey(dataRepresentation: Self.generatorCompressed)
            #expect(compressed.dataRepresentation == Data(Self.generatorCompressed))

            let hybrid = try P256K.KeyAgreement.PublicKey(dataRepresentation: Self.generatorHybridEven)
            #expect(hybrid.dataRepresentation == Data(Self.generatorUncompressed))
        }
    #endif
}
