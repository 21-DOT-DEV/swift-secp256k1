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
    /// The corresponding public key for the secp256k1 curve.
    struct PublicKey: Sendable {
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
            Self(baseKey: baseKey.negation)
        }

        /// Returns a public key in uncompressed 65 byte form
        public var uncompressedRepresentation: Data {
            baseKey.uncompressedRepresentation
        }

        /// Generates a secp256k1 public key.
        ///
        /// - Parameter baseKey: Generated secp256k1 public key.
        init(baseKey: PublicKeyImplementation) {
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
        ///     Accepts both compressed (33 bytes) and uncompressed (65 bytes) formats.
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
