//
//  ECDSA+PrivateKey.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing {
    /// A representation of a secp256k1 private key used for signing.
    struct PrivateKey: Equatable, Sendable {
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
            Self(baseKey: baseKey.negation)
        }

        /// Creates a private key from a validated backing implementation.
        init(baseKey: PrivateKeyImplementation) {
            self.baseKey = baseKey
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
}
