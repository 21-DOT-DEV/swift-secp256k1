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
    func tweak(_ tweak: [UInt8]) throws -> Self {
        var keypair = secp256k1_keypair()
        var privateBytes = [UInt8](repeating: 0, count: secp256k1.ByteDetails.count)

        guard secp256k1_keypair_create(secp256k1.Context.raw, &keypair, key.bytes).boolValue,
              secp256k1_keypair_xonly_tweak_add(secp256k1.Context.raw, &keypair, tweak).boolValue,
              secp256k1_keypair_sec(secp256k1.Context.raw, &privateBytes, &keypair).boolValue else {
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
    func tweak(_ tweak: [UInt8], format: secp256k1.Format = .compressed) throws -> Self {
        var xonlyPubKey = secp256k1_xonly_pubkey()
        var pubKey = secp256k1_pubkey()
        var pubKeyLen = format.length
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var xonlyPubKeyOutput = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.Schnorr.xonlyByteCount)
        var keyParity = Int32()

        guard secp256k1_xonly_pubkey_parse(secp256k1.Context.raw, &xonlyPubKey, xonly.bytes).boolValue,
              secp256k1_xonly_pubkey_tweak_add(secp256k1.Context.raw, &pubKey, &xonlyPubKey, tweak).boolValue,
              secp256k1_ec_pubkey_serialize(secp256k1.Context.raw, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(secp256k1.Context.raw, &xonlyPubKeyOutput, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(secp256k1.Context.raw, &xonlyBytes, &xonlyPubKeyOutput).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(rawRepresentation: pubBytes, xonly: xonlyBytes, format: format)
    }
}
