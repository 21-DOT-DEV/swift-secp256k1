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
    /// Creates a new ``PrivateKey`` by computing `secret_key' = (secret_key + tweak) mod n` via `secp256k1_ec_seckey_tweak_add`, where `n` is the secp256k1 curve order.
    ///
    /// - Parameter tweak: A 32-byte tweak scalar; must not produce a result that is zero modulo `n`.
    /// - Returns: A new ``PrivateKey`` with the tweaked secret scalar.
    /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or the result is zero modulo `n`.
    func add(_ tweak: [UInt8]) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var privateBytes = key.bytes

        guard secp256k1_ec_seckey_tweak_add(context, &privateBytes, tweak).boolValue,
              secp256k1_ec_seckey_verify(context, privateBytes).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(baseKey: PrivateKeyImplementation(validatedBytes: privateBytes, format: .compressed))
    }

    /// Creates a new ``PrivateKey`` by computing `secret_key' = (secret_key × tweak) mod n` via `secp256k1_ec_seckey_tweak_mul`, where `n` is the secp256k1 curve order.
    ///
    /// - Parameter tweak: A 32-byte tweak scalar; must be non-zero and less than `n`.
    /// - Returns: A new ``PrivateKey`` with the scaled secret scalar.
    /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or the result fails `secp256k1_ec_seckey_verify`.
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
    /// Creates a new ``PublicKey`` by computing `public_key' = public_key + G × tweak` via `secp256k1_ec_pubkey_tweak_add`, where `G` is the secp256k1 generator point.
    ///
    /// - Parameter tweak: A 32-byte tweak scalar; must not produce the point at infinity.
    /// - Parameter format: The serialization format of the returned ``PublicKey``; defaults to `.compressed`.
    /// - Returns: A new ``PublicKey`` equal to the original key plus the tweak times the generator.
    /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or the result is the point at infinity.
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

    /// Creates a new ``PublicKey`` by computing `public_key' = public_key × tweak` via `secp256k1_ec_pubkey_tweak_mul`.
    ///
    /// - Parameter tweak: A 32-byte tweak scalar; must be non-zero.
    /// - Parameter format: The serialization format of the returned ``PublicKey``; defaults to `.compressed`.
    /// - Returns: A new ``PublicKey`` equal to the original key multiplied by the tweak scalar.
    /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or the result is the point at infinity.
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
