//
//  Tweak.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    @_implementationOnly import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    @_implementationOnly import libsecp256k1
#endif

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

        return try Self(dataRepresentation: privateBytes)
    }

    /// Create a new `PrivateKey` by adding tweak to the secret key. When tweaking x-only keys,
    /// the implicit negations are handled when odd Y coordinates are reached.
    /// [REF](https://github.com/bitcoin-core/secp256k1/issues/1021#issuecomment-983021759)
    /// - Parameter tweak: the 32-byte tweak object
    /// - Returns: tweaked `PrivateKey` object
    func add(xonly tweak: [UInt8]) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var keypair = secp256k1_keypair()
        var privateBytes = [UInt8](repeating: 0, count: P256K.ByteLength.privateKey)
        var xonly = secp256k1_xonly_pubkey()
        var keyParity = Int32()

        guard secp256k1_keypair_create(context, &keypair, key.bytes).boolValue,
              secp256k1_keypair_xonly_tweak_add(context, &keypair, tweak).boolValue,
              secp256k1_keypair_sec(context, &privateBytes, &keypair).boolValue,
              secp256k1_keypair_xonly_pub(context, &xonly, &keyParity, &keypair).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(dataRepresentation: privateBytes)
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

        return try Self(dataRepresentation: privateBytes)
    }
}

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

        return try Self(dataRepresentation: pubKeyBytes, format: format)
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

        return try Self(dataRepresentation: pubKeyBytes, format: format)
    }
}

public extension P256K.Schnorr.XonlyKey {
    /// Create a new `XonlyKey` by adding tweak to the x-only public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `XonlyKey` object
    /// - Returns: tweaked `PublicKey` object
    func add(_ tweak: [UInt8]) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var inXonlyPubKey = secp256k1_xonly_pubkey()
        var outXonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: P256K.ByteLength.dimension)
        var keyParity = Int32()

        guard secp256k1_xonly_pubkey_parse(context, &inXonlyPubKey, bytes).boolValue,
              secp256k1_xonly_pubkey_tweak_add(context, &pubKey, &inXonlyPubKey, tweak).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(context, &outXonlyPubKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &outXonlyPubKey).boolValue,
              secp256k1_xonly_pubkey_tweak_add_check(context, &xonlyBytes, keyParity, &inXonlyPubKey, tweak).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(dataRepresentation: xonlyBytes, keyParity: keyParity)
    }
}
