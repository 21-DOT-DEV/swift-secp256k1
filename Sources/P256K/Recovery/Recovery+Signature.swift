//
//  Recovery+Signature.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public import Foundation
import libsecp256k1

#if Xcode || ENABLE_MODULE_RECOVERY

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Recovery {
        /// A 64-byte compact ECDSA signature paired with its 1-byte recovery ID, as
        /// produced by `secp256k1_ecdsa_recoverable_signature_serialize_compact` (declared
        /// in
        /// [`secp256k1/include/secp256k1_recovery.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_recovery.h)).
        ///
        /// This is the canonical wire format for Bitcoin signed-message payloads
        /// ([BIP-137](https://github.com/bitcoin/bips/blob/master/bip-0137.mediawiki),
        /// [BIP-322](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki)):
        /// 64 bytes of ECDSA compact signature plus 1 separate byte for the recovery ID.
        ///
        /// ## Topics
        ///
        /// ### Fields
        /// - ``signature``
        /// - ``recoveryId``
        struct ECDSACompactSignature {
            /// The 64-byte compact ECDSA signature (`r || s`, big-endian).
            ///
            /// Same byte layout as ``P256K/Signing/ECDSASignature/compactRepresentation`` —
            /// pair with ``recoveryId`` to transmit both halves separately, or concatenate
            /// as `signature || UInt8(recoveryId)` for the 65-byte combined form used by
            /// Bitcoin signed-message workflows.
            public let signature: Data

            /// The recovery ID (`0–3`) that identifies which of the possible public keys
            /// corresponds to the signer.
            ///
            /// For any valid `(message, signature)` pair there are up to four candidate
            /// public keys that satisfy the verification equation. The signer records the
            /// correct one as this 2-bit value (stored as `Int32` for easy upstream API
            /// interop). Values `≥ 4` are invalid and reflect a corrupted signature.
            public let recoveryId: Int32
        }

        /// 65-byte secp256k1 ECDSA recoverable signature (64-byte compact form + 1-byte
        /// recovery ID) produced by `secp256k1_ecdsa_sign_recoverable` using
        /// [RFC 6979](https://datatracker.ietf.org/doc/html/rfc6979) deterministic nonces.
        ///
        /// ## Overview
        ///
        /// A recoverable signature allows ``PublicKey`` to be reconstructed from the
        /// message hash alone via `secp256k1_ecdsa_recover`. Successful recovery guarantees
        /// the signature would pass `secp256k1_ecdsa_verify` **after normalization**;
        /// however, converting the signature to a non-recoverable form via ``normalize``
        /// does **not** automatically normalize it. Call
        /// `secp256k1_ecdsa_signature_normalize` on the result of ``normalize`` if lower-S
        /// normalized form is required for standard ECDSA verification per
        /// [BIP-146](https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki).
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:)``
        /// - ``init(compactRepresentation:recoveryId:)``
        ///
        /// ### Serialization
        /// - ``dataRepresentation``
        /// - ``compactRepresentation``
        ///
        /// ### Conversion
        /// - ``normalize``
        struct ECDSASignature: ContiguousBytes, DataSignature {
            /// The 65-byte canonical wire representation: `r || s` in big-endian
            /// (64 bytes) followed by the 1-byte recovery ID.
            ///
            /// This is the same `signature || UInt8(recoveryId)` concatenation described
            /// on ``ECDSACompactSignature`` for Bitcoin signed-message workflows
            /// ([BIP-137](https://github.com/bitcoin/bips/blob/master/bip-0137.mediawiki),
            /// [BIP-322](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki)), and is a stable, portable
            /// format suitable for persistence and transmission. Every value is
            /// validated at construction time — `r` and `s` must be below the curve
            /// order and the recovery ID must be in `0...3` — so a well-formed
            /// ``ECDSASignature`` always parses cleanly. The upstream
            /// `secp256k1_ecdsa_recoverable_signature` object is rebuilt through
            /// `secp256k1_ecdsa_recoverable_signature_parse_compact` at each point of
            /// use rather than stored.
            public private(set) var dataRepresentation: Data

            /// The 64-byte compact serialization and 1-byte recovery ID, matching the output of `secp256k1_ecdsa_recoverable_signature_serialize_compact`.
            ///
            /// The stored ``dataRepresentation`` is already this wire form, so the
            /// accessor splits it without an upstream call.
            public var compactRepresentation: ECDSACompactSignature {
                P256K.Recovery.ECDSACompactSignature(
                    signature: dataRepresentation.prefix(P256K.ByteLength.signature),
                    recoveryId: Int32(dataRepresentation.last ?? 0)
                )
            }

            /// Converts this recoverable signature to a standard ``P256K/Signing/ECDSASignature`` via `secp256k1_ecdsa_recoverable_signature_convert`.
            ///
            /// > Important: The converted signature is **not guaranteed to be lower-S normalized**
            /// > and may fail `secp256k1_ecdsa_verify`. If normalized form is required, pass the
            /// > result through `secp256k1_ecdsa_signature_normalize` before verifying.
            ///
            /// - Returns: A ``P256K/Signing/ECDSASignature`` holding the converted
            ///   (non-recoverable) signature. Lower-S normalization is **not** applied.
            public var normalize: P256K.Signing.ECDSASignature {
                let context = P256K.Context.rawRepresentation
                var normalizedSignature = secp256k1_ecdsa_signature()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()
                var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)

                // Stored bytes are validated at init, so the re-parse is
                // infallible in practice; a failure indicates memory corruption
                // or an upstream defect, not bad input.
                guard secp256k1_ecdsa_recoverable_signature_parse_compact(
                    context,
                    &recoverableSignature,
                    Array(dataRepresentation.prefix(P256K.ByteLength.signature)),
                    Int32(dataRepresentation[P256K.ByteLength.signature])
                ).boolValue,
                    secp256k1_ecdsa_recoverable_signature_convert(
                        context,
                        &normalizedSignature,
                        &recoverableSignature
                    ).boolValue,
                    secp256k1_ecdsa_signature_serialize_compact(
                        context,
                        &compactSignature,
                        &normalizedSignature
                    ).boolValue else {
                    P256K.invariantFailure("secp256k1_ecdsa_recoverable_signature_parse_compact failed on init-validated bytes — library bug")
                }

                return P256K.Signing.ECDSASignature(Data(compactSignature))
            }

            /// Creates an ``ECDSASignature`` from the canonical 65-byte wire form
            /// (`r || s` big-endian + 1-byte recovery ID).
            ///
            /// The bytes are validated by
            /// `secp256k1_ecdsa_recoverable_signature_parse_compact`: `r` and `s`
            /// must be below the curve order and the recovery ID must be in `0...3`.
            ///
            /// - Parameter dataRepresentation: Exactly 65 bytes (`P256K.ByteLength.signature + 1`) in the canonical `r || s || recoveryId` wire format.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count is not 65;
            ///   ``secp256k1Error/underlyingCryptoError`` if the recovery ID is out of range or `r`/`s` overflow the curve order.
            public init<D: DataProtocol>(dataRepresentation: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature + 1 else {
                    throw secp256k1Error.incorrectParameterSize
                }

                let signatureBytes = Array(dataRepresentation)
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

                // The recovery ID range check must precede the parse call:
                // upstream's `ARG_CHECK(recid >= 0 && recid <= 3)` invokes the
                // default illegal-argument callback, which aborts the process
                // (see bitcoin-core/secp256k1#751).
                guard signatureBytes[P256K.ByteLength.signature] <= 3,
                      secp256k1_ecdsa_recoverable_signature_parse_compact(
                          P256K.Context.rawRepresentation,
                          &recoverableSignature,
                          Array(signatureBytes.prefix(P256K.ByteLength.signature)),
                          Int32(signatureBytes[P256K.ByteLength.signature])
                      ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.dataRepresentation = Data(signatureBytes)
            }

            /// Creates an ``ECDSASignature`` from a pre-validated 65-byte wire-format data value.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature + 1` (65) and hold validated `r || s || recoveryId` bytes.
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature + 1, "Invalid recoverable signature size")
                self.dataRepresentation = dataRepresentation
            }

            /// Creates an ``ECDSASignature`` from a 64-byte compact representation and recovery ID, validated by `secp256k1_ecdsa_recoverable_signature_parse_compact`.
            ///
            /// - Parameter compactRepresentation: The 64-byte compact ECDSA signature (`r || s`).
            /// - Parameter recoveryId: The recovery ID (0–3) from the original signing operation.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `compactRepresentation` is not exactly 64 bytes;
            ///   ``secp256k1Error/underlyingCryptoError`` if `recoveryId` is out of range or `r`/`s` overflow the curve order.
            public init<D: DataProtocol>(compactRepresentation: D, recoveryId: Int32) throws {
                guard compactRepresentation.count == P256K.ByteLength.signature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                // The recovery ID range check must precede the parse call:
                // upstream's `ARG_CHECK(recid >= 0 && recid <= 3)` invokes the
                // default illegal-argument callback, which aborts the process
                // (see bitcoin-core/secp256k1#751).
                guard (0...3).contains(recoveryId) else {
                    throw secp256k1Error.underlyingCryptoError
                }

                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

                guard secp256k1_ecdsa_recoverable_signature_parse_compact(
                    P256K.Context.rawRepresentation,
                    &recoverableSignature,
                    Array(compactRepresentation),
                    recoveryId
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.dataRepresentation = Data(compactRepresentation) + [UInt8(recoveryId)]
            }

            /// Calls `body` with an unsafe pointer to the signature's 65 raw bytes.
            ///
            /// - Parameter body: A closure receiving a raw buffer pointer over the signature data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

    // MARK: - secp256k1 + Recovery

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Recovery.PrivateKey: DigestSigner {
        /// The signature type produced by signing with this private key.
        public typealias Signature = P256K.Recovery.ECDSASignature

        /// Generates a recoverable ECDSA signature from a pre-computed digest via `secp256k1_ecdsa_sign_recoverable` with RFC 6979 deterministic nonce generation.
        ///
        /// Digests of any length are accepted: the digest is reduced to the 32-byte
        /// `msg32` value per SEC1 §4.1.3 — the leftmost 32 bytes for longer digests,
        /// the integer value (left-padded with zeros) for shorter ones.
        ///
        /// - Parameter digest: The pre-computed message digest to sign.
        /// - Returns: A 65-byte ``ECDSASignature`` from which the signer's ``PublicKey`` can be recovered.
        public func signature<D: Digest>(for digest: D) -> Signature {
            let context = P256K.Context.rawRepresentation
            let digestBytes = digest.msg32Bytes
            var signature = secp256k1_ecdsa_recoverable_signature()
            var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
            var recoveryId = Int32()

            let signed = key.withUnsafeBytePointer { keyPtr in
                secp256k1_ecdsa_sign_recoverable(
                    context,
                    &signature,
                    digestBytes,
                    keyPtr,
                    nil,
                    nil
                ).boolValue
            }
            guard signed else {
                P256K.invariantFailure("secp256k1_ecdsa_sign_recoverable failed with valid key — library bug")
            }

            guard secp256k1_ecdsa_recoverable_signature_serialize_compact(
                context,
                &compactSignature,
                &recoveryId,
                &signature
            ).boolValue else {
                P256K.invariantFailure("secp256k1_ecdsa_recoverable_signature_serialize_compact failed — library bug")
            }

            return P256K.Recovery.ECDSASignature(Data(compactSignature) + [UInt8(recoveryId)])
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Recovery.PrivateKey: Signer {
        /// Generates a recoverable ECDSA signature by SHA-256 hashing `data` then calling `secp256k1_ecdsa_sign_recoverable`.
        ///
        /// - Parameter data: The message to sign; hashed with SHA-256 before signing.
        /// - Returns: A 65-byte ``ECDSASignature`` from which the signer's ``PublicKey`` can be recovered.
        public func signature<D: DataProtocol>(for data: D) -> Signature {
            signature(for: SHA256.hash(data: data))
        }
    }

#endif
