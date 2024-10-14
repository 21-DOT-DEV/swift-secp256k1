//
//  MuSig.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2024 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import zkp_bindings

public extension secp256k1 {
    /// MuSig is a multi-signature scheme that allows multiple parties to sign a message using their own private keys,
    /// but only reveal their public keys. The aggregated public key is then used to verify the signature.
    ///
    /// This implementation follows the MuSig algorithm as described in the BIP (https://github.com/bitcoin/bips/blob/26bb1d8/bip-0327.mediawiki)
    enum MuSig {
        /// The corresponding public key for the secp256k1 curve.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            private let baseKey: PublicKeyImplementation

            /// The secp256k1 public key object.
            var bytes: [UInt8] {
                baseKey.bytes
            }

            /// The cache of information about public key aggregation.
            var keyAggregationCache: Data {
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

            /// A raw representation of the public key.
            public var rawRepresentation: secp256k1_pubkey {
                baseKey.rawRepresentation
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

        /// The corresponding x-only public key for the secp256k1 curve.
        public struct XonlyKey: Equatable {
            /// Generated secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// The secp256k1 x-only public key object.
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            /// Schnorr x-only public key are implicit of the point being even, therefore this will always return `false`.`
            public var parity: Bool {
                baseKey.keyParity.boolValue
            }

            /// The cache of information about public key aggregation.
            public var cache: Data {
                Data(baseKey.cache)
            }

            /// Generates a secp256k1 x-only public key.
            ///
            /// - Parameter baseKey: Generated secp256k1 x-only public key.
            init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 x-only public key from a raw representation.
            ///
            /// - Parameter data: A data representation of the x-only public key.
            /// - Parameter keyParity: The key parity as an `Int32`.
            public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32 = 0, cache: [UInt8] = []) {
                self.baseKey = XonlyKeyImplementation(dataRepresentation: data, keyParity: keyParity, cache: cache)
            }

            /// Determines if two x-only keys are equal.
            ///
            /// - Parameters:
            ///   - lhs: The left-hand side private key.
            ///   - rhs: The right-hand side private key.
            /// - Returns: True if the private keys are equal, false otherwise.
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.baseKey.bytes == rhs.baseKey.bytes
            }
        }
    }
}

// MARK: - secp256k1 + MuSig

extension secp256k1.MuSig {
    /// Aggregates multiple Schnorr public keys into a single Schnorr public
    /// key using the MuSig algorithm for multi-signature schemes. This function
    /// combines the public keys and ensures the aggregated key is valid for use
    /// in Schnorr signatures.
    ///
    /// - Parameter pubkeys: An array of Schnorr public keys.
    /// - Returns: The aggregated Schnorr public key.
    /// - Throws: `secp256k1Error.underlyingCryptoError` if aggregation fails.
    static func aggregate(_ pubkeys: [secp256k1.Schnorr.PublicKey]) throws -> secp256k1.MuSig.PublicKey {
        let context = secp256k1.Context.rawRepresentation
        let format = secp256k1.Format.compressed
        var pubKeyLen = format.length
        var aggPubkey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard PointerArrayUtility.withUnsafePointerArray(pubkeys.map { $0.rawRepresentation }, { pointers in
            secp256k1_pubkey_sort(context, &pointers, pointers.count).boolValue &&
                secp256k1_musig_pubkey_agg(context, nil, nil, &cache, pointers, pointers.count).boolValue
        }), secp256k1_musig_pubkey_get(context, &aggPubkey, &cache).boolValue,
              secp256k1_ec_pubkey_serialize(
                context,
                &pubBytes,
                &pubKeyLen,
                &aggPubkey,
                format.rawValue
              ).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try secp256k1.MuSig.PublicKey(
            dataRepresentation: pubBytes,
            format: format,
            cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
        )
    }
}

public extension secp256k1.MuSig.PublicKey {
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

        self.keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)

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

public extension secp256k1.MuSig.XonlyKey {
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
              secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &outXonlyPubKey).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return Self(
            dataRepresentation: xonlyBytes,
            keyParity: keyParity,
            cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
        )
    }
}

/// A Schnorr (Schnorr Digital Signature Scheme) Signature
public extension secp256k1.Schnorr {
    struct PartialSignature: ContiguousBytes {
        /// Returns the raw signature in a fixed 64-byte format.
        public var dataRepresentation: Data
        ///  Returns the MuSig Session  in a fixed 133-byte format.
        public var session: Data

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - dataRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the rawRepresentation count
        public init<D: DataProtocol>(dataRepresentation: D, session: D) throws {
            guard dataRepresentation.count == secp256k1.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = Data(dataRepresentation)
            self.session = Data(session)
        }

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        init(_ dataRepresentation: Data, session: Data) throws {
            guard dataRepresentation.count == secp256k1.ByteLength.partialSignature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = dataRepresentation
            self.session = session
        }

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameters:
        ///     - body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }
    }
}

extension secp256k1.MuSig.PublicKey {
    public func isValidSignature<D: Digest>(
        _ partialSignature: secp256k1.Schnorr.PartialSignature,
        publicKey: secp256k1.Schnorr.PublicKey,
        nonce: secp256k1.Schnorr.Nonce,
        for digest: D
    ) -> Bool {
        let context = secp256k1.Context.rawRepresentation
        var partialSig = secp256k1_musig_partial_sig()
        var pubnonce = secp256k1_musig_pubnonce()
        var publicKey = publicKey.rawRepresentation
        var cache = secp256k1_musig_keyagg_cache()
        var session = secp256k1_musig_session()

        nonce.pubnonce.copyToUnsafeMutableBytes(of: &pubnonce.data)
        keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)
        partialSignature.session.copyToUnsafeMutableBytes(of: &session.data)

