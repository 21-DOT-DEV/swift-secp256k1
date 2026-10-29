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
import libsecp256k1

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    // MARK: - Schnorr Signatures

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// 64-byte
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// signature over the secp256k1 elliptic curve, produced by
        /// `secp256k1_schnorrsig_sign_custom` and verified by `secp256k1_schnorrsig_verify`
        /// (both declared in
        /// [`secp256k1/include/secp256k1_schnorrsig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h)).
        ///
        /// ## Overview
        ///
        /// BIP-340 Schnorr signatures always have a fixed 64-byte encoding: the 32-byte
        /// `R.x` coordinate of the nonce point followed by the 32-byte scalar `s`. There is
        /// no DER encoding or alternative format. Unlike ECDSA, Schnorr signatures have a
        /// **unique** representation for a given `(message, key, nonce)` triple — there is
        /// no `(r, ±s)` symmetry to normalize.
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:)``
        ///
        /// ### Serialization
        /// - ``dataRepresentation``
        struct SchnorrSignature: ContiguousBytes, DataSignature {
            /// The 64-byte BIP-340 Schnorr signature (`R.x || s` in big-endian).
            ///
            /// Stable wire format suitable for Bitcoin Taproot witnesses, Nostr events, and
            /// any other context consuming BIP-340 signatures. The two 32-byte halves are
            /// the big-endian X-coordinate of the nonce point `R` and the scalar `s`.
            public private(set) var dataRepresentation: Data

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
        /// Generates a BIP-340 Schnorr signature from a pre-computed digest using
        /// `secp256k1_schnorrsig_sign_custom` with fresh 32-byte auxiliary randomness.
        ///
        /// The auxiliary randomness is mixed into the BIP-340 nonce derivation (`secp256k1_nonce_function_bip340`)
        /// to protect against fault attacks. When the digest was produced using BIP-340 Tagged Hashes,
        /// the resulting signature is fully BIP-340 compliant.
        ///
        /// > Note: The digest's raw bytes are passed to `secp256k1_schnorrsig_sign_custom` **at their
        /// > natural length** as the message — BIP-340 (as amended) and the upstream custom signing
        /// > API both accept arbitrary-length messages. This differs from the ECDSA, Recovery, and
        /// > MuSig `Digest` overloads, which reduce the digest to a 32-byte `msg32` per SEC1 §4.1.3
        /// > because their upstream entry points consume exactly 32 bytes.
        ///
        /// - Parameter digest: The pre-computed message digest to sign; signed at its natural byte length.
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: Never throws in practice; `throws` is retained for API stability.
        ///   An upstream signing failure is unreachable on a validated key and would
        ///   report through ``P256K/setInvariantViolationHandler(_:)`` instead.
        public func signature<D: Digest>(for digest: D) throws -> P256K.Schnorr.SchnorrSignature {
            // The generated randomness stays in `SecureBytes` storage — the
            // pointer borrows it for the call rather than copying into a
            // plain array that would be freed unzeroed.
            let auxiliaryRand = SecureBytes(count: P256K.ByteLength.dimension)

            return digest.withUnsafeBytes { message in
                auxiliaryRand.withUnsafeBytes { auxRand in
                    sign(message: message, auxiliaryRand: auxRand)
                }
            }
        }

        /// Generates a BIP-340 Schnorr signature from a pre-computed digest using caller-supplied auxiliary randomness.
        ///
        /// - Parameters:
        ///   - digest: The pre-computed message digest to sign; signed at its natural byte length
        ///     (no `msg32` reduction — the upstream API accepts arbitrary-length messages).
        ///   - auxiliaryRand: Exactly 32 bytes of auxiliary randomness for BIP-340 nonce derivation,
        ///     borrowed read-only for the call. Pass a zeroed 32-byte container to reproduce the
        ///     all-zero-aux behavior (upstream treats a NULL `ndata` as all-zero).
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `auxiliaryRand` is not exactly 32 bytes.
        ///   An upstream signing failure is unreachable on a validated key and would
        ///   report through ``P256K/setInvariantViolationHandler(_:)`` instead.
        public func signature<D: Digest>(for digest: D, auxiliaryRand: some ContiguousBytes) throws -> P256K.Schnorr.SchnorrSignature {
            try auxiliaryRand.withUnsafeBytes { auxRand in
                guard auxRand.count == P256K.ByteLength.dimension else {
                    throw secp256k1Error.incorrectParameterSize
                }
                return digest.withUnsafeBytes { message in
                    sign(message: message, auxiliaryRand: auxRand)
                }
            }
        }

        /// Generates a BIP-340 Schnorr signature over a 32-byte message with fresh auxiliary randomness.
        ///
        /// The fixed 32-byte input is BIP-340's core signing case — Taproot sighashes, Nostr event
        /// ids, and any protocol that signs a message hash. For an arbitrary-length message use
        /// ``signature(customMessage:)`` or ``signature(customMessage:auxiliaryRand:)``
        /// instead, and prefer hashing to 32 bytes — with a BIP-340 tagged hash for domain
        /// separation — unless the signed protocol defines its own separation.
        ///
        /// - Parameter message: The message to sign — exactly 32 bytes.
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `message` is not exactly 32 bytes.
        ///   An upstream signing failure is unreachable on a validated key and would
        ///   report through ``P256K/setInvariantViolationHandler(_:)`` instead.
        public func signature(message: some ContiguousBytes) throws -> P256K.Schnorr.SchnorrSignature {
            try message.withUnsafeBytes { message in
                guard message.count == P256K.ByteLength.dimension else {
                    throw secp256k1Error.incorrectParameterSize
                }
                let auxiliaryRand = SecureBytes(count: P256K.ByteLength.dimension)
                return auxiliaryRand.withUnsafeBytes { auxRand in
                    sign(message: message, auxiliaryRand: auxRand)
                }
            }
        }

        /// Generates a BIP-340 Schnorr signature over a 32-byte message using caller-supplied auxiliary randomness.
        ///
        /// - Parameters:
        ///   - message: The message to sign — exactly 32 bytes.
        ///   - auxiliaryRand: Exactly 32 bytes of auxiliary randomness for BIP-340 nonce derivation,
        ///     borrowed read-only for the call. Pass a zeroed 32-byte container to reproduce the
        ///     all-zero-aux behavior (upstream treats a NULL `ndata` as all-zero).
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `message` or `auxiliaryRand` is not exactly 32 bytes.
        ///   An upstream signing failure is unreachable on a validated key and would
        ///   report through ``P256K/setInvariantViolationHandler(_:)`` instead.
        public func signature(message: some ContiguousBytes, auxiliaryRand: some ContiguousBytes) throws -> P256K.Schnorr.SchnorrSignature {
            try message.withUnsafeBytes { message in
                guard message.count == P256K.ByteLength.dimension else {
                    throw secp256k1Error.incorrectParameterSize
                }
                return try auxiliaryRand.withUnsafeBytes { auxRand in
                    guard auxRand.count == P256K.ByteLength.dimension else {
                        throw secp256k1Error.incorrectParameterSize
                    }
                    return sign(message: message, auxiliaryRand: auxRand)
                }
            }
        }

        /// Generates a Schnorr signature over an arbitrary-length message with fresh auxiliary randomness.
        ///
        /// Wraps `secp256k1_schnorrsig_sign_custom`, which accepts any message length (an empty
        /// message is legal and reaches upstream as `msg = NULL, msglen = 0`). BIP-340 requires
        /// domain separation for non-32-byte messages — prefer hashing to 32 bytes with a tagged
        /// hash and calling ``signature(message:)`` unless the signed protocol defines its own.
        ///
        /// - Parameter customMessage: The message bytes to sign — any length, including zero.
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: Never throws in practice; `throws` is retained for API stability.
        ///   An upstream signing failure is unreachable on a validated key and would
        ///   report through ``P256K/setInvariantViolationHandler(_:)`` instead.
        public func signature(customMessage: some ContiguousBytes) throws -> P256K.Schnorr.SchnorrSignature {
            let auxiliaryRand = SecureBytes(count: P256K.ByteLength.dimension)

            return customMessage.withUnsafeBytes { message in
                auxiliaryRand.withUnsafeBytes { auxRand in
                    sign(message: message, auxiliaryRand: auxRand)
                }
            }
        }

        /// Generates a Schnorr signature over an arbitrary-length message using caller-supplied auxiliary randomness.
        ///
        /// Wraps `secp256k1_schnorrsig_sign_custom`, which accepts any message length (an empty
        /// message is legal and reaches upstream as `msg = NULL, msglen = 0`). BIP-340 requires
        /// domain separation for non-32-byte messages — prefer hashing to 32 bytes with a tagged
        /// hash and calling ``signature(message:auxiliaryRand:)`` unless the signed protocol
        /// defines its own.
        ///
        /// - Parameters:
        ///   - customMessage: The message bytes to sign — any length, including zero.
        ///   - auxiliaryRand: Exactly 32 bytes of auxiliary randomness for BIP-340 nonce derivation,
        ///     borrowed read-only for the call. Pass a zeroed 32-byte container to reproduce the
        ///     all-zero-aux behavior (upstream treats a NULL `ndata` as all-zero).
        /// - Returns: A 64-byte ``SchnorrSignature``.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `auxiliaryRand` is not exactly 32 bytes.
        ///   An upstream signing failure is unreachable on a validated key and would
        ///   report through ``P256K/setInvariantViolationHandler(_:)`` instead.
        public func signature(
            customMessage: some ContiguousBytes,
            auxiliaryRand: some ContiguousBytes
        ) throws -> P256K.Schnorr.SchnorrSignature {
            try auxiliaryRand.withUnsafeBytes { auxRand in
                guard auxRand.count == P256K.ByteLength.dimension else {
                    throw secp256k1Error.incorrectParameterSize
                }
                return customMessage.withUnsafeBytes { message in
                    sign(message: message, auxiliaryRand: auxRand)
                }
            }
        }

        /// The `secp256k1_schnorrsig_sign_custom` call every public signing method funnels into.
        ///
        /// `message` borrows the caller's contiguous storage — an empty buffer's nil
        /// `baseAddress` reaches upstream as `msg = NULL, msglen = 0`, the documented
        /// empty-message call. `auxiliaryRand` becomes `extraparams.ndata`; every call
        /// site supplies a real 32-byte buffer (fresh `SecureBytes` or a caller's
        /// length-checked storage), so the pointer is never NULL.
        private func sign(
            message: UnsafeRawBufferPointer,
            auxiliaryRand: UnsafeRawBufferPointer
        ) -> P256K.Schnorr.SchnorrSignature {
            guard auxiliaryRand.count == P256K.ByteLength.dimension else {
                P256K.invariantFailure(
                    "auxiliaryRand reached the Schnorr signing boundary at \(auxiliaryRand.count) bytes, not 32 — internal routing bug"
                )
            }

            let context = P256K.Context.rawRepresentation
            let magic = P256K.Schnorr.magic
            var keypair = secp256k1_keypair()
            // `secp256k1_keypair` embeds the secret scalar and upstream never
            // zeroes caller-owned memory — scrub the local after its last use
            // rather than leave the residue in the stack frame.
            defer {
                Swift.withUnsafeMutableBytes(of: &keypair) { buffer in
                    _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
                }
            }
            var signature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
            var extraParams = secp256k1_schnorrsig_extraparams(
                magic: magic,
                noncefp: nil,
                ndata: UnsafeMutableRawPointer(mutating: auxiliaryRand.baseAddress)
            )

            let created = key.withUnsafeBytePointer { keyPtr in
                secp256k1_keypair_create(context, &keypair, keyPtr).boolValue
            }
            guard created else {
                P256K.invariantFailure("secp256k1_keypair_create failed in Schnorr signing with validated key — library bug")
            }

            // The keypair was just created from validated key material and no
            // custom nonce function is installed (`noncefp` is nil), so
            // `secp256k1_schnorrsig_sign_custom` cannot legitimately fail.
            guard secp256k1_schnorrsig_sign_custom(
                context,
                &signature,
                message.baseAddress?.assumingMemoryBound(to: UInt8.self),
                message.count,
                &keypair,
                &extraParams
            ).boolValue else {
                P256K.invariantFailure("secp256k1_schnorrsig_sign_custom failed on validated keypair — library bug")
            }

            return P256K.Schnorr.SchnorrSignature(Data(bytes: signature, count: P256K.ByteLength.signature))
        }
    }

    // MARK: - Schnorr + Validating Key

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Schnorr.XonlyKey: DigestValidator {
        /// Verifies a BIP-340 Schnorr signature against a pre-computed digest using `secp256k1_schnorrsig_verify`.
        ///
        /// > Note: The digest's raw bytes are verified as the message **at their natural length**,
        /// > matching the ``P256K/Schnorr/PrivateKey`` `signature(for:)` overloads — there is no
        /// > `msg32` reduction here as there is on the ECDSA and Recovery verification paths.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``SchnorrSignature`` to verify.
        ///   - digest: The pre-computed digest that was signed. Must be the same digest type and data used when signing.
        /// - Returns: `true` if the signature is valid for `digest` under this x-only public key, `false` otherwise.
        public func isValidSignature<D: Digest>(_ signature: P256K.Schnorr.SchnorrSignature, for digest: D) -> Bool {
            var hashDataBytes = Array(digest)

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

            // `bytes` is guaranteed a validated 32-byte coordinate by construction.
            return secp256k1_xonly_pubkey_parse(context, &pubKey, bytes).boolValue &&
                secp256k1_schnorrsig_verify(
                    context,
                    signature.dataRepresentation.byteArray,
                    message,
                    message.count,
                    &pubKey
                ).boolValue
        }
    }

#endif
