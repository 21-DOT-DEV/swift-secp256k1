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
    /// 64-byte secp256k1 ECDSA signature in libsecp256k1 internal format, convertible to and from DER (variable-length, up to 72 bytes) and compact (exactly 64 bytes) representations.
    ///
    /// All signatures produced by ``PrivateKey/signature(for:)-2bdso`` are automatically normalized
    /// to lower-S form by `secp256k1_ecdsa_sign`. This normalization is required because
    /// `secp256k1_ecdsa_verify` only accepts lower-S signatures; a non-normalized signature will
    /// always fail verification.
    ///
    /// ## Serialization
    ///
    /// - ``compactRepresentation``: 64 bytes, `r || s` in big-endian. Use for Bitcoin witness
    ///   fields and Nostr events.
    /// - ``derRepresentation``: Variable-length DER encoding (up to 72 bytes). Use for
    ///   Bitcoin legacy script and standard X.509 / TLS contexts.
    struct ECDSASignature: ContiguousBytes, NISTECDSASignature, CompactSignature {
        /// The 64-byte libsecp256k1 internal representation of the signature (`r || s` in big-endian).
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

        /// The 64-byte compact representation of the signature (`r || s` in big-endian), produced by `secp256k1_ecdsa_signature_serialize_compact`.
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

        /// The variable-length DER-encoded representation of the signature (up to 72 bytes), produced by `secp256k1_ecdsa_signature_serialize_der`.
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
    /// - Returns: An ``ECDSASignature`` in lower-S normalized form, ready for verification by ``P256K/Signing/PublicKey/isValidSignature(_:for:)-6vcl1``.
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
