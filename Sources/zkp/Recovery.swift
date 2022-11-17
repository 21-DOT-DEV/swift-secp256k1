//
//  Recovery.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

// MARK: - secp256k1 + Recovery

public extension secp256k1 {
    enum Recovery {
        public struct PublicKey {
            let baseKey: PublicKeyImplementation

            /// Initializes a secp256k1 public key using a data message and a recovery signature.
            /// - Parameters:
            ///   - data: The data to be hash and assumed signed.
            ///   - signature: A raw representation of the initialized signature that supports pubkey recovery.
            ///   - format: the format of the public key object
            public init<D: DataProtocol>(
                _ data: D,
                signature: secp256k1.Recovery.ECDSASignature,
                format: secp256k1.Format = .compressed
            ) throws {
                self.baseKey = try PublicKeyImplementation(
                    SHA256.hash(data: data),
                    signature: signature,
                    format: format
                )
            }

            /// Initializes a secp256k1 public key using a hash digest and a recovery signature.
            /// - Parameters:
            ///   - digest: The hash digest assumed to be signed.
            ///   - signature: A raw representation of the initialized signature that supports pubkey recovery.
            ///   - format: the format of the public key object
            public init<D: Digest>(
                _ digest: D,
                signature: secp256k1.Recovery.ECDSASignature,
                format: secp256k1.Format = .compressed
            ) throws {
                self.baseKey = try PublicKeyImplementation(digest, signature: signature, format: format)
            }

            /// Initializes a secp256k1 public key for recovery.
            /// - Parameter baseKey: generated secp256k1 public key.
            init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// A data representation of the public key
            public var rawRepresentation: Data { baseKey.rawRepresentation }

            /// Implementation public key object
            var bytes: [UInt8] { baseKey.bytes }
        }
    }
}

/// An ECDSA (Elliptic Curve Digital Signature Algorithm) Recovery Signature
public extension secp256k1.Recovery {
    /// Recovery Signature
    struct ECDSACompactSignature {
        public let signature: Data
        public let recoveryId: Int32
    }

    struct ECDSASignature: ContiguousBytes, RawSignature {
        /// Returns the raw signature.
        public var rawRepresentation: Data

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        public init<D: DataProtocol>(rawRepresentation: D) throws {
            guard rawRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount + 1 else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.rawRepresentation = Data(rawRepresentation)
        }

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        internal init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount + 1 else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.rawRepresentation = dataRepresentation
        }

        /// Initializes ECDSASignature from the Compact representation.
        /// - Parameter compactRepresentation: A Compact representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
        public init<D: DataProtocol>(compactRepresentation: D, recoveryId: Int32) throws {
            var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

            guard secp256k1_ecdsa_recoverable_signature_parse_compact(
                secp256k1.Context.raw,
                &recoverableSignature,
                Array(compactRepresentation),
                recoveryId
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.rawRepresentation = recoverableSignature.dataValue
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
        public var compactRepresentation: ECDSACompactSignature {
            get throws {
                let compactSignatureLength = 64
                var recoveryId = Int32()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()
                var compactSignature = [UInt8](repeating: 0, count: compactSignatureLength)

                rawRepresentation.copyToUnsafeMutableBytes(of: &recoverableSignature.data)

                guard secp256k1_ecdsa_recoverable_signature_serialize_compact(
                    secp256k1.Context.raw,
                    &compactSignature,
                    &recoveryId,
                    &recoverableSignature
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return secp256k1.Recovery.ECDSACompactSignature(
                    signature: Data(bytes: &compactSignature, count: compactSignatureLength),
                    recoveryId: recoveryId
                )
            }
        }

        /// Convert a recoverable signature into a normal signature.
        public var normalize: secp256k1.Signing.ECDSASignature {
            get throws {
                var normalizedSignature = secp256k1_ecdsa_signature()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

                rawRepresentation.copyToUnsafeMutableBytes(of: &recoverableSignature.data)

                guard secp256k1_ecdsa_recoverable_signature_convert(
                    secp256k1.Context.raw,
                    &normalizedSignature,
                    &recoverableSignature
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return try secp256k1.Signing.ECDSASignature(normalizedSignature.dataValue)
            }
        }
    }
}