        guard secp256k1_musig_partial_sig_parse(context, &partialSig, Array(partialSignature.dataRepresentation)).boolValue else {
            return false
        }

        return secp256k1_musig_partial_sig_verify(
            context,
            &partialSig,
            &pubnonce,
            &publicKey,
            &cache,
            &session
        ).boolValue
    }
}

extension secp256k1.Schnorr.PrivateKey {
    /// Generates a MuSig partial signature.
    ///
    /// - Parameters:
    ///   - message: The message to sign.
    ///   - nonce: The signer's secret nonce.
    ///   - publicNonceAggregate: The aggregate of all signers' public nonces.
    ///   - publicKeyAggregate: The aggregate of all signers' public keys.
    /// - Returns: The partial MuSig signature.
    /// - Throws: If there is a failure producing the signature.
    public func partialSignature<D: Digest>(
        for digest: D,
        nonce: secp256k1.Schnorr.Nonce,
        publicNonceAggregate: secp256k1.MuSig.Nonce,
        publicKeyAggregate: secp256k1.MuSig.PublicKey
    ) throws -> secp256k1.Schnorr.PartialSignature {
        let context = secp256k1.Context.rawRepresentation
        var signature = secp256k1_musig_partial_sig()
        var secnonce = secp256k1_musig_secnonce()
        var keypair = secp256k1_keypair()
        var cache = secp256k1_musig_keyagg_cache()
        var session = secp256k1_musig_session()
        var aggnonce = secp256k1_musig_aggnonce()
        var partialSignature = [UInt8](repeating: 0, count: secp256k1.ByteLength.partialSignature)

        guard secp256k1_keypair_create(context, &keypair, Array(dataRepresentation)).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        nonce.secnonce.copyToUnsafeMutableBytes(of: &secnonce.data)
        publicKeyAggregate.keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)
        publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

        guard secp256k1_musig_nonce_process(context, &session, &aggnonce, Array(digest), &cache, nil).boolValue,
            secp256k1_musig_partial_sign(context, &signature, &secnonce, &keypair, &cache, &session).boolValue,
              secp256k1_musig_partial_sig_serialize(context, &partialSignature, &signature).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try secp256k1.Schnorr.PartialSignature(
            Data(bytes: &partialSignature, count: secp256k1.ByteLength.partialSignature),
            session: session.dataValue
        )
    }

    /// Generates a MuSig partial signature. SHA256 is used as the hash function.
    ///
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - nonce: The signer's secret nonce.
    ///   - publicNonceAggregate: The aggregate of all signers' public nonces.
    ///   - publicKeyAggregate: The aggregate of all signers' public keys.
    /// - Returns: The partial MuSig signature.
    /// - Throws: If there is a failure producing the signature.
    public func partialSignature<D: DataProtocol>(
        for data: D,
        nonce: secp256k1.Schnorr.Nonce,
        publicNonceAggregate: secp256k1.MuSig.Nonce,
        publicKeyAggregate: secp256k1.MuSig.PublicKey
    ) throws -> secp256k1.Schnorr.PartialSignature {
        try partialSignature(
            for: SHA256.hash(data: data),
            nonce: nonce,
            publicNonceAggregate: publicNonceAggregate,
            publicKeyAggregate: publicKeyAggregate
        )
    }
}

/// An extension for secp256k1_musig_partial_sig providing a convenience property.
public extension secp256k1_musig_partial_sig {
    /// A property that returns the Data representation of the `secp256k1_musig_partial_sig` object.
    var dataValue: Data {
        var mutableSig = self
        return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
    }
}

/// An extension for secp256k1_musig_session providing a convenience property.
public extension secp256k1_musig_session {
    var dataValue: Data {
        var mutableSession = self
        return Data(bytes: &mutableSession.data, count: MemoryLayout.size(ofValue: data))
    }
}

/// A Schnorr (Schnorr Digital Signature Scheme) Signature
public extension secp256k1.MuSig {
    struct AggregateSignature: ContiguousBytes, DataSignature {
        /// Returns the raw signature in a fixed 64-byte format.
        public var dataRepresentation: Data

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - dataRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the rawRepresentation count
        public init<D: DataProtocol>(dataRepresentation: D) throws {
            guard dataRepresentation.count == secp256k1.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = Data(dataRepresentation)
        }

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == secp256k1.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = dataRepresentation
        }

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameters:
        ///     - body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }
    }
}

extension secp256k1.MuSig {
    /// Aggregates partial signatures into a complete signature.
    ///
    /// - Parameter partialSignatures: An array of partial signatures to aggregate.
    /// - Returns: The aggregated Schnorr signature.
    /// - Throws: If there is a failure aggregating the signatures.
    public static func aggregateSignatures(
        _ partialSignatures: [secp256k1.Schnorr.PartialSignature]
    ) throws -> secp256k1.MuSig.AggregateSignature {
        let context = secp256k1.Context.rawRepresentation
        var signature = [UInt8](repeating: 0, count: secp256k1.ByteLength.signature)
        var session = secp256k1_musig_session()

        partialSignatures.first?.session.copyToUnsafeMutableBytes(of: &session.data)

        guard PointerArrayUtility.withUnsafePointerArray(
            partialSignatures.map {
                var partialSig = secp256k1_musig_partial_sig()
                secp256k1_musig_partial_sig_parse(context, &partialSig, Array($0.dataRepresentation))
                return partialSig
            }, { pointers in
                secp256k1_musig_partial_sig_agg(context, &signature, &session, pointers, pointers.count).boolValue
            }) else {
            throw secp256k1Error.underlyingCryptoError
        }
        
        return try secp256k1.MuSig.AggregateSignature(Data(signature))
    }
}
