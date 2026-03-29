//
//  ECDSA+PublicKey.swift
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

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing {
    /// secp256k1 ECDSA public key for verifying ``ECDSASignature`` values, available in compressed (33-byte) or uncompressed (65-byte) serialized form.
    ///
    /// Obtain a public key from its companion ``PrivateKey/publicKey`` property, or by deserializing
    /// a compressed (33-byte), uncompressed (65-byte), PEM, DER, or ANSI X9.63 representation.
    /// The serialization format is preserved and reported by the ``format`` property.
    struct PublicKey: Sendable {
        /// The internal backing public key implementation.
        let baseKey: PublicKeyImplementation

        /// The serialized public key bytes in the key's ``format``.
        var bytes: [UInt8] {
            baseKey.bytes
        }

        /// The serialized public key bytes as `Data`, in the key's ``format``.
        public var dataRepresentation: Data {
            baseKey.dataRepresentation
        }

        /// The 32-byte x-only public key (X coordinate only) derived from this key for use with Schnorr signature verification.
        public var xonly: XonlyKey {
            XonlyKey(baseKey: baseKey.xonly)
        }

        /// The serialization format of this public key: `.compressed` (33 bytes) or `.uncompressed` (65 bytes).
        public var format: P256K.Format {
            baseKey.format
        }

        /// A new ``PublicKey`` that is the additive inverse of this key on the secp256k1 curve, produced by `secp256k1_ec_pubkey_negate`.
        public var negation: Self {
            Self(baseKey: baseKey.negation)
        }

        /// The 65-byte uncompressed serialization of this public key (0x04 prefix + 32-byte X + 32-byte Y), regardless of the key's stored ``format``.
        public var uncompressedRepresentation: Data {
            baseKey.uncompressedRepresentation
        }

        /// Creates a public key from a validated backing implementation.
        init(baseKey: PublicKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Creates a compressed secp256k1 public key from an x-only key by prepending the 0x02 (even-Y) or 0x03 (odd-Y) parity prefix.
        ///
        /// - Parameter xonlyKey: The x-only public key to convert.
        public init(xonlyKey: XonlyKey) {
            let key = XonlyKeyImplementation(
                dataRepresentation: xonlyKey.bytes,
                keyParity: xonlyKey.parity ? 1 : 0
            )
            self.baseKey = PublicKeyImplementation(xonlyKey: key)
        }

        /// Creates a secp256k1 public key from serialized bytes.
        ///
        /// - Parameter data: Serialized public key bytes whose length must match `format.length`.
        /// - Parameter format: The serialization format of `data` (`.compressed` for 33 bytes, `.uncompressed` for 65 bytes).
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if parsing via `secp256k1_ec_pubkey_parse` fails.
        public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format) throws {
            self.baseKey = try PublicKeyImplementation(dataRepresentation: data, format: format)
        }

        /// Creates a secp256k1 public key for signing from a Privacy-Enhanced Mail (PEM) representation.
        ///
        /// - Parameters:
        ///   - pemRepresentation: A PEM representation of the key.
        public init(pemRepresentation: String) throws {
            let pem = try ASN1.PEMDocument(pemString: pemRepresentation)
            guard pem.type == "PUBLIC KEY" else {
                throw CryptoKitASN1Error.invalidPEMDocument
            }
            self = try .init(derRepresentation: pem.derBytes)
        }

        /// Creates a secp256k1 public key for signing from a Distinguished Encoding Rules (DER) encoded representation.
        ///
        /// - Parameters:
        ///   - derRepresentation: A DER-encoded representation of the key.
        public init<Bytes: RandomAccessCollection>(derRepresentation: Bytes) throws where Bytes.Element == UInt8 {
            let bytes = Array(derRepresentation)
            let parsed = try ASN1.SubjectPublicKeyInfo(asn1Encoded: bytes)
            self = try .init(x963Representation: parsed.key)
        }

        /// Creates a secp256k1 public key from an ANSI X9.63 representation.
        ///
        /// - Parameter x963Representation: 33 bytes for compressed or 65 bytes for uncompressed format; the byte-length determines the ``format`` automatically.
        /// - Throws: `CryptoKitError.incorrectParameterSize` if the length is neither 33 nor 65 bytes; ``secp256k1Error/underlyingCryptoError`` if parsing fails.
        public init<Bytes: ContiguousBytes>(x963Representation: Bytes) throws {
            let length = x963Representation.withUnsafeBytes { $0.count }

            switch length {
            case P256K.ByteLength.dimension + 1:
                self.baseKey = try PublicKeyImplementation(dataRepresentation: x963Representation, format: .compressed)

            case (2 * P256K.ByteLength.dimension) + 1:
                self.baseKey = try PublicKeyImplementation(dataRepresentation: x963Representation, format: .uncompressed)

            default:
                throw CryptoKitError.incorrectParameterSize
            }
        }
    }
}
