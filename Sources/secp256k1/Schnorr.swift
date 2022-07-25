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
import secp256k1_bindings

extension secp256k1 {
    @usableFromInline enum Schnorr {
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

// MARK: - Schnorr Signatures

/// A Schnorr (Schnorr Digital Signature Scheme) Signature
public extension secp256k1.Signing {
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

// MARK: - secp256k1 + Signing Key

public extension secp256k1.Signing {
    struct SchnorrSigner {
        /// Generated secp256k1 Signing Key.
        var signingKey: PrivateKeyImplementation
    }
}

extension secp256k1.Signing.SchnorrSigner: DigestSigner, Signer {
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
    public func signature<D: DataProtocol>(for data: D) throws -> secp256k1.Signing.SchnorrSignature {
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
    public func signature<D: Digest>(for digest: D) throws -> secp256k1.Signing.SchnorrSignature {
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
    public func signature<D: DataProtocol>(for data: D, auxiliaryRand: [UInt8]) throws -> secp256k1.Signing.SchnorrSignature {
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
    public func signature<D: Digest>(for digest: D, auxiliaryRand: [UInt8]) throws -> secp256k1.Signing.SchnorrSignature {
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
    public func signature(message: inout [UInt8], auxiliaryRand: UnsafeMutableRawPointer?) throws -> secp256k1.Signing.SchnorrSignature {
        var keypair = secp256k1_keypair()
        var signature = [UInt8](repeating: 0, count: secp256k1.Schnorr.signatureByteCount)
        var extraParams = secp256k1_schnorrsig_extraparams(magic: secp256k1.Schnorr.magic, noncefp: nil, ndata: auxiliaryRand)

        guard secp256k1_keypair_create(secp256k1.Context.raw, &keypair, signingKey.key.bytes).boolValue,
              secp256k1_schnorrsig_sign_custom(secp256k1.Context.raw, &signature, &message, message.count, &keypair, &extraParams).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try secp256k1.Signing.SchnorrSignature(Data(bytes: signature, count: secp256k1.Schnorr.signatureByteCount))
    }
}

// MARK: - Schnorr + Validating Key

public extension secp256k1.Signing {
    struct SchnorrValidator {
        /// Generated Schnorr Validating Key.
        var validatingKey: PublicKeyImplementation
    }
}

extension secp256k1.Signing.SchnorrValidator: DigestValidator, DataValidator {
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
    public func isValidSignature<D: DataProtocol>(_ signature: secp256k1.Signing.SchnorrSignature, for data: D) -> Bool {
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
    public func isValidSignature<D: Digest>(_ signature: secp256k1.Signing.SchnorrSignature, for digest: D) -> Bool {
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
    public func isValid(_ signature: secp256k1.Signing.SchnorrSignature, for message: inout [UInt8]) -> Bool {
        var pubKey = secp256k1_xonly_pubkey()

        return secp256k1_xonly_pubkey_parse(secp256k1.Context.raw, &pubKey, validatingKey.xonly.bytes).boolValue &&
            secp256k1_schnorrsig_verify(secp256k1.Context.raw, signature.rawRepresentation.bytes, message, message.count, &pubKey).boolValue
    }
}
