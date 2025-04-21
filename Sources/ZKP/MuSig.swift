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

#if canImport(libsecp256k1_zkp)
    @_implementationOnly import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    @_implementationOnly import libsecp256k1
#endif

public extension P256K {
    /// MuSig is a multi-signature scheme that allows multiple parties to sign a message using their own private keys,
    /// but only reveal their public keys. The aggregated public key is then used to verify the signature.
    ///
    /// This implementation follows the MuSig algorithm as described in BIP-327.
    enum MuSig {
        /// Represents a public key in the MuSig scheme.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            let baseKey: PublicKeyImplementation

            /// The secp256k1 public key object.
            var bytes: [UInt8] {
                baseKey.bytes
            }

            /// The cache of information about public key aggregation.
            var keyAggregationCache: Data {
                Data(baseKey.cache)
            }

            /// The key format representation of the public key.
            public var format: P256K.Format {
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

            /// Creates a MuSig public key from an x-only key.
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

            /// Creates a MuSig public key from raw data.
            ///
            /// - Parameters:
            ///   - data: A data representation of the key.
            ///   - format: The key format.
            ///   - cache: The key aggregation cache.
            /// - Throws: An error if the raw representation does not create a valid public key.
            public init<D: ContiguousBytes>(
                dataRepresentation data: D,
                format: P256K.Format,
                cache: [UInt8]
            ) throws {
                self.baseKey = try PublicKeyImplementation(
                    dataRepresentation: data,
                    format: format,
                    cache: cache
                )
            }
        }

        /// Represents an x-only public key in the MuSig scheme.
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

