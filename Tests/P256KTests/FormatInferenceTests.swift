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

/// Spec 005 (T005) — `P256K.Format.inferred(serializedPublicKeyCount:)` maps a
/// serialized public-key byte count to its format: 33 → `.compressed`,
/// 65 → `.uncompressed`, and throws `incorrectKeySize` for anything else —
/// the same error the explicit `count == format.length` check produced on the
/// `format:`-labeled initializers the inferred `init(dataRepresentation:)`
/// replaces.
struct FormatInferenceTestSuite {
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

    /// A byte count that disagrees with the `format:` label is rejected by the
    /// count check inside `init(dataRepresentation:format:)`
    /// (`XonlyKeyImplementation.generate`) before the buffer ever reaches the
    /// parser — `incorrectKeySize`, the same error class `inferred` reports.
    /// Jury-flagged coverage; the deprecated shim preserves this contract.
    /// Content is irrelevant here — the count check fires first.
    @Test(
        "Count disagrees with format label throws incorrectKeySize",
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

    /// A count that *does* match its label passes the count check and fails
    /// inside `secp256k1_ec_pubkey_parse` instead — `underlyingCryptoError`, a
    /// different error class than the size check's, keeping the two failure
    /// modes distinguishable at the API boundary.
    @Test("Valid-length unparseable bytes throw underlyingCryptoError")
    func validLengthGarbageThrowsUnderlyingCryptoError() {
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            try P256K.Signing.PublicKey(
                dataRepresentation: [UInt8](repeating: 0xFF, count: P256K.Format.compressed.length),
                format: .compressed
            )
        }
    }
}
