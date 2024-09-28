//
//  MuSig.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2024 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

public extension secp256k1.Schnorr {
    /// The corresponding public key for the secp256k1 curve.
    struct PublicKey {
        /// Generated secp256k1 public key.
        private let baseKey: PublicKeyImplementation

        /// The secp256k1 public key object.
        var bytes: [UInt8] {
            baseKey.bytes
        }

        /// The cache of information about public key aggregation.
        var cache: Data {
            Data(baseKey.cache)
        }

        /// The key format representation of the public key.
        public var format: secp256k1.Format {
            baseKey.format
        }

        /// A data representation of the public key.
        public var dataRepresentation: Data {
            baseKey.dataRepresentation
        }

        /// The associated x-only public key for verifying Schnorr signatures.
        ///
        /// - Returns: The associated x-only public key.
        public var xonly: XonlyKey {
            XonlyKey(baseKey: baseKey.xonly)
        }

        /// Generates a secp256k1 public key.
        ///
        /// - Parameter baseKey: Generated secp256k1 public key.
        fileprivate init(baseKey: PublicKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Generates a secp256k1 public key from an x-only key.
        ///
        /// - Parameter xonlyKey: An x-only key object.
        public init(xonlyKey: XonlyKey) {
            let key = XonlyKeyImplementation(
                dataRepresentation: xonlyKey.bytes,
                keyParity: xonlyKey.parity ? 1 : 0,
                cache: xonlyKey.cache.bytes
            )
            self.baseKey = PublicKeyImplementation(xonlyKey: key)
        }

        /// Generates a secp256k1 public key from a raw representation.
        ///
        /// - Parameter data: A data representation of the key.
        /// - Parameter format: The key format.
        /// - Throws: An error if the raw representation does not create a public key.
        public init<D: ContiguousBytes>(
            dataRepresentation data: D,
            format: secp256k1.Format,
            cache: [UInt8]
        ) throws {
            self.baseKey = try PublicKeyImplementation(
                dataRepresentation: data,
                format: format,
                cache: cache
            )
        }
    }
}

public extension secp256k1.Schnorr {
    func aggregate(_ pubkeys: [PublicKey]) throws -> PublicKey {
        let context = secp256k1.Context.rawRepresentation
        let format = secp256k1.Format.compressed
        var pubKeyLen = format.length
        var aggPubkey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var keys = pubkeys.map {
            var newPubKey = secp256k1_pubkey()
            $0.dataRepresentation.copyToUnsafeMutableBytes(of: &newPubKey.data)
            let pointerKey: UnsafePointer<secp256k1_pubkey>? = withUnsafePointer(to: &newPubKey) { $0 }
            return pointerKey
        }

        guard secp256k1_musig_pubkey_agg(context, nil, nil, &cache, &keys, pubkeys.count).boolValue,
              secp256k1_musig_pubkey_get(context, &aggPubkey, &cache).boolValue,
              secp256k1_ec_pubkey_serialize(
                  context,
                  &pubBytes,
                  &pubKeyLen,
                  &aggPubkey,
                  format.rawValue
              ).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try PublicKey(
            dataRepresentation: pubBytes,
            format: format,
            cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
        )
    }
}

public extension secp256k1.Schnorr.PublicKey {
    /// Create a new `PublicKey` by adding tweak to the public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `PublicKey` object
    /// - Returns: tweaked `PublicKey` object
    func add(_ tweak: [UInt8], format: secp256k1.Format = .compressed) throws -> Self {
        let context = secp256k1.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var pubKeyLen = format.length
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        self.cache.copyToUnsafeMutableBytes(of: &cache.data)

        guard secp256k1_ec_pubkey_parse(context, &pubKey, bytes, pubKeyLen).boolValue,
              secp256k1_musig_pubkey_ec_tweak_add(context, &pubKey, &cache, tweak).boolValue,
              secp256k1_ec_pubkey_serialize(context, &pubKeyBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(
            dataRepresentation: pubKeyBytes,
            format: format,
            cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
        )
    }
}

public extension secp256k1.Schnorr.XonlyKey {
    /// Create a new `XonlyKey` by adding tweak to the x-only public key.
    /// - Parameters:
    ///   - tweak: the 32-byte tweak object
    ///   - format: the format of the tweaked `XonlyKey` object
    /// - Returns: tweaked `PublicKey` object
    func add(_ tweak: [UInt8]) throws -> Self {
        let context = secp256k1.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var outXonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.Schnorr.xonlyByteCount)
        var keyParity = Int32()

        self.cache.copyToUnsafeMutableBytes(of: &cache.data)

        guard secp256k1_musig_pubkey_xonly_tweak_add(context, &pubKey, &cache, tweak).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(context, &outXonlyPubKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &outXonlyPubKey).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(
            dataRepresentation: xonlyBytes,
            keyParity: keyParity,
            cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
        )
    }
}
