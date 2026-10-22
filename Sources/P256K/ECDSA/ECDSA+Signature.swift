//
//  ECDSA+Signature.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public import Foundation
import libsecp256k1

// MARK: - secp256k1 + ECDSA Signature

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing {
    /// 64-byte secp256k1 ECDSA signature in canonical compact wire format (`r || s`
    /// in big-endian), convertible to and from DER (variable-length, up to 72 bytes).
    ///
    /// ## Overview
    ///
    /// All signatures produced by the `signature(for:)` overloads on ``PrivateKey`` are
    /// automatically normalized to lower-S form by `secp256k1_ecdsa_sign` per
    /// [BIP-146](https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki). This
    /// normalization is required because `secp256k1_ecdsa_verify` only accepts lower-S
    /// signatures; a non-normalized signature will always fail verification.
    ///
    /// ``dataRepresentation`` stores the canonical wire bytes — identical to
    /// ``compactRepresentation`` and to CryptoKit's `rawRepresentation` — so it is a
    /// stable format suitable for persistence and transmission. The upstream
    /// `secp256k1_ecdsa_signature` object is rebuilt from these bytes at each point
    /// of use rather than stored.
    ///
    /// ## Topics
    ///
    /// ### Construction
    /// - ``init(dataRepresentation:)``
    /// - ``init(compactRepresentation:)``
    /// - ``init(derRepresentation:)``
    ///
    /// ### Serialized Forms
    /// - ``compactRepresentation``
    /// - ``derRepresentation``
    struct ECDSASignature: ContiguousBytes, NISTECDSASignature, CompactSignature {
        /// The 64-byte canonical wire representation: `r || s` in big-endian.
        ///
        /// This is the same form ``compactRepresentation`` returns — a stable,
        /// portable encoding suitable for persistence and transmission, identical
        /// to CryptoKit's `rawRepresentation`. Every value is validated at
        /// construction time by `secp256k1_ecdsa_signature_parse_compact` — `r`
        /// and `s` must be below the curve order — so a well-formed
        /// ``ECDSASignature`` always parses cleanly. The upstream
        /// `secp256k1_ecdsa_signature` object is rebuilt at each point of use
        /// rather than stored.
        public private(set) var dataRepresentation: Data

        /// Creates an ``ECDSASignature`` from the canonical 64-byte wire form
        /// (`r || s` in big-endian).
        ///
        /// - Parameter dataRepresentation: Exactly 64 bytes in compact format (`r || s` in big-endian).
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count is not 64;
        ///   ``secp256k1Error/underlyingCryptoError`` if `r` or `s` is at or above the curve order.
        public init<D: DataProtocol>(dataRepresentation: D) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            var signature = secp256k1_ecdsa_signature()

            guard secp256k1_ecdsa_signature_parse_compact(
                P256K.Context.rawRepresentation,
                &signature,
                Array(dataRepresentation)
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.dataRepresentation = Data(dataRepresentation)
        }

        /// Initializes ECDSASignature from pre-validated canonical `r || s` bytes.
        /// - Parameters:
        ///   - dataRepresentation: A data representation of the signature as a collection of contiguous bytes.
        /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature`.
        init(_ dataRepresentation: Data) {
            precondition(dataRepresentation.count == P256K.ByteLength.signature, "Invalid ECDSA signature size")
            self.dataRepresentation = dataRepresentation
        }

        /// Creates an ``ECDSASignature`` by parsing a DER-encoded ECDSA signature via `secp256k1_ecdsa_signature_parse_der`.
        ///
        /// - Parameter derRepresentation: A valid DER-encoded ECDSA signature (typically up to 72 bytes).
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if DER parsing fails.
        public init<D: DataProtocol>(derRepresentation: D) throws {
            let context = P256K.Context.rawRepresentation
            let derSignatureBytes = Array(derRepresentation)
            var signature = secp256k1_ecdsa_signature()
            var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)

            guard secp256k1_ecdsa_signature_parse_der(
                context,
                &signature,
                derSignatureBytes,
                derSignatureBytes.count
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            // A DER parse that succeeded yields in-range scalars, so the compact
            // re-serialization is infallible.
            guard secp256k1_ecdsa_signature_serialize_compact(
                context,
                &compactSignature,
                &signature
            ).boolValue else {
                P256K.invariantFailure("secp256k1_ecdsa_signature_serialize_compact failed on parsed signature — library bug")
            }

            self.dataRepresentation = Data(compactSignature)
        }

        /// Creates an ``ECDSASignature`` by parsing a 64-byte compact representation via `secp256k1_ecdsa_signature_parse_compact`.
        ///
        /// The compact representation is exactly the canonical wire form stored in
        /// ``dataRepresentation``, so this is equivalent to ``init(dataRepresentation:)``.
        ///
        /// - Parameter compactRepresentation: Exactly 64 bytes in compact format (`r || s` in big-endian).
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `compactRepresentation` is not exactly
        ///   64 bytes; ``secp256k1Error/underlyingCryptoError`` if `r` or `s` is at or above the curve order.
        public init<D: DataProtocol>(compactRepresentation: D) throws {
            try self.init(dataRepresentation: compactRepresentation)
        }

        /// Calls `body` with an unsafe pointer to the signature's raw bytes.
        ///
        /// - Parameter body: A closure receiving a raw buffer pointer over the 64-byte signature data.
        /// - Returns: The value returned by `body`.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }

        /// The 64-byte compact representation of the signature (`r || s` in big-endian).
        ///
        /// Stable wire format suitable for Bitcoin witness fields, Nostr events, and other
        /// contexts that expect a fixed-length signature. The two 32-byte halves are the
        /// big-endian encodings of the `r` and `s` scalars respectively — identical to
        /// the stored ``dataRepresentation``, which is already this canonical wire form.
        public var compactRepresentation: Data {
            dataRepresentation
        }

        /// The variable-length DER-encoded representation of the signature (up to 72
        /// bytes), produced by `secp256k1_ecdsa_signature_serialize_der`.
        ///
        /// ASN.1 DER encoding defined by SEC1 § 4.1 — the standard wire format for ECDSA
        /// signatures in TLS, X.509 certificates, and pre-SegWit Bitcoin script. Typical
        /// output is 70–72 bytes; the upper bound of 72 reflects the maximum DER length
        /// including two `INTEGER` tags and length octets.
        public var derRepresentation: Data {
            let context = P256K.Context.rawRepresentation
            var signature = secp256k1_ecdsa_signature()
            var derSignatureLength = 80
            var derSignature = [UInt8](repeating: 0, count: derSignatureLength)

            // Stored bytes were validated by `parse_compact` at init, so the
            // re-parse is infallible in practice; a failure indicates memory
            // corruption or an upstream defect, not bad input.
            guard secp256k1_ecdsa_signature_parse_compact(
                context,
                &signature,
                Array(dataRepresentation)
            ).boolValue else {
                P256K.invariantFailure("secp256k1_ecdsa_signature_parse_compact failed on init-validated bytes — library bug")
            }
            guard secp256k1_ecdsa_signature_serialize_der(
                context,
                &derSignature,
                &derSignatureLength,
                &signature
            ).boolValue else {
                P256K.invariantFailure("secp256k1_ecdsa_signature_serialize_der failed on init-validated bytes — library bug")
            }

            return Data(bytes: &derSignature, count: derSignatureLength)
        }
    }
}

// MARK: - secp256k1 + Signing Key

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Signing.PrivateKey: DigestSigner {
    /// Generates a lower-S normalized ECDSA signature over the secp256k1 elliptic curve using RFC 6979 deterministic nonce generation.
    ///
    /// Digests of any length are accepted: the digest is reduced to the 32-byte
    /// `msg32` value per SEC1 §4.1.3 — the leftmost 32 bytes for longer digests,
    /// the integer value (left-padded with zeros) for shorter ones.
    ///
    /// - Parameter digest: The pre-computed message digest to sign.
    /// - Returns: An ``ECDSASignature`` in lower-S normalized form, ready for verification via the `isValidSignature(_:for:)` overloads on ``P256K/Signing/PublicKey``.
    public func signature<D: Digest>(for digest: D) -> P256K.Signing.ECDSASignature {
        let context = P256K.Context.rawRepresentation
        let digestBytes = digest.msg32Bytes
        var signature = secp256k1_ecdsa_signature()
        var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)

        guard secp256k1_ecdsa_sign(
            context,
            &signature,
            digestBytes,
            Array(dataRepresentation),
            nil,
            nil
        ).boolValue else {
            P256K.invariantFailure("secp256k1_ecdsa_sign failed with valid key — library bug")
        }

        guard secp256k1_ecdsa_signature_serialize_compact(
            context,
            &compactSignature,
            &signature
        ).boolValue else {
            P256K.invariantFailure("secp256k1_ecdsa_signature_serialize_compact failed — library bug")
        }

        return P256K.Signing.ECDSASignature(Data(compactSignature))
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Signing.PrivateKey: Signer {
    /// Generates a lower-S normalized ECDSA signature by first hashing `data` with SHA-256, then signing with `secp256k1_ecdsa_sign`.
    ///
    /// - Parameter data: The message bytes to hash and sign.
    /// - Returns: An ``ECDSASignature`` in lower-S normalized form.
    public func signature<D: DataProtocol>(for data: D) -> P256K.Signing.ECDSASignature {
        signature(for: SHA256.hash(data: data))
    }
}

// MARK: - secp256k1 + Validating Key

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Signing.PublicKey: DigestValidator {
    /// Verifies an ECDSA signature against a pre-computed digest using `secp256k1_ecdsa_verify`, which requires the signature to be in lower-S normalized form.
    ///
    /// Digests of any length are accepted: the digest is reduced to the 32-byte
    /// `msg32` value per SEC1 §4.1.3 — the leftmost 32 bytes for longer digests,
    /// the integer value (left-padded with zeros) for shorter ones — so a
    /// signature produced by a signer that applies the same standard reduction
    /// verifies as `true`.
    ///
    /// - Parameters:
    ///   - signature: The ``ECDSASignature`` to verify; must be in lower-S normalized form.
    ///   - digest: The digest that was signed.
    /// - Returns: `true` if the signature is valid for `digest` under this public key, `false` otherwise.
    public func isValidSignature<D: Digest>(_ signature: P256K.Signing.ECDSASignature, for digest: D) -> Bool {
        let context = P256K.Context.rawRepresentation
        let digestBytes = digest.msg32Bytes
        var ecdsaSignature = secp256k1_ecdsa_signature()
        var publicKey = baseKey.rawRepresentation

        // Stored signature bytes were validated at init, so this re-parse cannot
        // fail; a failure would fail closed as an unverifiable signature.
        guard secp256k1_ecdsa_signature_parse_compact(
            context,
            &ecdsaSignature,
            signature.dataRepresentation.bytes
        ).boolValue else {
            return false
        }

        return secp256k1_ecdsa_verify(context, &ecdsaSignature, digestBytes, &publicKey).boolValue
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Signing.PublicKey: DataValidator {
    /// Verifies an ECDSA signature by first hashing `data` with SHA-256, then calling `secp256k1_ecdsa_verify`.
    ///
    /// - Parameters:
    ///   - signature: The ``ECDSASignature`` to verify; must be in lower-S normalized form.
    ///   - data: The original message bytes whose SHA-256 hash was signed.
    /// - Returns: `true` if the signature is valid, `false` otherwise.
    public func isValidSignature<D: DataProtocol>(_ signature: P256K.Signing.ECDSASignature, for data: D) -> Bool {
        isValidSignature(signature, for: SHA256.hash(data: data))
    }
}
