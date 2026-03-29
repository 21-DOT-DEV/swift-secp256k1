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

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// 64-byte BIP-340 Schnorr signature over the secp256k1 elliptic curve, produced by `secp256k1_schnorrsig_sign_custom` and verified by `secp256k1_schnorrsig_verify`.
        ///
        /// BIP-340 Schnorr signatures always have a fixed 64-byte encoding: the 32-byte `R.x`
        /// coordinate followed by 32-byte scalar `s`. There is no DER encoding or alternative
        /// format. Unlike ECDSA, Schnorr signatures have a unique representation.
        struct SchnorrSignature: ContiguousBytes, DataSignature {
            /// The 64-byte BIP-340 Schnorr signature (`R.x || s` in big-endian).
            public var dataRepresentation: Data

            /// Creates a ``SchnorrSignature`` from a 64-byte raw representation.
            ///
            /// - Parameter dataRepresentation: Exactly 64 bytes in BIP-340 format (`R.x || s`).
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count is not 64.
            public init<D: DataProtocol>(dataRepresentation: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
            }

            /// Creates a ``SchnorrSignature`` from a pre-validated 64-byte data value.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature` (64).
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature, "Invalid Schnorr signature size")
                self.dataRepresentation = dataRepresentation
            }

            /// Calls `body` with an unsafe pointer to the signature's 64 raw bytes.
            ///
            /// - Parameter body: A closure receiving a raw buffer pointer over the signature data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

    // MARK: - secp256k1 + Schnorr

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Schnorr.PrivateKey: DigestSigner {
        /// Generates a BIP-340 Schnorr signature from a pre-computed digest using `secp256k1_schnorrsig_sign_custom` with fresh 32-byte auxiliary randomness.
        ///
        /// The auxiliary randomness is mixed into the BIP-340 nonce derivation (`secp256k1_nonce_function_bip340`)
        /// to protect against fault attacks. When the digest was produced using BIP-340 Tagged Hashes,
        /// the resulting signature is fully BIP-340 compliant.
        ///
        /// - Parameter digest: The pre-computed message digest to sign.
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if signature production fails.
        public func signature<D: Digest>(for digest: D) throws -> P256K.Schnorr.SchnorrSignature {
            try signature(for: digest, auxiliaryRand: SecureBytes(count: P256K.ByteLength.dimension).bytes)
        }

        /// Generates a BIP-340 Schnorr signature from a pre-computed digest using caller-supplied auxiliary randomness.
        ///
        /// - Parameters:
        ///   - digest: The pre-computed message digest to sign.
        ///   - auxiliaryRand: Exactly 32 bytes of auxiliary randomness for BIP-340 nonce derivation; pass zeroed bytes to disable.
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if signature production fails.
        public func signature<D: Digest>(for digest: D, auxiliaryRand: [UInt8]) throws -> P256K.Schnorr.SchnorrSignature {
            var hashDataBytes = Array(digest).bytes
            var randomBytes = auxiliaryRand

            return try signature(message: &hashDataBytes, auxiliaryRand: &randomBytes)
        }

        /// Generates a Schnorr signature over an arbitrary-length message using `secp256k1_schnorrsig_sign_custom`.
        ///
        /// Unlike the `Digest`-based overloads, this method accepts any message length and passes it
        /// directly to `secp256k1_schnorrsig_sign_custom`. If `auxiliaryRand` is `nil`,
        /// `secp256k1_nonce_function_bip340` sets the auxiliary random data to zero. Pass a pointer
        /// to 32 bytes for full BIP-340 compliant nonce derivation.
        ///
        /// - Parameters:
        ///   - message: The message bytes to sign (any length unless `strict` is `true`).
        ///   - auxiliaryRand: Pointer to 32 bytes of auxiliary randomness, or `nil` to use zero auxiliary data.
        ///   - strict: If `true`, throws ``secp256k1Error/incorrectParameterSize`` when `message.count` is not 32.
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `strict` is `true` and the message is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if signing fails.
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
        /// Verifies a BIP-340 Schnorr signature against a pre-computed digest using `secp256k1_schnorrsig_verify`.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``SchnorrSignature`` to verify.
        ///   - digest: The pre-computed digest that was signed. Must be the same digest type and data used when signing.
        /// - Returns: `true` if the signature is valid for `digest` under this x-only public key, `false` otherwise.
        public func isValidSignature<D: Digest>(_ signature: P256K.Schnorr.SchnorrSignature, for digest: D) -> Bool {
            var hashDataBytes = Array(digest).bytes

            return isValid(signature, for: &hashDataBytes)
        }

        /// Verifies a Schnorr signature over an arbitrary-length message using `secp256k1_schnorrsig_verify`.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``SchnorrSignature`` to verify.
        ///   - message: The message bytes that were signed (any length; must match the bytes used when signing).
        /// - Returns: `true` if the signature is valid, `false` otherwise.
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
