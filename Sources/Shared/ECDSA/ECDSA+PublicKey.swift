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
    /// secp256k1 ECDSA public key for verifying ``ECDSASignature`` values, available in
    /// compressed (33-byte) or uncompressed (65-byte) serialized form.
    ///
    /// ## Overview
    ///
    /// Obtain a public key from its companion ``PrivateKey/publicKey`` property, or by
    /// deserializing a compressed (33-byte), uncompressed (65-byte), PEM, DER, or ANSI
    /// X9.63 representation. The serialization format is preserved and reported by the
    /// ``format`` property. Parsing goes through `secp256k1_ec_pubkey_parse` (declared in
    /// [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h)),
    /// which rejects off-curve points and wrong-length encodings.
    ///
    /// ## Topics
    ///
    /// ### Construction
    /// - ``init(dataRepresentation:format:)``
    /// - ``init(xonlyKey:)``
    /// - ``init(pemRepresentation:)``
    /// - ``init(derRepresentation:)``
    /// - ``init(x963Representation:)``
    ///
    /// ### Serialized Forms
    /// - ``dataRepresentation``
    /// - ``uncompressedRepresentation``
    /// - ``format``
    /// - ``xonly``
    ///
    /// ### Algebra
    /// - ``negation``
    struct PublicKey: Sendable {
        /// The internal `PublicKeyImplementation` backing this verifying key.
        ///
        /// Kept `internal` — the backing type wraps the 64-byte upstream `secp256k1_pubkey`
        /// struct plus the serialization format; consumers never see the raw C handle
        /// through the public API.
        let baseKey: PublicKeyImplementation

        /// The serialized public key bytes in the key's ``format``.
        ///
        /// Internal-visibility accessor used by Swift-side verify helpers that want to
        /// avoid the `Data` allocation; external callers use ``dataRepresentation`` for
        /// the `Data` form.
        var bytes: [UInt8] {
            baseKey.bytes
        }

        /// The serialized public key bytes as `Data`, in the key's ``format``.
        ///
        /// Suitable for transmission and persistence. Produced via
        /// `secp256k1_ec_pubkey_serialize` with the flag corresponding to the stored
        /// ``format`` (see ``P256K/Format/rawValue``).
        public var dataRepresentation: Data {
            baseKey.dataRepresentation
        }

        /// The 32-byte x-only public key (X coordinate only) derived from this key for use
        /// with Schnorr signature verification.
        ///
        /// Computed on every access via `secp256k1_xonly_pubkey_from_pubkey`. Useful when a
        /// workflow needs to pivot from ECDSA-era verification to Taproot-era BIP-340
        /// verification against the same underlying public point.
        public var xonly: XonlyKey {
            XonlyKey(baseKey: baseKey.xonly)
        }

        /// The serialization format of this public key: `.compressed` (33 bytes) or
        /// `.uncompressed` (65 bytes).
        ///
        /// Inherited from the `format:` argument at construction time. See
        /// ``P256K/Format`` for the SEC1 encoding details and upstream `#define` mapping.
        public var format: P256K.Format {
            baseKey.format
        }

        /// A new ``PublicKey`` that is the additive inverse of this key on the secp256k1
        /// curve, produced by `secp256k1_ec_pubkey_negate`.
        ///
        /// The inverse is the point `-P = (x, -y mod p)`: same X coordinate, flipped Y
        /// parity. Satisfies `self + negation` is the point at infinity. Used in BIP-32
        /// derivation schemes and in manual verification of aggregation properties.
        public var negation: Self {
            Self(baseKey: baseKey.negation)
        }

        /// The 65-byte uncompressed serialization of this public key (`0x04` prefix +
        /// 32-byte X + 32-byte Y), regardless of the key's stored ``format``.
        ///
        /// Always returns the uncompressed SEC1 form via
        /// `secp256k1_ec_pubkey_serialize` with `SECP256K1_EC_UNCOMPRESSED`. Useful when
        /// interoperating with systems that require the full `(x, y)` point encoding.
        public var uncompressedRepresentation: Data {
            baseKey.uncompressedRepresentation
        }

        /// Creates a public key from a validated backing implementation.
        ///
        /// Internal-visibility constructor used by factory methods that have already
        /// validated the backing implementation (e.g. ``negation``,
        /// ``PrivateKey/publicKey``); consumers use the public initializers below.
        ///
        /// - Parameter baseKey: A validated `PublicKeyImplementation`.
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