            /// Creates a MuSig x-only public key from raw data.
            ///
            /// - Parameters:
            ///   - data: A data representation of the x-only public key.
            ///   - keyParity: The key parity as an `Int32`.
            ///   - cache: The key aggregation cache.
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

public extension P256K.MuSig {
    /// Aggregates multiple Schnorr public keys into a single Schnorr public key using the MuSig algorithm.
    ///
    /// This function implements the key aggregation process as described in BIP-327.
    ///
    /// - Parameter pubkeys: An array of Schnorr public keys to aggregate.
    /// - Returns: The aggregated Schnorr public key.
    /// - Throws: An error if aggregation fails.
    static func aggregate(_ pubkeys: [P256K.Schnorr.PublicKey]) throws -> P256K.MuSig.PublicKey {
        let context = P256K.Context.rawRepresentation
        let format = P256K.Format.compressed
        var pubKeyLen = format.length
        var aggPubkey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard PointerArrayUtility
            .withUnsafePointerArray(pubkeys.map { $0.baseKey.rawRepresentation }, { pointers in
                #if canImport(libsecp256k1_zkp)
                    secp256k1_pubkey_sort(context, &pointers, pointers.count).boolValue &&
                        secp256k1_musig_pubkey_agg(context, nil, nil, &cache, pointers, pointers.count).boolValue
                #elseif canImport(libsecp256k1)
                    secp256k1_ec_pubkey_sort(context, &pointers, pointers.count).boolValue &&
                        secp256k1_musig_pubkey_agg(context, nil, &cache, pointers, pointers.count).boolValue
                #endif
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

        return try P256K.MuSig.PublicKey(
            dataRepresentation: pubBytes,
            format: format,
            cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
        )
    }
}

public extension P256K.MuSig.PublicKey {
    /// Creates a new `PublicKey` by adding a tweak to the public key.
    ///
    /// This function implements the tweaking process for MuSig public keys as described in BIP-327.
    ///
    /// - Parameters:
    ///   - tweak: The 32-byte tweak to apply.
    ///   - format: The format of the tweaked `PublicKey` object.
    /// - Returns: A new tweaked `PublicKey` object.
    /// - Throws: An error if tweaking fails.
    func add(_ tweak: [UInt8], format: P256K.Format = .compressed) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var pubKeyLen = format.length
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)

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

public extension P256K.MuSig.XonlyKey {
    /// Creates a new `XonlyKey` by adding a tweak to the x-only public key.
    ///
    /// This function implements the tweaking process for MuSig x-only public keys as described in BIP-327.
    ///
    /// - Parameter tweak: The 32-byte tweak to apply.
    /// - Returns: A new tweaked `XonlyKey` object.
    /// - Throws: An error if tweaking fails.
    func add(_ tweak: [UInt8]) throws -> Self {
        let context = P256K.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var cache = secp256k1_musig_keyagg_cache()
        var outXonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: P256K.Schnorr.xonlyByteCount)
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
public extension P256K.Schnorr {
    struct PartialSignature: ContiguousBytes {
        /// Returns the raw signature in a fixed 64-byte format.
        public var dataRepresentation: Data
        ///  Returns the MuSig Session  in a fixed 133-byte format.
        public var session: Data

        /// Creates a partial signature from raw data.
        ///
        /// - Parameters:
        ///   - dataRepresentation: The raw partial signature data.
        ///   - session: The MuSig session data.
        /// - Throws: An error if the data is invalid.
        public init<D: DataProtocol>(dataRepresentation: D, session: D) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
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
            guard dataRepresentation.count == P256K.ByteLength.partialSignature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = dataRepresentation
            self.session = session
        }

        /// Provides access to the raw bytes of the partial signature.
        ///
        /// - Parameter body: A closure that takes an `UnsafeRawBufferPointer` and returns a value.
        /// - Returns: The value returned by the closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }
    }
}

public extension P256K.MuSig.PublicKey {
    /// Verifies a partial signature against this public key.
    ///
    /// This function implements the partial signature verification process as described in BIP-327.
    ///
    /// - Parameters:
    ///   - partialSignature: The partial signature to verify.
    ///   - publicKey: The signer's public key.
    ///   - nonce: The signer's public nonce.
    ///   - digest: The message digest being signed.
    /// - Returns: `true` if the partial signature is valid, `false` otherwise.
    func isValidSignature<D: Digest>(
        _ partialSignature: P256K.Schnorr.PartialSignature,
        publicKey: P256K.Schnorr.PublicKey,
        nonce: P256K.Schnorr.Nonce,
        for digest: D
    ) -> Bool {
        let context = P256K.Context.rawRepresentation
        var partialSig = secp256k1_musig_partial_sig()
        var pubnonce = secp256k1_musig_pubnonce()
        var publicKey = publicKey.baseKey.rawRepresentation
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

public extension P256K.Schnorr.PrivateKey {
    /// Generates a partial signature for MuSig.
    ///
    /// This function implements the partial signing process as described in BIP-327.
    ///
    /// - Parameters:
    ///   - digest: The message digest to sign.
    ///   - pubnonce: The signer's public nonce.
    ///   - secureNonce: The signer's secret nonce.
    ///   - publicNonceAggregate: The aggregate of all signers' public nonces.
    ///   - publicKeyAggregate: The aggregate of all signers' public keys.
    /// - Returns: A partial MuSig signature.
    /// - Throws: An error if partial signature generation fails.
    func partialSignature<D: Digest>(
        for digest: D,
        pubnonce: P256K.Schnorr.Nonce,
        secureNonce: consuming P256K.Schnorr.SecureNonce,
        publicNonceAggregate: P256K.MuSig.Nonce,
        publicKeyAggregate: P256K.MuSig.PublicKey
    ) throws -> P256K.Schnorr.PartialSignature {
        let context = P256K.Context.rawRepresentation
        var signature = secp256k1_musig_partial_sig()
        var secnonce = secp256k1_musig_secnonce()
        var keypair = secp256k1_keypair()
        var cache = secp256k1_musig_keyagg_cache()
        var session = secp256k1_musig_session()
        var aggnonce = secp256k1_musig_aggnonce()
        var partialSignature = [UInt8](repeating: 0, count: P256K.ByteLength.partialSignature)

        guard secp256k1_keypair_create(context, &keypair, Array(dataRepresentation)).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        secureNonce.data.copyToUnsafeMutableBytes(of: &secnonce.data)
        publicKeyAggregate.keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)
        publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

        #if canImport(libsecp256k1_zkp)
            guard secp256k1_musig_nonce_process(context, &session, &aggnonce, Array(digest), &cache, nil).boolValue,
                  secp256k1_musig_partial_sign(context, &signature, &secnonce, &keypair, &cache, &session).boolValue,
                  secp256k1_musig_partial_sig_serialize(context, &partialSignature, &signature).boolValue
            else {
                throw secp256k1Error.underlyingCryptoError
            }
        #elseif canImport(libsecp256k1)
            guard secp256k1_musig_nonce_process(context, &session, &aggnonce, Array(digest), &cache).boolValue,
                  secp256k1_musig_partial_sign(context, &signature, &secnonce, &keypair, &cache, &session).boolValue,
                  secp256k1_musig_partial_sig_serialize(context, &partialSignature, &signature).boolValue
            else {
                throw secp256k1Error.underlyingCryptoError
            }
        #endif

        return try P256K.Schnorr.PartialSignature(
            Data(bytes: &partialSignature, count: P256K.ByteLength.partialSignature),
            session: session.dataValue
        )
    }

    /// Generates a partial signature for MuSig using SHA256 as the hash function.
    ///
    /// This is a convenience method that hashes the input data using SHA256 before signing.
    ///
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - pubnonce: The signer's public nonce.
    ///   - secureNonce: The signer's secret nonce.
    ///   - publicNonceAggregate: The aggregate of all signers' public nonces.
    ///   - publicKeyAggregate: The aggregate of all signers' public keys.
    /// - Returns: A partial MuSig signature.
    /// - Throws: An error if partial signature generation fails.
    func partialSignature<D: DataProtocol>(
        for data: D,
        pubnonce: P256K.Schnorr.Nonce,
        secureNonce: consuming P256K.Schnorr.SecureNonce,
        publicNonceAggregate: P256K.MuSig.Nonce,
        publicKeyAggregate: P256K.MuSig.PublicKey
    ) throws -> P256K.Schnorr.PartialSignature {
        try partialSignature(
            for: SHA256.hash(data: data),
            pubnonce: pubnonce,
            secureNonce: secureNonce,
            publicNonceAggregate: publicNonceAggregate,
            publicKeyAggregate: publicKeyAggregate
        )
    }
}

/// An extension for secp256k1_musig_partial_sig providing a convenience property.
extension secp256k1_musig_partial_sig {
    /// A property that returns the Data representation of the `secp256k1_musig_partial_sig` object.
    var dataValue: Data {
        var mutableSig = self
        return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
    }
}

/// An extension for secp256k1_musig_session providing a convenience property.
extension secp256k1_musig_session {
    var dataValue: Data {
        var mutableSession = self
        return Data(bytes: &mutableSession.data, count: MemoryLayout.size(ofValue: data))
    }
}

/// A Schnorr (Schnorr Digital Signature Scheme) Signature
public extension P256K.MuSig {
    struct AggregateSignature: ContiguousBytes, DataSignature {
        /// Returns the raw signature in a fixed 64-byte format.
        public var dataRepresentation: Data

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - dataRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the rawRepresentation count
        public init<D: DataProtocol>(dataRepresentation: D) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = Data(dataRepresentation)
        }

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
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

public extension P256K.MuSig {
    /// Aggregates partial signatures into a complete signature.
    ///
    /// - Parameter partialSignatures: An array of partial signatures to aggregate.
    /// - Returns: The aggregated Schnorr signature.
    /// - Throws: If there is a failure aggregating the signatures.
    static func aggregateSignatures(
        _ partialSignatures: [P256K.Schnorr.PartialSignature]
    ) throws -> P256K.MuSig.AggregateSignature {
        let context = P256K.Context.rawRepresentation
        var signature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
        var session = secp256k1_musig_session()

        partialSignatures.first?.session.copyToUnsafeMutableBytes(of: &session.data)

        guard PointerArrayUtility.withUnsafePointerArray(
            partialSignatures.map {
                var partialSig = secp256k1_musig_partial_sig()
                _ = secp256k1_musig_partial_sig_parse(context, &partialSig, Array($0.dataRepresentation))
                return partialSig
            }, { pointers in
                secp256k1_musig_partial_sig_agg(context, &signature, &session, pointers, pointers.count).boolValue
            }
        ) else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try P256K.MuSig.AggregateSignature(Data(signature))
    }
}
