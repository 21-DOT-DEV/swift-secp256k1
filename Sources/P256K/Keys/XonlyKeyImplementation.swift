//
//  XonlyKeyImplementation.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
#if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
    public import SwiftSystem
#else
    #if canImport(FoundationEssentials)
        public import FoundationEssentials
    #else
        public import Foundation
    #endif
#endif

import libsecp256k1

/// Internal backing implementation for a secp256k1 x-only public key
/// ([BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)), storing
/// the 32-byte X coordinate, key parity, and an optional MuSig2 aggregation cache.
///
/// ## Overview
///
/// An x-only public key encodes a curve point whose Y coordinate is even. It is
/// serialized as only its 32-byte X coordinate. The `keyParity` value records whether
/// the original full public key's Y coordinate required negation to produce the even-Y
/// form — needed for BIP-341 Taproot tweaking operations
/// ([`secp256k1/include/secp256k1_extrakeys.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_extrakeys.h)).
///
/// Kept `@usableFromInline` so it can back the public Schnorr / ECDH / MuSig / Signing
/// x-only key types across `Sources/P256K/*` without widening the public API surface.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
@usableFromInline struct XonlyKeyImplementation: Sendable {
    /// The 32-byte X coordinate of the x-only public key, as output by
    /// `secp256k1_xonly_pubkey_serialize`.
    ///
    /// Stable wire format suitable for persistence and transmission as a BIP-340-style
    /// key identifier.
    @usableFromInline let bytes: [UInt8]

    /// Parity of the original public key's Y coordinate before x-only conversion:
    /// `0` if Y was even, `1` if Y was odd (negated). Returned by
    /// `secp256k1_xonly_pubkey_from_pubkey`.
    ///
    /// Required to reconstruct the full `(x, y)` point from the x-only form and
    /// consulted during BIP-341 Taproot tweak verification.
    @usableFromInline let keyParity: Int32

    /// Serialized MuSig2 public-key aggregation cache. Empty for non-aggregated keys.
    ///
    /// Holds the 197-byte opaque `secp256k1_musig_keyagg_cache` struct body required
    /// for continued signing / tweaking against this aggregate. Not a stable
    /// serialization format — treat as a within-process session token.
    @usableFromInline let cache: [UInt8]

    /// The 32-byte X coordinate as `Data`.
    @usableFromInline var dataRepresentation: Data {
        Data(bytes)
    }

    /// The `secp256k1_xonly_pubkey` struct populated by `secp256k1_xonly_pubkey_parse`.
    ///
    /// The struct's `data` field holds upstream's internal field-element
    /// encoding, not the serialized coordinate — it must be built through the
    /// parse entry point. `bytes` was validated at initialization, so the parse
    /// is infallible; a failure indicates memory corruption or an upstream
    /// defect (and an all-zero struct would abort inside `xonly_pubkey_load`).
    var rawRepresentation: secp256k1_xonly_pubkey {
        var xonlyKey = secp256k1_xonly_pubkey()
        guard secp256k1_xonly_pubkey_parse(
            P256K.Context.rawRepresentation,
            &xonlyKey,
            bytes
        ).boolValue else {
            P256K.invariantFailure("secp256k1_xonly_pubkey_parse failed on validated key — library bug")
        }
        return xonlyKey
    }

