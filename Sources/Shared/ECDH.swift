//
//  ECDH.swift
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

#if Xcode || ENABLE_MODULE_ECDH

    // MARK: - secp256k1 + KeyAgreement

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        /// secp256k1 ECDH key agreement namespace providing ``PrivateKey`` and ``PublicKey`` for computing a ``SharedSecret`` via `secp256k1_ecdh`.
        ///
        /// ECDH computes a shared secret `S = private_key × peer_public_key` on the secp256k1
        /// elliptic curve. **Context randomization does not provide side-channel protection for
        /// ECDH** — it uses a different kind of point multiplication than ECDSA or Schnorr signing.
        /// The shared secret is returned as a serialized point in compressed (33-byte, default)
        /// or uncompressed (65-byte) form depending on the `format` argument.
        enum KeyAgreement: Sendable {
            /// secp256k1 ECDH public key, accepted by ``PrivateKey/sharedSecretFromKeyAgreement(with:format:)`` to compute a ``SharedSecret``.
            public struct PublicKey: Sendable {
                /// The internal backing public key implementation.
                let baseKey: PublicKeyImplementation

                /// Creates a secp256k1 ECDH public key from serialized bytes.
                ///
                /// - Parameter data: Serialized public key bytes whose length must match `format.length`.
                /// - Parameter format: The serialization format; defaults to `.compressed` (33 bytes).
                /// - Throws: ``secp256k1Error/underlyingCryptoError`` if parsing via `secp256k1_ec_pubkey_parse` fails.
                public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format = .compressed) throws {
                    self.baseKey = try PublicKeyImplementation(dataRepresentation: data, format: format)
                }

                /// Creates an ECDH public key from a validated backing implementation.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// The 32-byte x-only public key (X coordinate only) derived from this key.
                public var xonly: P256K.KeyAgreement.XonlyKey {
                    XonlyKey(baseKey: baseKey.xonly)
                }

                /// The 65-byte uncompressed serialization of this public key (0x04 prefix + X + Y).
                public var uncompressedRepresentation: Data {
                    baseKey.uncompressedRepresentation
                }

                /// The serialized public key bytes as `Data`, in the key's format.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The serialized public key bytes as `[UInt8]`.
                var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// Creates a secp256k1 public key for key agreement from a Distinguished Encoding Rules (DER) encoded representation.
                ///
                /// - Parameters:
                ///   - derRepresentation: A DER-encoded representation of the key.
                public init<Bytes: RandomAccessCollection>(derRepresentation: Bytes) throws where Bytes.Element == UInt8 {
                    let bytes = Array(derRepresentation)
                    let parsed = try ASN1.SubjectPublicKeyInfo(asn1Encoded: bytes)
                    self = try .init(x963Representation: parsed.key)
                }

                /// Creates a secp256k1 ECDH public key from an ANSI X9.63 representation.
                ///
                /// - Parameter x963Representation: 33 bytes for compressed or 65 bytes for uncompressed; byte-length determines the format automatically.
                /// - Throws: `CryptoKitError.incorrectParameterSize` if the length is neither 33 nor 65 bytes.
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

            /// The 32-byte x-only form of a ``PublicKey``, derived via `secp256k1_xonly_pubkey_from_pubkey`.
            public struct XonlyKey: Sendable {
                /// The internal backing x-only key implementation.
                private let baseKey: XonlyKeyImplementation

                /// The 32-byte X coordinate as `Data`.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// `true` if the full public key's Y coordinate is odd (the x-only point is the negation of the original pubkey), `false` if even; as returned by `secp256k1_xonly_pubkey_from_pubkey`.
                public var parity: Bool {
                    baseKey.keyParity.boolValue
                }

                /// Creates an ECDH x-only key from a validated backing implementation.
                init(baseKey: XonlyKeyImplementation) {
                    self.baseKey = baseKey
                }
            }

            /// secp256k1 ECDH private key for deriving a ``SharedSecret`` with a peer's ``PublicKey`` via `secp256k1_ecdh`.
            public struct PrivateKey: Sendable {
                /// The internal backing private key implementation.
                let baseKey: PrivateKeyImplementation

                /// Creates a random secp256k1 ECDH private key.
                ///
                /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
                /// - Throws: ``secp256k1Error/underlyingCryptoError`` if key generation fails.
                public init(format: P256K.Format = .compressed) throws {
                    self.baseKey = try PrivateKeyImplementation(format: format)
                }

                /// Creates a secp256k1 ECDH private key from a 32-byte raw scalar.
                ///
                /// - Parameter data: Exactly 32 bytes; must pass `secp256k1_ec_seckey_verify`.
                /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
                /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if the scalar is invalid.
                public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format = .compressed) throws {
                    self.baseKey = try PrivateKeyImplementation(dataRepresentation: data, format: format)
                }

                /// Creates an ECDH private key from a validated backing implementation.
                init(baseKey: PrivateKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// The secp256k1 public key derived from this private key.
                public var publicKey: P256K.KeyAgreement.PublicKey {
                    PublicKey(baseKey: baseKey.publicKey)
                }

                /// The raw 32-byte private key as `Data`. Keep this value confidential.
                public var rawRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The raw 32-byte private key as `SecureBytes`.
                var bytes: SecureBytes {
                    baseKey.key
                }
            }
        }
    }

    // MARK: - secp256k1 + DH

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.KeyAgreement.PrivateKey: DiffieHellmanKeyAgreement {
        /// The C function type for a custom ECDH hash function that serializes the shared EC point into secret bytes.
        public typealias HashFunctionType = @convention(c) (
            UnsafeMutablePointer<UInt8>?,
            UnsafePointer<UInt8>?,
            UnsafePointer<UInt8>?,
            UnsafeMutableRawPointer?
        ) -> Int32

        /// Computes a compressed-format ECDH shared secret with `publicKeyShare` via `secp256k1_ecdh`.
        ///
        /// - Parameter publicKeyShare: The peer's public key.
        /// - Returns: A ``SharedSecret`` in compressed (33-byte) format.
        func sharedSecretFromKeyAgreement(with publicKeyShare: P256K.KeyAgreement.PublicKey) -> SharedSecret {
            sharedSecretFromKeyAgreement(with: publicKeyShare, format: .compressed)
        }

        /// Computes an ECDH shared secret by calling `secp256k1_ecdh` with a custom hash closure that serializes the shared point.
        ///
        /// The shared point is serialized as a compressed (33-byte) or uncompressed (65-byte) public
        /// key depending on `format`. **Context randomization does not protect this operation
        /// against side-channel attacks** — ECDH uses a different kind of point multiplication than
        /// signing operations.
        ///
        /// - Parameter publicKeyShare: The peer's secp256k1 public key.
        /// - Parameter format: Whether to serialize the shared point as compressed (33 bytes, default) or uncompressed (65 bytes).
        /// - Returns: A ``SharedSecret`` containing the serialized shared point.
        public func sharedSecretFromKeyAgreement(
            with publicKeyShare: P256K.KeyAgreement.PublicKey,
            format: P256K.Format = .compressed
        ) -> SharedSecret {
            let context = P256K.Context.rawRepresentation
            var publicKey = publicKeyShare.baseKey.rawRepresentation
            var sharedSecret = [UInt8](repeating: 0, count: format.length)
            var data = [UInt8](repeating: format == .compressed ? 1 : 0, count: 1)

            guard secp256k1_ecdh(context, &sharedSecret, &publicKey, baseKey.key.bytes, hashClosure(), &data).boolValue else {
                fatalError("secp256k1_ecdh failed with valid keys — library bug")
            }

            return SharedSecret(ss: SecureBytes(bytes: sharedSecret), format: format)
        }

        /// Returns a `secp256k1_ecdh` hash function closure that serializes the shared EC point as a compressed or uncompressed public key, bypassing the default SHA-256 hashing.
        ///
        /// - Returns: A C-compatible ``HashFunctionType`` closure for use as the `hashfp` argument of `secp256k1_ecdh`.
        func hashClosure() -> HashFunctionType {
            { output, x32, y32, data in
                guard let output, let x32, let y32, let compressed = data?.load(as: Bool.self) else { return 0 }

                let lastByte = y32.advanced(by: P256K.ByteLength.dimension - 1).pointee
                let version: UInt8 = compressed ? (lastByte & 0x01) | 0x02 : 0x04

                output.update(repeating: version, count: 1)
                output.advanced(by: 1).update(from: x32, count: P256K.ByteLength.dimension)

                if compressed == false {
                    output.advanced(by: P256K.ByteLength.dimension + 1)
                        .update(from: y32, count: P256K.ByteLength.dimension)
                }

                return 1
            }
        }
    }

#endif
