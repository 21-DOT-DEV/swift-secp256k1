//
//  Schnorr.swift
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

public extension P256K {
    enum Schnorr {
        /// Fixed number of bytes for Schnorr signature
        ///
        /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
        @inlinable static var signatureByteCount: Int { 64 }

        /// Fixed number of bytes for x-only key
        ///
        /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
        @inlinable static var xonlyByteCount: Int { 32 }

        /// Tuple representation of ``SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC``
        ///
        /// Only used at initialization and has no other function than making sure the object is initialized.
        ///
        /// [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L88)
        @inlinable static var magic: (UInt8, UInt8, UInt8, UInt8) { (218, 111, 179, 140) }
    }
}

/// An elliptic curve that enables secp256k1 signatures and key agreement.
public extension P256K.Schnorr {
    /// A representation of a secp256k1 private key used for signing.
    struct PrivateKey: Equatable {
        /// Generated secp256k1 Signing Key.
        private let baseKey: PrivateKeyImplementation

        /// The associated public key for verifying signatures created with this private key.
        ///
        /// - Returns: The associated public key.
        public var publicKey: PublicKey {
            PublicKey(baseKey: baseKey.publicKey)
        }

        /// The associated x-only public key for verifying Schnorr signatures.
        ///
        /// - Returns: The associated x-only public key.
        public var xonly: XonlyKey {
            XonlyKey(baseKey: baseKey.publicKey.xonly)
        }

        /// A data representation of the private key.
        public var dataRepresentation: Data {
            baseKey.dataRepresentation
        }

        /// Negates a secret key.
        public var negation: Self {
            get throws {
                let negatedKey = try baseKey.negation.dataRepresentation
                return try Self(dataRepresentation: negatedKey)
            }
        }

        /// Creates a random secp256k1 private key for signing.
        ///
        /// - Parameter format: The key format, default is .compressed.
        /// - Throws: An error if the private key cannot be generated.
        public init() throws {
            self.baseKey = try PrivateKeyImplementation(format: .uncompressed)
        }

        /// Creates a secp256k1 private key for signing from a data representation.
        ///
        /// - Parameter data: A data representation of the key.
        /// - Throws: An error if the data representation does not create a private key for signing.
        public init<D: ContiguousBytes>(dataRepresentation data: D) throws {
            self.baseKey = try PrivateKeyImplementation(dataRepresentation: data)
        }

