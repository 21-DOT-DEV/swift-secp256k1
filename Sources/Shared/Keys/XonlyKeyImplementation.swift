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
    import SwiftSystem
#else
    #if canImport(FoundationEssentials)
        import FoundationEssentials
    #else
        import Foundation
    #endif
#endif

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// Public X-only public key for Schnorr implementation
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
@usableFromInline struct XonlyKeyImplementation: Sendable {
    /// Implementation x-only public key object
    @usableFromInline let bytes: [UInt8]

    /// Backing key parity object
    @usableFromInline let keyParity: Int32

    /// Backing cache for information about public key aggregation.
    @usableFromInline let cache: [UInt8]

    /// A data representation of the backing x-only public key
    @usableFromInline var dataRepresentation: Data {
        Data(bytes)
    }

    /// A raw representation of the backing x-only public key
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

    /// Create a x-only public key from bytes representation.
    /// - Parameter privateBytes: a private key object in byte form
    /// - Returns: a public key object
    /// - Throws: An error is thrown when the bytes does not create a public key.
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
