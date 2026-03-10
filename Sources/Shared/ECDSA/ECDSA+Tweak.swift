//
//  ECDSA+Tweak.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing.PrivateKey {
    /// Create a new `PrivateKey` by adding tweak to the secret key.
    /// - Parameter tweak: the 32-byte tweak object
    /// - Returns: tweaked `PrivateKey` object
    func add(_ tweak: [UInt8]) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var privateBytes = key.bytes

        guard secp256k1_ec_seckey_tweak_add(context, &privateBytes, tweak).boolValue,
              secp256k1_ec_seckey_verify(context, privateBytes).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(baseKey: PrivateKeyImplementation(validatedBytes: privateBytes, format: .compressed))
    }

    /// Create a new `PrivateKey` by multiplying tweak to the secret key.
    /// - Parameter tweak: the 32-byte tweak object
    /// - Returns: tweaked `PrivateKey` object
    func multiply(_ tweak: [UInt8]) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var privateBytes = key.bytes

        guard secp256k1_ec_seckey_tweak_mul(context, &privateBytes, tweak).boolValue,
              secp256k1_ec_seckey_verify(context, privateBytes).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(baseKey: PrivateKeyImplementation(validatedBytes: privateBytes, format: .compressed))
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing.PublicKey {
    /// Create a new `PublicKey` by adding tweak to the public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `PublicKey` object
    /// - Returns: tweaked `PublicKey` object
    func add(_ tweak: [UInt8], format: P256K.Format = .compressed) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var pubKey = baseKey.rawRepresentation
        var pubKeyLen = format.length
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard secp256k1_ec_pubkey_tweak_add(context, &pubKey, tweak).boolValue,
              secp256k1_ec_pubkey_serialize(context, &pubKeyBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(baseKey: PublicKeyImplementation(validatedBytes: pubKeyBytes, format: format))
    }

    /// Create a new `PublicKey` by multiplying tweak to the public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `PublicKey` object
    /// - Returns: tweaked `PublicKey` object
    func multiply(_ tweak: [UInt8], format: P256K.Format = .compressed) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var pubKey = baseKey.rawRepresentation
        var pubKeyLen = format.length
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard secp256k1_ec_pubkey_tweak_mul(context, &pubKey, tweak).boolValue,
              secp256k1_ec_pubkey_serialize(context, &pubKeyBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(baseKey: PublicKeyImplementation(validatedBytes: pubKeyBytes, format: format))
    }
}
