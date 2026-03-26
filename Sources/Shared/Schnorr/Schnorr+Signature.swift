//
//  Schnorr+Signature.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    // MARK: - Schnorr Signatures

    /// A Schnorr (Schnorr Digital Signature Scheme) Signature
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
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
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature`.
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature, "Invalid Schnorr signature size")
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

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Schnorr.PrivateKey: DigestSigner {
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

            guard secp256k1_keypair_create(context, &keypair, Array(dataRepresentation)).boolValue else {
                fatalError("secp256k1_keypair_create failed with valid key — library bug")
            }

            guard secp256k1_schnorrsig_sign_custom(
                context,
                &signature,
                &message,
                message.count,
                &keypair,
                &extraParams
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return P256K.Schnorr.SchnorrSignature(Data(bytes: signature, count: P256K.ByteLength.signature))
        }
    }

    // MARK: - Schnorr + Validating Key

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Schnorr.XonlyKey: DigestValidator {
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

#endif
