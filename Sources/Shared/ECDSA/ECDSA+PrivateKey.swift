//
//  ECDSA+PrivateKey.swift
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
    /// secp256k1 ECDSA private key for deterministically signing messages and producing
    /// ``ECDSASignature`` values using the secp256k1 curve.
    ///
    /// ## Overview
    ///
    /// Create a key by generating fresh randomness or by deserializing an existing raw,
    /// PEM, or DER representation. The 32-byte secret scalar must pass
    /// `secp256k1_ec_seckey_verify` (declared in
    /// [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h))
    /// to be accepted. Keep ``dataRepresentation`` confidential; exposing it compromises
    /// all signatures produced by this key.
    ///
    /// The `format` parameter controls whether the **public** key companion is serialized
    /// as compressed (33 bytes, default) or uncompressed (65 bytes). The private key itself
    /// is always 32 bytes regardless of format.
    ///
    /// ### Signing
    ///
    /// ECDSA signing uses `secp256k1_ecdsa_sign` with
    /// [RFC 6979](https://datatracker.ietf.org/doc/html/rfc6979) deterministic nonce
    /// generation. All signatures produced by this key are automatically normalized to
    /// lower-S form per
    /// [BIP-146](https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki), which is
    /// the only form accepted by `secp256k1_ecdsa_verify`. Pass a `Digest` or raw `Data`
    /// to the `signature(for:)` overloads on this type; the data overload hashes with
    /// SHA-256 before signing.
    ///
    /// ## Topics
    ///
    /// ### Construction
    /// - ``init(format:)``
    /// - ``init(dataRepresentation:format:)``
    /// - ``init(pemRepresentation:)``
    /// - ``init(derRepresentation:)``
    ///
    /// ### Inspection
    /// - ``publicKey``
    /// - ``dataRepresentation``
    /// - ``negation``
    struct PrivateKey: Equatable, Sendable {
        /// The internal `PrivateKeyImplementation` backing this signing key.
        ///
        /// Kept `private` — the backing type wraps the 32-byte secret scalar in
        /// `SecureBytes`-style zeroizing storage; consumers interact only through the
        /// public API surface.
        private let baseKey: PrivateKeyImplementation

        /// The raw 32-byte secret key bytes as `SecureBytes`.
        ///
        /// Internal-visibility accessor used by Swift-side helpers that participate in the
        /// `SecureBytes` lifetime (e.g. nonce-derivation helpers, `Equatable` comparison).
        /// External callers use ``dataRepresentation`` for a `Data` copy.
        var key: SecureBytes {
            baseKey.key
        }

        /// The secp256k1 public key derived from this private key, used to verify
        /// signatures this key produces.
        ///
        /// Computed on every access via `secp256k1_ec_pubkey_create`. For high-frequency
        /// signing loops, cache the value locally rather than re-deriving it per call.
        /// The returned public key carries the private key's ``P256K/Format`` selection.
        public var publicKey: PublicKey {
            PublicKey(baseKey: baseKey.publicKey)
        }

        /// The raw 32-byte secret key as `Data`. Keep this value confidential; disclosure
        /// allows anyone to sign on your behalf.
        ///
        /// The bytes are zeroed when the backing `PrivateKeyImplementation` is
        /// deallocated, but **copies made through this accessor are not**: any `Data`
        /// produced here escapes the zeroization scope and must be handled by the caller.
        /// Prefer restricting its reach to the minimum necessary scope (e.g. one encrypted
        /// write to a keychain) before discarding.
        public var dataRepresentation: Data {
            baseKey.dataRepresentation
        }

        /// A new ``PrivateKey`` whose secret scalar is the additive inverse of this key
        /// modulo the secp256k1 curve order, produced by `secp256k1_ec_seckey_negate`.
        ///
        /// Useful for BIP-32-style derivation schemes that need the negated scalar for
        /// subtraction under addition. The result satisfies `self.key + negation.key ≡ 0
        /// (mod n)`, equivalently `publicKey + negation.publicKey` is the point at
        /// infinity.
        public var negation: Self {
            Self(baseKey: baseKey.negation)
        }

        /// Creates a private key from a validated backing implementation.
        ///
        /// Internal-visibility constructor used when the backing implementation has
        /// already been validated (e.g. by ``negation`` or by the backing type's own
        /// factory methods); consumers use the public initializers below instead.
        ///
        /// - Parameter baseKey: A validated `PrivateKeyImplementation`.
        init(baseKey: PrivateKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Creates a random secp256k1 private key for signing by generating 32 cryptographically secure random bytes and validating them with `secp256k1_ec_seckey_verify`.
        ///
        /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the generated bytes do not form a valid secp256k1 private key (probability < 2⁻¹²⁸).
        public init(format: P256K.Format = .compressed) throws {
            self.baseKey = try PrivateKeyImplementation(format: format)
        }

        /// Creates a secp256k1 private key for signing from a 32-byte raw scalar.
        ///
        /// - Parameter data: Exactly 32 bytes representing the private key scalar; must pass `secp256k1_ec_seckey_verify`.
        /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
        /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if the scalar is invalid.
        public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format = .compressed) throws {
            self.baseKey = try PrivateKeyImplementation(dataRepresentation: data, format: format)
        }

        /// Creates a secp256k1 private key for signing from a Privacy-Enhanced Mail (PEM) representation.
        ///
        /// - Parameters:
        ///   - pemRepresentation: A PEM representation of the key.
        public init(pemRepresentation: String) throws {
            let pem = try ASN1.PEMDocument(pemString: pemRepresentation)

            switch pem.type {
            case "EC PRIVATE KEY":
                let parsed = try ASN1.SEC1PrivateKey(asn1Encoded: Array(pem.derBytes))
                self = try .init(dataRepresentation: parsed.privateKey)

            case "PRIVATE KEY":
                let parsed = try ASN1.PKCS8PrivateKey(asn1Encoded: Array(pem.derBytes))
                self = try .init(dataRepresentation: parsed.privateKey.privateKey)

            default:
                throw CryptoKitASN1Error.invalidPEMDocument
            }
        }

        /// Creates a secp256k1 private key for signing from a Distinguished Encoding Rules (DER) encoded representation.
        ///
        /// - Parameters:
        ///   - derRepresentation: A DER-encoded representation of the key.
        public init<Bytes: RandomAccessCollection>(derRepresentation: Bytes) throws where Bytes.Element == UInt8 {
            let bytes = Array(derRepresentation)

            // We have to try to parse this twice because we have no information about what kind of key this is.
            // We try with PKCS#8 first, and then fall back to SEC.1.

            do {
                let key = try ASN1.PKCS8PrivateKey(asn1Encoded: bytes)
                self = try .init(dataRepresentation: key.privateKey.privateKey)
            } catch {
                let key = try ASN1.SEC1PrivateKey(asn1Encoded: bytes)
                self = try .init(dataRepresentation: key.privateKey)
            }
        }

        #if Xcode || ENABLE_UINT256
            /// Creates a secp256k1 private key for signing from a `UInt256` constant.
            ///
            /// - Parameter staticInt: A `UInt256` value whose raw bytes form the 32-byte private key scalar.
            /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the scalar is not a valid secp256k1 private key.
            @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
            public init(_ staticInt: UInt256, format: P256K.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(dataRepresentation: staticInt.rawValue, format: format)
            }
        #endif

        /// Returns `true` if both private keys have identical 32-byte secret scalars; compares using `SecureBytes` constant-time equality.
        ///
        /// - Parameters:
        ///   - lhs: The left-hand side private key.
        ///   - rhs: The right-hand side private key.
        /// - Returns: `true` if the private keys are equal, `false` otherwise.
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.key == rhs.key
        }
    }
}
