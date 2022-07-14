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

typealias NISTECDSASignature = RawSignature & DERSignature

protocol RawSignature {
    init<D: DataProtocol>(rawRepresentation: D) throws
    var rawRepresentation: Data { get }
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
public extension secp256k1.Signing {
    struct ECDSASignature: ContiguousBytes, NISTECDSASignature, CompactSignature {
        /// Returns the raw signature.
        /// The raw signature format for ECDSA is r || s
        public var rawRepresentation: Data

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        public init<D: DataProtocol>(rawRepresentation: D) throws {
            guard rawRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.rawRepresentation = Data(rawRepresentation)
        }

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        internal init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.rawRepresentation = dataRepresentation
        }

        /// Initializes ECDSASignature from the DER representation.
        /// - Parameter derRepresentation: A DER representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
        public init<D: DataProtocol>(derRepresentation: D) throws {
            let derSignatureBytes = Array(derRepresentation)
            var signature = secp256k1_ecdsa_signature()

            guard secp256k1_ecdsa_signature_parse_der(secp256k1.Context.raw, &signature, derSignatureBytes, derSignatureBytes.count).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.rawRepresentation = signature.dataValue
        }

        /// Initializes ECDSASignature from the Compact representation.
        /// - Parameter derRepresentation: A Compact representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
        public init<D: DataProtocol>(compactRepresentation: D) throws {
            var signature = secp256k1_ecdsa_signature()

            guard secp256k1_ecdsa_signature_parse_compact(secp256k1.Context.raw, &signature, Array(compactRepresentation)).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.rawRepresentation = signature.dataValue
        }

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameter body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try rawRepresentation.withUnsafeBytes(body)
        }

        /// Serialize an ECDSA signature in compact (64 byte) format.
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a 64-byte data representation of the compact serialization
        public var compactRepresentation: Data {
            get throws {
                let compactSignatureLength = 64
                var signature = secp256k1_ecdsa_signature()
                var compactSignature = [UInt8](repeating: 0, count: compactSignatureLength)

                rawRepresentation.copyToUnsafeMutableBytes(of: &signature.data)

                guard secp256k1_ecdsa_signature_serialize_compact(secp256k1.Context.raw, &compactSignature, &signature).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return Data(bytes: &compactSignature, count: compactSignatureLength)
            }
        }

        /// A DER-encoded representation of the signature
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a DER representation of the signature
        public var derRepresentation: Data {
            get throws {
                var signature = secp256k1_ecdsa_signature()
                var derSignatureLength = 80
                var derSignature = [UInt8](repeating: 0, count: derSignatureLength)

                rawRepresentation.copyToUnsafeMutableBytes(of: &signature.data)

                guard secp256k1_ecdsa_signature_serialize_der(secp256k1.Context.raw, &derSignature, &derSignatureLength, &signature).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return Data(bytes: &derSignature, count: derSignatureLength)
            }
        }
    }
}

// MARK: - secp256k1 + Signing Key

public extension secp256k1.Signing {
    struct ECDSASigner {
        /// Generated secp256k1 Signing Key.
        var signingKey: PrivateKeyImplementation
    }
}

extension secp256k1.Signing.ECDSASigner: DigestSigner, Signer {
    ///  Generates an ECDSA signature over the secp256k1 elliptic curve.
    ///
    /// - Parameter digest: The digest to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature
    public func signature<D: Digest>(for digest: D) throws -> secp256k1.Signing.ECDSASignature {
        var signature = secp256k1_ecdsa_signature()

        guard secp256k1_ecdsa_sign(secp256k1.Context.raw, &signature, Array(digest), Array(signingKey.rawRepresentation), nil, nil).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try secp256k1.Signing.ECDSASignature(signature.dataValue)
    }

    /// Generates an ECDSA signature over the secp256k1 elliptic curve.
    /// SHA256 is used as the hash function.
    ///
    /// - Parameter data: The data to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: DataProtocol>(for data: D) throws -> secp256k1.Signing.ECDSASignature {
        try signature(for: SHA256.hash(data: data))
    }
}

// MARK: - secp256k1 + Validating Key

public extension secp256k1.Signing {
    struct ECDSAValidator {
        /// Generated secp256k1 Validating Key.
        var validatingKey: PublicKeyImplementation
    }
}

extension secp256k1.Signing.ECDSAValidator: DigestValidator, DataValidator {
    /// Verifies an ECDSA signature over the secp256k1 elliptic curve.
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - digest: The digest that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: Digest>(_ signature: secp256k1.Signing.ECDSASignature, for digest: D) -> Bool {
        var secp256k1Signature = secp256k1_ecdsa_signature()
        var secp256k1PublicKey = secp256k1_pubkey()

        signature.rawRepresentation.copyToUnsafeMutableBytes(of: &secp256k1Signature.data)

        return secp256k1_ec_pubkey_parse(secp256k1.Context.raw, &secp256k1PublicKey, validatingKey.bytes, validatingKey.bytes.count).boolValue &&
            secp256k1_ecdsa_verify(secp256k1.Context.raw, &secp256k1Signature, Array(digest), &secp256k1PublicKey).boolValue
    }

    /// Verifies an ECDSA signature over the secp256k1 elliptic curve.
    /// SHA256 is used as the hash function.
    ///
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The data that was signed.
    /// - Returns: True if the signature is valid, false otherwise.
    public func isValidSignature<D: DataProtocol>(_ signature: secp256k1.Signing.ECDSASignature, for data: D) -> Bool {
        isValidSignature(signature, for: SHA256.hash(data: data))
    }
}
