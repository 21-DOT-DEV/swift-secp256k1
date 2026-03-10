//
//  Recovery+Signature.swift
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

#if Xcode || ENABLE_MODULE_RECOVERY

    /// An ECDSA (Elliptic Curve Digital Signature Algorithm) Recovery Signature
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Recovery {
        /// Recovery Signature
        struct ECDSACompactSignature {
            public let signature: Data
            public let recoveryId: Int32
        }

        struct ECDSASignature: ContiguousBytes, DataSignature {
            /// Returns the raw signature.
            public var dataRepresentation: Data

            /// Serialize an ECDSA signature in compact (64 byte) format.
            /// - Returns: a 64-byte data representation of the compact serialization
            public var compactRepresentation: ECDSACompactSignature {
                let context = P256K.Context.rawRepresentation
                var recoveryId = Int32()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()
                var compactSignature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)

                dataRepresentation.copyToUnsafeMutableBytes(of: &recoverableSignature.data)

                guard secp256k1_ecdsa_recoverable_signature_serialize_compact(
                    context,
                    &compactSignature,
                    &recoveryId,
                    &recoverableSignature
                ).boolValue else {
                    fatalError("secp256k1_ecdsa_recoverable_signature_serialize_compact failed — library bug")
                }

                return P256K.Recovery.ECDSACompactSignature(
                    signature: Data(bytes: &compactSignature, count: P256K.ByteLength.signature),
                    recoveryId: recoveryId
                )
            }

            /// Convert a recoverable signature into a normal signature.
            public var normalize: P256K.Signing.ECDSASignature {
                let context = P256K.Context.rawRepresentation
                var normalizedSignature = secp256k1_ecdsa_signature()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

                dataRepresentation.copyToUnsafeMutableBytes(of: &recoverableSignature.data)

                guard secp256k1_ecdsa_recoverable_signature_convert(
                    context,
                    &normalizedSignature,
                    &recoverableSignature
                ).boolValue else {
                    fatalError("secp256k1_ecdsa_recoverable_signature_convert failed — library bug")
                }

                return P256K.Signing.ECDSASignature(normalizedSignature.dataValue)
            }

            /// Initializes ECDSASignature from the raw representation.
            /// - Parameters:
            ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
            /// - Throws: If there is a failure with the dataRepresentation count
            public init<D: DataProtocol>(dataRepresentation: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature + 1 else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
            }

            /// Initializes ECDSASignature from the raw representation.
            /// - Parameters:
            ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature + 1`.
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature + 1, "Invalid recoverable signature size")
                self.dataRepresentation = dataRepresentation
            }

            /// Initializes ECDSASignature from the Compact representation.
            /// - Parameter compactRepresentation: A Compact representation of the key as a collection of contiguous bytes.
            /// - Throws: If there is a failure with parsing the derRepresentation
            public init<D: DataProtocol>(compactRepresentation: D, recoveryId: Int32) throws {
                let context = P256K.Context.rawRepresentation
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

                guard secp256k1_ecdsa_recoverable_signature_parse_compact(
                    context,
                    &recoverableSignature,
                    Array(compactRepresentation),
                    recoveryId
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.dataRepresentation = recoverableSignature.dataValue
            }

            /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
            /// - Parameter body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
            /// - Throws: If there is a failure with underlying `withUnsafeBytes`
            /// - Returns: The signature as returned from the body closure.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

    // MARK: - secp256k1 + Recovery

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Recovery.PrivateKey: DigestSigner {
        public typealias Signature = P256K.Recovery.ECDSASignature

        ///  Generates a recoverable ECDSA signature.
        ///
        /// - Parameter digest: The digest to sign.
        /// - Returns: The recoverable ECDSA Signature.
        public func signature<D: Digest>(for digest: D) -> Signature {
            let context = P256K.Context.rawRepresentation
            var signature = secp256k1_ecdsa_recoverable_signature()

            guard secp256k1_ecdsa_sign_recoverable(
                context,
                &signature,
                Array(digest),
                Array(dataRepresentation),
                nil,
                nil
            ).boolValue else {
                fatalError("secp256k1_ecdsa_sign_recoverable failed with valid key — library bug")
            }

            return P256K.Recovery.ECDSASignature(signature.dataValue)
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.Recovery.PrivateKey: Signer {
        /// Generates a recoverable ECDSA signature. SHA256 is used as the hash function.
        ///
        /// - Parameter data: The data to sign.
        /// - Returns: The ECDSA Signature.
        public func signature<D: DataProtocol>(for data: D) -> Signature {
            signature(for: SHA256.hash(data: data))
        }
    }

#endif
