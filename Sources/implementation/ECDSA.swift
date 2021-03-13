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
import secp256k1_bindings

protocol NISTECDSASignature {
    init<D: DataProtocol>(rawRepresentation: D) throws
    init<D: DataProtocol>(derRepresentation: D) throws
    func derRepresentation() throws -> Data
    var rawRepresentation: Data { get }
}

protocol NISTSigning {
    associatedtype PublicKey: NISTECPublicKey & DataValidator & DigestValidator
    associatedtype PrivateKey: NISTECPrivateKey & Signer
    associatedtype ECDSASignature: NISTECDSASignature
}

// MARK: - secp256k1 + Signing

/// An ECDSA (Elliptic Curve Digital Signature Algorithm) Signature
extension secp256k1.Signing {
    public struct ECDSASignature: ContiguousBytes, NISTECDSASignature {
        /// Returns the raw signature.
        /// The raw signature format for ECDSA is r || s
        public var rawRepresentation: Data

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameter rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        public init<D: DataProtocol>(rawRepresentation: D) throws {
            guard rawRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount else {
                throw CryptoKitError.incorrectParameterSize
            }

            self.rawRepresentation = Data(rawRepresentation)
        }

        /// Initializes ECDSASignature from the data representation.
        /// - Parameter dataRepresentation: A data representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        internal init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount else {
                throw CryptoKitError.incorrectParameterSize
            }

            self.rawRepresentation = dataRepresentation
        }

        /// Initializes ECDSASignature from the DER representation.
        /// - Parameter derRepresentation: A DER representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
        public init<D: DataProtocol>(derRepresentation: D) throws {
            // Initialize context
            let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
            let derSignatureBytes = Array(derRepresentation)
            var signature = secp256k1_ecdsa_signature()

            // Destroy context after creation
            defer { secp256k1_context_destroy(context) }

            guard secp256k1_ecdsa_signature_parse_der(context, &signature, derSignatureBytes, derSignatureBytes.count) == 1 else {
                throw CryptoKitError.incorrectParameterSize
            }

            self.rawRepresentation = Data(bytes: &signature.data, count: MemoryLayout.size(ofValue: signature.data))
        }

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameter body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try self.rawRepresentation.withUnsafeBytes(body)
        }

        /// Serialize an ECDSA signature in compact (64 byte) format.
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a 64-byte data representation of the compact serialization
        public func compactRepresentation() throws -> Data {
            // Initialize context
            let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
            let compactSignatureLength = 64
            var signature = secp256k1_ecdsa_signature()
            var compactSignature = [UInt8](repeating: 0, count: compactSignatureLength)

            // Destroy context after creation
            defer { secp256k1_context_destroy(context) }

            withUnsafeMutableBytes(of: &signature.data) { ptr in
                ptr.copyBytes(from: rawRepresentation.prefix(ptr.count))
            }

            guard secp256k1_ecdsa_signature_serialize_compact(context, &compactSignature, &signature) == 1 else {
                return Data()
            }

            return Data(bytes: &compactSignature, count: compactSignatureLength)
        }

        /// A DER-encoded representation of the signature
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a DER representation of the signature
        public func derRepresentation() throws -> Data {
            // Initialize context
            let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
            var signature = secp256k1_ecdsa_signature()
            var derSignatureLength = 80
            var derSignature = [UInt8](repeating: 0, count: derSignatureLength)

            // Destroy context after creation
            defer { secp256k1_context_destroy(context) }

            withUnsafeMutableBytes(of: &signature.data) { ptr in
                ptr.copyBytes(from: rawRepresentation.prefix(ptr.count))
            }

            guard secp256k1_ecdsa_signature_serialize_der(context, &derSignature, &derSignatureLength, &signature) == 1 else {
                return Data()
            }

            return Data(bytes: &derSignature, count: derSignatureLength)
        }
    }
}

// MARK: - secp256k1 + PrivateKey
extension secp256k1.Signing.PrivateKey: DigestSigner {
    ///  Generates an ECDSA signature over the secp256k1 elliptic curve.
    ///
    /// - Parameter digest: The digest to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature
    public func signature<D: Digest>(for digest: D) throws -> secp256k1.Signing.ECDSASignature {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
        var signature = secp256k1_ecdsa_signature()

        // Destroy context after creation
        defer { secp256k1_context_destroy(context) }

        guard secp256k1_ecdsa_sign(context, &signature, Array(digest), Array(rawRepresentation), nil, nil) == 1 else {
            throw CryptoKitError.incorrectParameterSize
        }

        return try secp256k1.Signing.ECDSASignature(Data(bytes: &signature.data, count: MemoryLayout.size(ofValue: signature.data)))
    }
}

extension secp256k1.Signing.PrivateKey: Signer {
    /// Generates an ECDSA signature over the secp256k1 elliptic curve.
    /// SHA256 is used as the hash function.
    ///
    /// - Parameter data: The data to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: DataProtocol>(for data: D) throws -> secp256k1.Signing.ECDSASignature {
        return try self.signature(for: SHA256.hash(data: data))
    }
}

extension secp256k1.Signing.PublicKey: DigestValidator {
    /// Verifies an ECDSA signature over the secp256k1 elliptic curve.
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - digest: The digest that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: Digest>(_ signature: secp256k1.Signing.ECDSASignature, for digest: D) -> Bool {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
        var secp256k1Signature = secp256k1_ecdsa_signature()
        var secp256k1PublicKey = secp256k1_pubkey()

        // Destroy context after creation
        defer { secp256k1_context_destroy(context) }

        guard secp256k1_ec_pubkey_parse(context, &secp256k1PublicKey, keyBytes, keyBytes.count) == 1 else {
            return false
        }

        withUnsafeMutableBytes(of: &secp256k1Signature.data) { ptr in
            ptr.copyBytes(from: signature.rawRepresentation.prefix(ptr.count))
        }

        return secp256k1_ecdsa_verify(context, &secp256k1Signature, Array(digest), &secp256k1PublicKey) == 1
    }
}

extension secp256k1.Signing.PublicKey: DataValidator {
    /// Verifies an ECDSA signature over the secp256k1 elliptic curve.
    /// SHA256 is used as the hash function.
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The data that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: DataProtocol>(_ signature: secp256k1.Signing.ECDSASignature, for data: D) -> Bool {
        return self.isValidSignature(signature, for: SHA256.hash(data: data))
    }
 }
