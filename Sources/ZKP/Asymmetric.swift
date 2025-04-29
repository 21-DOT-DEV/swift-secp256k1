//
//  Asymmetric.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    @_implementationOnly import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    @_implementationOnly import libsecp256k1
#endif

/// An elliptic curve that enables secp256k1 signatures and key agreement.
public extension P256K {
    /// A mechanism used to create or verify a cryptographic signature using the secp256k1
    /// elliptic curve digital signature algorithm (ECDSA).
    enum Signing {
        /// A representation of a secp256k1 private key used for signing.
        public struct PrivateKey: Equatable {
            /// Generated secp256k1 Signing Key.
            private let baseKey: PrivateKeyImplementation

            /// The secp256k1 private key object.
            var key: SecureBytes {
                baseKey.key
            }

            /// The associated public key for verifying signatures created with this private key.
            ///
            /// - Returns: The associated public key.
            public var publicKey: PublicKey {
                PublicKey(baseKey: baseKey.publicKey)
            }

            /// A data representation of the private key.
            public var dataRepresentation: Data {
                baseKey.dataRepresentation
            }

            /// Negates a secret key.
            public var negation: Self {
                get throws {
                    let negatedKey = try baseKey.negation.dataRepresentation
                    return try Self(dataRepresentation: negatedKey)
                }
            }

            /// Creates a random secp256k1 private key for signing.
            ///
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the private key cannot be generated.
            public init(format: P256K.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            ///
            /// - Parameter data: A data representation of the key.
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the raw representation does not create a private key for signing.
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

            /// Creates a secp256k1 private key for signing from a data representation.
            ///
            /// - Parameter data: A raw representation of the key.
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the raw representation does not create a private key for signing.
            @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
            public init(_ staticInt: UInt256, format: P256K.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(dataRepresentation: staticInt.rawValue, format: format)
            }

            /// Determines if two private keys are equal.
            ///
            /// - Parameters:
            ///   - lhs: The left-hand side private key.
            ///   - rhs: The right-hand side private key.
            /// - Returns: True if the private keys are equal, false otherwise.
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.key == rhs.key
            }
        }

        /// The corresponding public key for the secp256k1 curve.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            let baseKey: PublicKeyImplementation

            /// The secp256k1 public key object.
            var bytes: [UInt8] {
                baseKey.bytes
            }

            /// A data representation of the public key.
            public var dataRepresentation: Data {
                baseKey.dataRepresentation
            }

            /// The associated x-only public key for verifying Schnorr signatures.
            ///
            /// - Returns: The associated x-only public key.
            public var xonly: XonlyKey {
                XonlyKey(baseKey: baseKey.xonly)
            }

            /// The key format representation of the public key.
            public var format: P256K.Format {
                baseKey.format
            }

            /// Negates a public key.
            public var negation: Self {
                get throws {
                    let negatedKey = try baseKey.negation
                    return try Self(dataRepresentation: negatedKey.dataRepresentation, format: negatedKey.format)
                }
            }

            /// Returns a public key in uncompressed 65 byte form
            public var uncompressedRepresentation: Data {
                let context = P256K.Context.rawRepresentation
                var pubKey = baseKey.rawRepresentation
                var pubKeyLen = ByteLength.uncompressedPublicKey
                var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

                _ = secp256k1_ec_pubkey_serialize(
                    context,
                    &pubKeyBytes,
                    &pubKeyLen,
                    &pubKey,
                    UInt32(SECP256K1_EC_UNCOMPRESSED)
                )

                return Data(pubKeyBytes)
            }

            /// Generates a secp256k1 public key.
            ///
            /// - Parameter baseKey: Generated secp256k1 public key.
            fileprivate init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 public key from an x-only key.
            ///
            /// - Parameter xonlyKey: An x-only key object.
            public init(xonlyKey: XonlyKey) {
                let key = XonlyKeyImplementation(
                    dataRepresentation: xonlyKey.bytes,
                    keyParity: xonlyKey.parity ? 1 : 0
                )
                self.baseKey = PublicKeyImplementation(xonlyKey: key)
            }

            /// Generates a secp256k1 public key from a data representation.
            ///
            /// - Parameter data: A data representation of the key.
            /// - Parameter format: The key format.
            /// - Throws: An error if the data representation does not create a public key.
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

            /// Creates a secp256k1 public key for signing from an ANSI x9.63 representation.
            ///
            /// - Parameters:
            ///   - x963Representation: An ANSI x9.63 representation of the key.
            public init<Bytes: ContiguousBytes>(x963Representation: Bytes) throws {
                // Before we do anything, we validate that the x963 representation has the right number of bytes.
                let length = x963Representation.withUnsafeBytes { $0.count }

                switch length {
                case (2 * P256K.ByteLength.dimension) + 1:
                    self.baseKey = try PublicKeyImplementation(dataRepresentation: x963Representation, format: .uncompressed)

                default:
                    throw CryptoKitError.incorrectParameterSize
                }
            }
        }

        /// The corresponding x-only public key for the secp256k1 curve.
        public struct XonlyKey {
            /// Generated secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// The secp256k1 x-only public key object.
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            /// A boolean that indicates the point's parity.
            ///
            /// Set to `true` if the point encoded by the x-only public key is the negation of the public key,
            /// and set to `false` otherwise.
            public var parity: Bool {
                baseKey.keyParity.boolValue
            }

            /// Generates a secp256k1 x-only public key.
            ///
            /// - Parameter baseKey: Generated secp256k1 x-only public key.
            fileprivate init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 x-only public key from a raw representation and key parity.
            ///
            /// - Parameter data: A data representation of the x-only public key.
            /// - Parameter keyParity: The key parity as an `Int32`.
            public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32) {
                self.baseKey = XonlyKeyImplementation(dataRepresentation: data.bytes, keyParity: keyParity)
            }
        }
    }
}
