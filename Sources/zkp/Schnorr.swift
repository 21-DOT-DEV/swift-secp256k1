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

public extension secp256k1 {
    enum Schnorr {
        /// Fixed number of bytes for Schnorr signature
        ///
        /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
        @inlinable static var signatureByteCount: Int { 64 }

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
public extension secp256k1.Schnorr {
    /// A representation of a secp256k1 private key used for signing.
    struct PrivateKey: Equatable {
        /// Generated secp256k1 Signing Key.
        private let baseKey: PrivateKeyImplementation

        /// The associated x-only public key for verifying Schnorr signatures.
        ///
        /// - Returns: The associated x-only public key.
        public var xonly: XonlyKey {
            XonlyKey(baseKey: baseKey.publicKey.xonly)
        }

        /// A data representation of the private key.
        public var rawRepresentation: Data {
            baseKey.rawRepresentation
        }

        /// Creates a random secp256k1 private key for signing.
        ///
        /// - Parameter format: The key format, default is .compressed.
        /// - Throws: An error if the private key cannot be generated.
        public init(format: secp256k1.Format = .compressed) throws {
            self.baseKey = try PrivateKeyImplementation(format: format)
        }

        /// Creates a secp256k1 private key for signing from a data representation.
        ///
        /// - Parameter data: A raw representation of the key.
        /// - Parameter format: The key format, default is .compressed.
        /// - Throws: An error if the raw representation does not create a private key for signing.
        public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
            self.baseKey = try PrivateKeyImplementation(rawRepresentation: data, format: format)
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

    /// The corresponding x-only public key for the secp256k1 curve.
    struct XonlyKey {
        /// Generated secp256k1 x-only public key.
        private let baseKey: XonlyKeyImplementation

        /// The secp256k1 x-only public key object.
        public var bytes: [UInt8] {
            baseKey.bytes
        }

        /// Schnorr x-only public key are implicit of the point being even, therefore this will always return `false`.`
        public var parity: Bool {
            false
        }

        /// Generates a secp256k1 x-only public key.
        ///
        /// - Parameter baseKey: Generated secp256k1 x-only public key.
        fileprivate init(baseKey: XonlyKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Generates a secp256k1 x-only public key from a raw representation.
        ///
        /// - Parameter data: A raw representation of the x-only public key.
        public init<D: ContiguousBytes>(rawRepresentation data: D) {
            self.baseKey = XonlyKeyImplementation(rawRepresentation: data, keyParity: 0)
        }
    }
}

// MARK: - Schnorr Signatures

/// A Schnorr (Schnorr Digital Signature Scheme) Signature
public extension secp256k1.Schnorr {
    struct SchnorrSignature: ContiguousBytes, RawSignature {
        /// Returns the raw signature in a fixed 64-byte format.
        public var rawRepresentation: Data

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the rawRepresentation count
        public init<D: DataProtocol>(rawRepresentation: D) throws {
            guard rawRepresentation.count == secp256k1.Schnorr.signatureByteCount else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.rawRepresentation = Data(rawRepresentation)
        }

        /// Initializes SchnorrSignature from the raw representation.
        /// - Parameters:
        ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        internal init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == secp256k1.Schnorr.signatureByteCount else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.rawRepresentation = dataRepresentation
        }

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameters:
        ///     - body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try rawRepresentation.withUnsafeBytes(body)
        }
    }
}

// MARK: - secp256k1 + Schnorr

extension secp256k1.Schnorr.PrivateKey: DigestSigner, Signer {
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
    public func signature<D: DataProtocol>(for data: D) throws -> secp256k1.Schnorr.SchnorrSignature {
        try signature(for: data, auxiliaryRand: SecureBytes(count: secp256k1.Schnorr.xonlyByteCount).bytes)
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
    public func signature<D: Digest>(for digest: D) throws -> secp256k1.Schnorr.SchnorrSignature {
        try signature(for: digest, auxiliaryRand: SecureBytes(count: secp256k1.Schnorr.xonlyByteCount).bytes)
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
    public func signature<D: DataProtocol>(for data: D, auxiliaryRand: [UInt8]) throws -> secp256k1.Schnorr.SchnorrSignature {
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
    public func signature<D: Digest>(for digest: D, auxiliaryRand: [UInt8]) throws -> secp256k1.Schnorr.SchnorrSignature {
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
    public func signature(message: inout [UInt8], auxiliaryRand: UnsafeMutableRawPointer?) throws -> secp256k1.Schnorr.SchnorrSignature {
        var keypair = secp256k1_keypair()
        var signature = [UInt8](repeating: 0, count: secp256k1.Schnorr.signatureByteCount)
        var extraParams = secp256k1_schnorrsig_extraparams(magic: secp256k1.Schnorr.magic, noncefp: nil, ndata: auxiliaryRand)

        guard secp256k1_keypair_create(secp256k1.Context.raw, &keypair, Array(rawRepresentation)).boolValue,
              secp256k1_schnorrsig_sign_custom(secp256k1.Context.raw, &signature, &message, message.count, &keypair, &extraParams).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try secp256k1.Schnorr.SchnorrSignature(Data(bytes: signature, count: secp256k1.Schnorr.signatureByteCount))
    }
}

// MARK: - Schnorr + Validating Key

extension secp256k1.Schnorr.XonlyKey: DigestValidator, DataValidator {
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
    public func isValidSignature<D: DataProtocol>(_ signature: secp256k1.Schnorr.SchnorrSignature, for data: D) -> Bool {
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
    public func isValidSignature<D: Digest>(_ signature: secp256k1.Schnorr.SchnorrSignature, for digest: D) -> Bool {
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
    public func isValid(_ signature: secp256k1.Schnorr.SchnorrSignature, for message: inout [UInt8]) -> Bool {
        var pubKey = secp256k1_xonly_pubkey()

        return secp256k1_xonly_pubkey_parse(secp256k1.Context.raw, &pubKey, bytes).boolValue &&
            secp256k1_schnorrsig_verify(secp256k1.Context.raw, signature.rawRepresentation.bytes, message, message.count, &pubKey).boolValue
    }
}
