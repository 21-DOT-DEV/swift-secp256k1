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

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// Internal backing implementation for a secp256k1 x-only public key (BIP-340), storing the 32-byte X coordinate, key parity, and an optional MuSig2 aggregation cache.
///
/// An x-only public key encodes a curve point whose Y coordinate is even. It is serialized as
/// only its 32-byte X coordinate. The `keyParity` value records whether the full public key's Y
/// coordinate required negation to produce the even-Y form, which is needed for certain Taproot
/// tweaking operations.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
@usableFromInline struct XonlyKeyImplementation: Sendable {
    /// The 32-byte X coordinate of the x-only public key, as output by `secp256k1_xonly_pubkey_serialize`.
    @usableFromInline let bytes: [UInt8]

    /// Parity of the original public key's Y coordinate before x-only conversion: 0 if Y was even, 1 if Y was odd (negated). Returned by `secp256k1_xonly_pubkey_from_pubkey`.
    @usableFromInline let keyParity: Int32

    /// Serialized MuSig2 public key aggregation cache. Empty for non-aggregated keys.
    @usableFromInline let cache: [UInt8]

    /// The 32-byte X coordinate as `Data`.
    @usableFromInline var dataRepresentation: Data {
        Data(bytes)
    }

    /// The `secp256k1_xonly_pubkey` struct populated from `bytes` via direct memory copy.
    var rawRepresentation: secp256k1_xonly_pubkey {
        var xonlyKey = secp256k1_xonly_pubkey()
        dataRepresentation.copyToUnsafeMutableBytes(of: &xonlyKey.data)
        return xonlyKey
    }

    /// Backing initialization that generates a x-only public key from a raw representation.
    /// - Parameter data: A data representation of the key.
    @usableFromInline init<D: ContiguousBytes>(
        dataRepresentation data: D,
        keyParity: Int32,
        cache: [UInt8] = []
    ) {
        self.bytes = data.bytes
        self.keyParity = keyParity
        self.cache = cache.bytes
    }

    /// Backing initialization that sets the public key from a x-only public key object.
    /// - Parameter bytes: a x-only public key in byte form
    @usableFromInline init(
        _ bytes: [UInt8],
        keyParity: Int32,
        cache: [UInt8]
    ) {
        self.bytes = bytes
        self.keyParity = keyParity
        self.cache = cache
    }

    /// Derives the 32-byte x-only public key from serialized public key bytes using `secp256k1_ec_pubkey_parse`, `secp256k1_xonly_pubkey_from_pubkey`, and `secp256k1_xonly_pubkey_serialize`.
    /// - Parameter publicBytes: Serialized public key bytes whose count must match `format.length`.
    /// - Parameter keyParity: Updated with 0 if the Y coordinate is even, 1 if odd.
    /// - Parameter format: The serialization format of `publicBytes`.
    /// - Returns: The 32-byte x-only public key (X coordinate).
    /// - Throws: ``secp256k1Error/incorrectKeySize`` if byte count does not match `format.length`; ``secp256k1Error/underlyingCryptoError`` if key derivation fails.
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

        guard secp256k1_ec_pubkey_parse(context, &pubKey, publicBytes, format.length).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return xonlyBytes
    }
}
