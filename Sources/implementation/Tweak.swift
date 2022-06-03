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
import secp256k1_bindings

public extension secp256k1.Signing.PrivateKey {
    /// Create a new `PrivateKey` by adding tweak to the secret key.
    /// - Parameter tweak: the 32-byte tweak object
    /// - Returns: tweaked `PrivateKey` object
    func add(_ tweak: [UInt8]) throws -> Self {
        var privateBytes = key.bytes

        guard secp256k1_ec_seckey_tweak_add(secp256k1.Context.raw, &privateBytes, tweak).boolValue,
              secp256k1_ec_seckey_verify(secp256k1.Context.raw, privateBytes).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(rawRepresentation: privateBytes)
    }

    /// Create a new `PrivateKey` by adding tweak to the secret key. When tweaking x-only keys,
    /// the implicit negations are handled when odd Y coordinates are reached.
    /// [REF](https://github.com/bitcoin-core/secp256k1/issues/1021#issuecomment-983021759)
    /// - Parameter tweak: the 32-byte tweak object
    /// - Returns: tweaked `PrivateKey` object
    func add(xonly tweak: [UInt8]) throws -> Self {
        var keypair = secp256k1_keypair()
        var privateBytes = [UInt8](repeating: 0, count: secp256k1.ByteDetails.count)
        var xonly = secp256k1_xonly_pubkey()
        var keyParity = Int32()

        guard secp256k1_keypair_create(secp256k1.Context.raw, &keypair, key.bytes).boolValue,
              secp256k1_keypair_xonly_tweak_add(secp256k1.Context.raw, &keypair, tweak).boolValue,
              secp256k1_keypair_sec(secp256k1.Context.raw, &privateBytes, &keypair).boolValue,
              secp256k1_keypair_xonly_pub(secp256k1.Context.raw, &xonly, &keyParity, &keypair).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(rawRepresentation: privateBytes)
    }

    /// Create a new `PrivateKey` by multiplying tweak to the secret key.
    /// - Parameter tweak: the 32-byte tweak object
    /// - Returns: tweaked `PrivateKey` object
    func multiply(_ tweak: [UInt8]) throws -> Self {
        var privateBytes = key.bytes

        guard secp256k1_ec_seckey_tweak_mul(secp256k1.Context.raw, &privateBytes, tweak).boolValue,
              secp256k1_ec_seckey_verify(secp256k1.Context.raw, privateBytes).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(rawRepresentation: privateBytes)
    }
}

public extension secp256k1.Signing.PublicKey {
    /// Create a new `PublicKey` by adding tweak to the public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `PublicKey` object
    /// - Returns: tweaked `PublicKey` object
    func add(_ tweak: [UInt8], format: secp256k1.Format = .compressed) throws -> Self {
        var pubKey = secp256k1_pubkey()
        var pubKeyLen = format.length
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var xonlyKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.Schnorr.xonlyByteCount)
        var keyParity = Int32()

        guard secp256k1_ec_pubkey_parse(secp256k1.Context.raw, &pubKey, bytes, pubKeyLen).boolValue,
              secp256k1_ec_pubkey_tweak_add(secp256k1.Context.raw, &pubKey, tweak).boolValue,
              secp256k1_ec_pubkey_serialize(secp256k1.Context.raw, &pubKeyBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(secp256k1.Context.raw, &xonlyKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(secp256k1.Context.raw, &xonlyBytes, &xonlyKey).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(rawRepresentation: pubKeyBytes, xonly: xonlyBytes, keyParity: keyParity, format: format)
    }

    /// Create a new `PublicKey` by multiplying tweak to the public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `PublicKey` object
    /// - Returns: tweaked `PublicKey` object
    func multiply(_ tweak: [UInt8], format: secp256k1.Format = .compressed) throws -> Self {
        var pubKey = secp256k1_pubkey()
        var pubKeyLen = format.length
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var xonlyKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.Schnorr.xonlyByteCount)
        var keyParity = Int32()

        guard secp256k1_ec_pubkey_parse(secp256k1.Context.raw, &pubKey, bytes, pubKeyLen).boolValue,
              secp256k1_ec_pubkey_tweak_mul(secp256k1.Context.raw, &pubKey, tweak).boolValue,
              secp256k1_ec_pubkey_serialize(secp256k1.Context.raw, &pubKeyBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(secp256k1.Context.raw, &xonlyKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(secp256k1.Context.raw, &xonlyBytes, &xonlyKey).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(rawRepresentation: pubKeyBytes, xonly: xonlyBytes, keyParity: keyParity, format: format)
    }
}

public extension secp256k1.Signing.XonlyKey {
    /// Create a new `XonlyKey` by adding tweak to the x-only public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `XonlyKey` object
    /// - Returns: tweaked `PublicKey` object
    func add(_ tweak: [UInt8]) throws -> Self {
        var pubKey = secp256k1_pubkey()
        var inXonlyPubKey = secp256k1_xonly_pubkey()
        var outXonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.Schnorr.xonlyByteCount)
        var keyParity = Int32()

        guard secp256k1_xonly_pubkey_parse(secp256k1.Context.raw, &inXonlyPubKey, bytes).boolValue,
              secp256k1_xonly_pubkey_tweak_add(secp256k1.Context.raw, &pubKey, &inXonlyPubKey, tweak).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(secp256k1.Context.raw, &outXonlyPubKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(secp256k1.Context.raw, &xonlyBytes, &outXonlyPubKey).boolValue,
              secp256k1_xonly_pubkey_tweak_add_check(secp256k1.Context.raw, &xonlyBytes, keyParity, &inXonlyPubKey, tweak).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(rawRepresentation: xonlyBytes, keyParity: keyParity)
    }
}
