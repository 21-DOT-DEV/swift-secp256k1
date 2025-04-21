//
//  ECDSA.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
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

typealias NISTECDSASignature = DERSignature & DataSignature

protocol DataSignature {
    init<D: DataProtocol>(dataRepresentation: D) throws
    var dataRepresentation: Data { get }
}

protocol DERSignature {
    init<D: DataProtocol>(derRepresentation: D) throws
    var derRepresentation: Data { get throws }
}

protocol CompactSignature {
    init<D: DataProtocol>(compactRepresentation: D) throws
    var compactRepresentation: Data { get throws }
}

// MARK: - secp256k1 + ECDSA Signature

/// An ECDSA (Elliptic Curve Digital Signature Algorithm) Signature
public extension P256K.Signing {
    struct ECDSASignature: ContiguousBytes, NISTECDSASignature, CompactSignature {
        /// Returns the data signature.
        /// The raw signature format for ECDSA is r || s
        public var dataRepresentation: Data

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        public init<D: DataProtocol>(dataRepresentation: D) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = Data(dataRepresentation)
        }

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == P256K.ByteLength.signature else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = dataRepresentation
        }

        /// Initializes ECDSASignature from the DER representation.
        /// - Parameter derRepresentation: A DER representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
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

        /// Initializes ECDSASignature from the Compact representation.
        /// - Parameter derRepresentation: A Compact representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
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

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameter body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }

        /// Serialize an ECDSA signature in compact (64 byte) format.
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a 64-byte data representation of the compact serialization
        public var compactRepresentation: Data {
            get throws {
                let context = P256K.Context.rawRepresentation
                var signature = secp256k1_ecdsa_signature()
                var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)

                dataRepresentation.copyToUnsafeMutableBytes(of: &signature.data)

                guard secp256k1_ecdsa_signature_serialize_compact(
                    context,
                    &compactSignature,
                    &signature
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return Data(bytes: &compactSignature, count: P256K.ByteLength.signature)
            }
        }

        /// A DER-encoded representation of the signature
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a DER representation of the signature
        public var derRepresentation: Data {
            get throws {
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
                    throw secp256k1Error.underlyingCryptoError
                }

                return Data(bytes: &derSignature, count: derSignatureLength)
            }
        }
    }
}

// MARK: - secp256k1 + Signing Key

extension P256K.Signing.PrivateKey: DigestSigner {
    ///  Generates an ECDSA signature over the secp256k1 elliptic curve.
    ///
    /// - Parameter digest: The digest to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature
    public func signature<D: Digest>(for digest: D) throws -> P256K.Signing.ECDSASignature {
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
            throw secp256k1Error.underlyingCryptoError
        }

        return try P256K.Signing.ECDSASignature(signature.dataValue)
    }
}

extension P256K.Signing.PrivateKey: Signer {
    /// Generates an ECDSA signature over the secp256k1 elliptic curve.
    /// SHA256 is used as the hash function.
    ///
    /// - Parameter data: The data to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: DataProtocol>(for data: D) throws -> P256K.Signing.ECDSASignature {
        try signature(for: SHA256.hash(data: data))
    }
}

// MARK: - secp256k1 + Validating Key

extension P256K.Signing.PublicKey: DigestValidator {
    /// Verifies an ECDSA signature over the secp256k1 elliptic curve.
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - digest: The digest that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: Digest>(_ signature: P256K.Signing.ECDSASignature, for digest: D) -> Bool {
        let context = P256K.Context.rawRepresentation
        var ecdsaSignature = secp256k1_ecdsa_signature()
        var publicKey = baseKey.rawRepresentation

        signature.dataRepresentation.copyToUnsafeMutableBytes(of: &ecdsaSignature.data)

        return secp256k1_ecdsa_verify(context, &ecdsaSignature, Array(digest), &publicKey).boolValue
    }
}

extension P256K.Signing.PublicKey: DataValidator {
    /// Verifies an ECDSA signature over the secp256k1 elliptic curve.
    /// SHA256 is used as the hash function.
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The data that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: DataProtocol>(_ signature: P256K.Signing.ECDSASignature, for data: D) -> Bool {
        isValidSignature(signature, for: SHA256.hash(data: data))
    }
}
