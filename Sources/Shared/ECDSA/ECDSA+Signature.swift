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

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

// MARK: - secp256k1 + ECDSA Signature

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing {
    /// 64-byte secp256k1 ECDSA signature in libsecp256k1 internal format, convertible to and
    /// from DER (variable-length, up to 72 bytes) and compact (exactly 64 bytes)
    /// representations.
    ///
    /// ## Overview
    ///
    /// All signatures produced by the `signature(for:)` overloads on ``PrivateKey`` are
    /// automatically normalized to lower-S form by `secp256k1_ecdsa_sign` per
    /// [BIP-146](https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki). This
    /// normalization is required because `secp256k1_ecdsa_verify` only accepts lower-S
    /// signatures; a non-normalized signature will always fail verification.
    ///
    /// The internal 64-byte `data` buffer is the opaque `secp256k1_ecdsa_signature` struct
    /// body declared in
    /// [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h).
    /// Its byte layout is **not** a stable wire format across libsecp256k1 versions — use
    /// ``compactRepresentation`` or ``derRepresentation`` for persistence / transmission.
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
        /// The 64-byte opaque `secp256k1_ecdsa_signature` struct buffer.
        ///
        /// The internal layout is not a stable wire format — use ``compactRepresentation``
        /// or ``derRepresentation`` for cross-process persistence. The bytes here are
        /// retained across Swift-layer operations to avoid repeat parsing; the upstream
        /// struct stores the `(r, s)` pair in a version-specific packed form.
        public var dataRepresentation: Data

        /// Creates an ``ECDSASignature`` from a 64-byte raw representation.
        ///
        /// - Parameter dataRepresentation: Exactly 64 bytes in libsecp256k1 internal format (`r || s`).
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count is not 64.
        public init<D: DataProtocol>(dataRepresentation: D) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = Data(dataRepresentation)
        }

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
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

            guard secp256k1_ecdsa_signature_parse_der(
                context,
                &signature,
                derSignatureBytes,
                derSignatureBytes.count
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.dataRepresentation = signature.dataValue
        }

        /// Creates an ``ECDSASignature`` by parsing a 64-byte compact representation via `secp256k1_ecdsa_signature_parse_compact`.
        ///
        /// - Parameter compactRepresentation: Exactly 64 bytes in compact format (`r || s` in big-endian).
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if parsing fails.
        public init<D: DataProtocol>(compactRepresentation: D) throws {
            let context = P256K.Context.rawRepresentation
            var signature = secp256k1_ecdsa_signature()

            guard secp256k1_ecdsa_signature_parse_compact(
                context,
                &signature,
                Array(compactRepresentation)
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.dataRepresentation = signature.dataValue
        }

        /// Calls `body` with an unsafe pointer to the signature's raw bytes.
        ///
        /// - Parameter body: A closure receiving a raw buffer pointer over the 64-byte signature data.
        /// - Returns: The value returned by `body`.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }

        /// The 64-byte compact representation of the signature (`r || s` in big-endian),
        /// produced by `secp256k1_ecdsa_signature_serialize_compact`.
        ///
        /// Stable wire format suitable for Bitcoin witness fields, Nostr events, and other
        /// contexts that expect a fixed-length signature. The two 32-byte halves are the
        /// big-endian encodings of the `r` and `s` scalars respectively.
        public var compactRepresentation: Data {
            let context = P256K.Context.rawRepresentation
            var signature = secp256k1_ecdsa_signature()
            var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)

            dataRepresentation.copyToUnsafeMutableBytes(of: &signature.data)

            guard secp256k1_ecdsa_signature_serialize_compact(
                context,
                &compactSignature,
                &signature
            ).boolValue else {
                fatalError("secp256k1_ecdsa_signature_serialize_compact failed with valid signature — library bug")
            }

            return Data(bytes: &compactSignature, count: P256K.ByteLength.signature)
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

            dataRepresentation.copyToUnsafeMutableBytes(of: &signature.data)

            guard secp256k1_ecdsa_signature_serialize_der(
                context,
                &derSignature,
                &derSignatureLength,
                &signature
            ).boolValue else {
                fatalError("secp256k1_ecdsa_signature_serialize_der failed with valid signature — library bug")
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
    /// - Parameter digest: The pre-computed message digest to sign.
    /// - Returns: An ``ECDSASignature`` in lower-S normalized form, ready for verification via the `isValidSignature(_:for:)` overloads on ``P256K/Signing/PublicKey``.
    public func signature<D: Digest>(for digest: D) -> P256K.Signing.ECDSASignature {
        let context = P256K.Context.rawRepresentation
        var signature = secp256k1_ecdsa_signature()

        guard secp256k1_ecdsa_sign(
            context,
            &signature,
            Array(digest),
            Array(dataRepresentation),
            nil,
            nil
        ).boolValue else {
            fatalError("secp256k1_ecdsa_sign failed with valid key — library bug")
        }

        return P256K.Signing.ECDSASignature(signature.dataValue)
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
    /// - Parameters:
    ///   - signature: The ``ECDSASignature`` to verify; must be in lower-S normalized form.
    ///   - digest: The digest that was signed.
    /// - Returns: `true` if the signature is valid for `digest` under this public key, `false` otherwise.
    public func isValidSignature<D: Digest>(_ signature: P256K.Signing.ECDSASignature, for digest: D) -> Bool {
        let context = P256K.Context.rawRepresentation
        var ecdsaSignature = secp256k1_ecdsa_signature()
        var publicKey = baseKey.rawRepresentation

        signature.dataRepresentation.copyToUnsafeMutableBytes(of: &ecdsaSignature.data)

        return secp256k1_ecdsa_verify(context, &ecdsaSignature, Array(digest), &publicKey).boolValue
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