        /// Determines if two private keys are equal.
        ///
        /// - Parameters:
        ///   - lhs: The left-hand side private key.
        ///   - rhs: The right-hand side private key.
        /// - Returns: True if the private keys are equal, false otherwise.
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.baseKey.key == rhs.baseKey.key
        }
    }

    /// The corresponding public key for the secp256k1 curve.
    struct PublicKey {
        /// Generated secp256k1 public key.
        let baseKey: PublicKeyImplementation

        /// The secp256k1 public key object.
        var bytes: [UInt8] {
            baseKey.bytes
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

        /// Generates a secp256k1 public key from an x-only key.
        ///
        /// - Parameter xonlyKey: An x-only key object.
        public init(xonlyKey: XonlyKey) {
            let key = XonlyKeyImplementation(
                dataRepresentation: xonlyKey.bytes,
                keyParity: xonlyKey.parity ? 1 : 0
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
            format: P256K.Format
        ) throws {
            self.baseKey = try PublicKeyImplementation(
                dataRepresentation: data,
                format: format
            )
        }
    }

    /// The corresponding x-only public key for the secp256k1 curve.
    struct XonlyKey: Equatable {
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

// MARK: - Schnorr Signatures

/// A Schnorr (Schnorr Digital Signature Scheme) Signature
public extension P256K.Schnorr {
    struct SchnorrSignature: ContiguousBytes, DataSignature {
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

// MARK: - secp256k1 + Schnorr

extension P256K.Schnorr.PrivateKey: DigestSigner, Signer {
    /// Generates an Schnorr signature from a hash of a variable length data object
    ///
    /// This function uses SHA256 to create a hash of the variable length the data argument to ensure only 32-byte messages are signed.
    /// Strictly does _not_ follow BIP340. Read ``secp256k1_schnorrsig_sign`` documentation for more info.
    ///
    /// [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L95L118)
    ///
    /// - Parameters:
    ///     - data: The data object to hash and sign.
    /// - Returns: The Schnorr Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: DataProtocol>(for data: D) throws -> P256K.Schnorr.SchnorrSignature {
        try signature(for: data, auxiliaryRand: SecureBytes(count: P256K.ByteLength.dimension).bytes)
    }

    /// Generates an Schnorr signature from the hash digest object
    ///
    /// This function is used when a hash digest has been created before invoking.
    /// Enables BIP340 signatures assuming the hash digest used the `Tagged Hashes` scheme as defined in the proposal.
    ///
    /// [BIP340 Design](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#design)
    ///
    /// - Parameters:
    ///     - digest: The digest to sign.
    /// - Returns: The Schnorr Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: Digest>(for digest: D) throws -> P256K.Schnorr.SchnorrSignature {
        try signature(for: digest, auxiliaryRand: SecureBytes(count: P256K.ByteLength.dimension).bytes)
    }

    /// Generates an Schnorr signature from a hash of a variable length data object
    ///
    /// This function uses SHA256 to create a hash of the variable length the data argument to ensure only 32-byte messages are signed.
    /// Strictly does _not_ follow BIP340. Read ``secp256k1_schnorrsig_sign`` documentation for more info.
    ///
    /// [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L95L118)
    ///
    /// - Parameters:
    ///     - data: The data object to hash and sign.
    ///     - auxiliaryRand: Auxiliary randomness.
    /// - Returns: The Schnorr Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: DataProtocol>(for data: D, auxiliaryRand: [UInt8]) throws -> P256K.Schnorr.SchnorrSignature {
        try signature(for: SHA256.hash(data: data), auxiliaryRand: auxiliaryRand)
    }

    /// Generates an Schnorr signature from the hash digest object
    ///
    /// This function is used when a hash digest has been created before invoking.
    /// Enables BIP340 signatures assuming the hash digest used the `Tagged Hashes` scheme as defined in the proposal.
    ///
    /// [BIP340 Design](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#design)
    ///
    /// - Parameters:
    ///     - digest: The digest to sign.
    ///     - auxiliaryRand: Auxiliary randomness; BIP340 requires 32-bytes.
    /// - Returns: The Schnorr Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: Digest>(for digest: D, auxiliaryRand: [UInt8]) throws -> P256K.Schnorr.SchnorrSignature {
        var hashDataBytes = Array(digest).bytes
        var randomBytes = auxiliaryRand

        return try signature(message: &hashDataBytes, auxiliaryRand: &randomBytes)
    }

    /// Generates an Schnorr signature from a message object with a variable length of bytes
    ///
    /// This function provides the flexibility for creating a Schnorr signature without making assumptions about message object.
    /// If ``auxiliaryRand`` is ``nil`` the ``secp256k1_nonce_function_bip340`` is used.
    ///
    /// [secp256k1_schnorrsig_extraparams](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L66L81)
    ///
    /// - Parameters:
    ///   - message: The message object to sign
    ///   - auxiliaryRand: Auxiliary randomness; BIP340 requires 32-bytes.
    /// - Returns: The Schnorr Signature.
    /// - Throws: If there is a failure creating the context or signature.
    public func signature(
        message: inout [UInt8],
        auxiliaryRand: UnsafeMutableRawPointer?,
        strict: Bool = false
    ) throws -> P256K.Schnorr.SchnorrSignature {
        guard strict == false || message.count == P256K.ByteLength.dimension else {
            throw secp256k1Error.incorrectParameterSize
        }

        let context = P256K.Context.rawRepresentation
        let magic = P256K.Schnorr.magic
        var keypair = secp256k1_keypair()
        var signature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
        var extraParams = secp256k1_schnorrsig_extraparams(magic: magic, noncefp: nil, ndata: auxiliaryRand)

        guard secp256k1_keypair_create(context, &keypair, Array(dataRepresentation)).boolValue,
              secp256k1_schnorrsig_sign_custom(
                  context,
                  &signature,
                  &message,
                  message.count,
                  &keypair,
                  &extraParams
              ).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try P256K.Schnorr.SchnorrSignature(Data(bytes: signature, count: P256K.ByteLength.signature))
    }
}

// MARK: - Schnorr + Validating Key

extension P256K.Schnorr.XonlyKey: DigestValidator, DataValidator {
    /// Verifies a Schnorr signature with a variable length data object
    ///
    /// This function uses SHA256 to create a hash of the variable length the data argument to ensure only 32-byte messages are verified.
    /// Strictly does _not_ follow BIP340. Read ``secp256k1_schnorrsig_sign`` documentation for more info.
    ///
    /// [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L95L118)
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The data that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: DataProtocol>(_ signature: P256K.Schnorr.SchnorrSignature, for data: D) -> Bool {
        isValidSignature(signature, for: SHA256.hash(data: data))
    }

    /// Verifies a Schnorr signature with a digest
    ///
    /// This function is used when a hash digest has been created before invoking.
    /// Enables BIP340 signatures assuming the hash digest used the `Tagged Hashes` scheme as defined in the proposal.
    ///
    /// [BIP340 Design](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#design)
    ///
    /// - Parameters:
    ///   - signature: The signature to verify.
    ///   - digest: The digest that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: Digest>(_ signature: P256K.Schnorr.SchnorrSignature, for digest: D) -> Bool {
        var hashDataBytes = Array(digest).bytes

        return isValid(signature, for: &hashDataBytes)
    }

    /// Verifies a Schnorr signature with a variable length message object
    ///
    /// This function provides flexibility for verifying a Schnorr signature without assumptions about message.
    ///
    /// [secp256k1_schnorrsig_verify](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L149L158)
    ///
    /// - Parameters:
    ///   - signature: The signature to verify.
    ///   - message:  The message that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValid(_ signature: P256K.Schnorr.SchnorrSignature, for message: inout [UInt8]) -> Bool {
        let context = P256K.Context.rawRepresentation
        var pubKey = secp256k1_xonly_pubkey()

        return secp256k1_xonly_pubkey_parse(context, &pubKey, bytes).boolValue &&
            secp256k1_schnorrsig_verify(
                context,
                signature.dataRepresentation.bytes,
                message,
                message.count,
                &pubKey
            ).boolValue
    }
}