    /// Backing initialization that generates a x-only public key from a raw representation.
    ///
    /// Validates that the coordinate is exactly 32 bytes and lifts to a curve point via
    /// `secp256k1_xonly_pubkey_parse`, so an `XonlyKeyImplementation` always holds
    /// parseable key bytes — downstream `xonly_pubkey_parse`/`xonly_pubkey_tweak_add`
    /// calls can rely on that invariant.
    /// - Parameter data: A data representation of the key.
    /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not exactly 32 bytes;
    ///   ``secp256k1Error/underlyingCryptoError`` if the X coordinate fails
    ///   `secp256k1_xonly_pubkey_parse` (out of range or no curve point).
    @usableFromInline init<D: ContiguousBytes>(
        dataRepresentation data: D,
        keyParity: Int32,
        cache: [UInt8] = []
    ) throws {
        let bytes = data.bytes
        var xonlyKey = secp256k1_xonly_pubkey()

        // Upstream reads exactly 32 bytes from the input pointer.
        guard bytes.count == P256K.ByteLength.dimension else {
            throw secp256k1Error.incorrectKeySize
        }

        guard secp256k1_xonly_pubkey_parse(
            P256K.Context.rawRepresentation,
            &xonlyKey,
            bytes
        ).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        // A non-empty cache must be a complete `secp256k1_musig_keyagg_cache`
        // blob: upstream checks its 4-byte magic inside `ARG_CHECK` on every
        // `keyagg_cache_load`, which aborts the process on mismatch.
        if cache.isEmpty == false {
            guard cache.count == MuSigOpaqueState.keyAggregationCacheByteCount else {
                throw secp256k1Error.incorrectParameterSize
            }
            guard MuSigOpaqueState.isValidKeyAggregationCache(cache) else {
                throw secp256k1Error.underlyingCryptoError
            }
        }

        self.bytes = bytes
        self.keyParity = keyParity
        self.cache = cache.bytes
    }

    /// Non-throwing initialization for bytes already proven valid by a
    /// libsecp256k1 operation (e.g. `secp256k1_xonly_pubkey_serialize` output).
    ///
    /// Asserts the invariant rather than throwing — matching
    /// ``PrivateKeyImplementation/init(validatedBytes:format:)``: internal callers
    /// pass upstream-produced bytes only, so an assertion failure means an
    /// internal bug, not public input.
    @usableFromInline init(
        validatedBytes bytes: [UInt8],
        keyParity: Int32,
        cache: [UInt8]
    ) {
        precondition(bytes.count == P256K.ByteLength.dimension, "Invalid x-only key size")
        precondition(
            cache.isEmpty || cache.count == MuSigOpaqueState.keyAggregationCacheByteCount,
            "Invalid key aggregation cache size"
        )

        // `bytes` are produced by upstream serialization or an already-validated
        // key, so a parse failure indicates an internal bug; the check runs in
        // debug builds only to keep `.xonly` accessors off the hot path.
        assert(
            { () -> Bool in
                var xonlyKey = secp256k1_xonly_pubkey()
                return secp256k1_xonly_pubkey_parse(
                    P256K.Context.rawRepresentation,
                    &xonlyKey,
                    bytes
                ).boolValue
            }(),
            "validatedBytes failed x-only parse — internal bug"
        )

        self.bytes = bytes
        self.keyParity = keyParity
        self.cache = cache
    }

    /// Derives the 32-byte x-only public key from serialized public key bytes using `secp256k1_ec_pubkey_parse`, `secp256k1_xonly_pubkey_from_pubkey`, and `secp256k1_xonly_pubkey_serialize`.
    /// - Parameter publicBytes: Serialized public key bytes whose count must match `format.length`.
    /// - Parameter keyParity: Updated with 0 if the Y coordinate is even, 1 if odd.
    /// - Parameter format: The serialization format of `publicBytes`.
    /// - Returns: The 32-byte x-only public key (X coordinate).
    /// - Throws: ``secp256k1Error/incorrectKeySize`` if byte count does not match `format.length`; ``secp256k1Error/underlyingCryptoError`` if `publicBytes` fails public-key parsing.
    static func generate(
        bytes publicBytes: [UInt8],
        keyParity: inout Int32,
        format: P256K.Format
    ) throws -> [UInt8] {
        guard publicBytes.count == format.length else {
            throw secp256k1Error.incorrectKeySize
        }

        let context = P256K.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var xonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: P256K.ByteLength.privateKey)

        // `publicBytes` is caller-supplied, so the parse can legitimately fail.
        guard secp256k1_ec_pubkey_parse(context, &pubKey, publicBytes, format.length).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }
        guard secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubKey, &keyParity, &pubKey).boolValue else {
            P256K.invariantFailure("secp256k1_xonly_pubkey_from_pubkey failed on parsed key — library bug")
        }
        guard secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey).boolValue else {
            P256K.invariantFailure("secp256k1_xonly_pubkey_serialize failed on derived key — library bug")
        }

        return xonlyBytes
    }
}
