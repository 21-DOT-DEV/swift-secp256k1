//
//  Recovery.swift
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

#if Xcode || ENABLE_MODULE_RECOVERY

    // MARK: - secp256k1 + Recovery

    /// An extension for secp256k1 with a nested Recovery enum.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        enum Recovery {
            /// A representation of a secp256k1 private key used for signing.
            public struct PrivateKey: Equatable {
                /// Generated secp256k1 Signing Key.
                private let baseKey: PrivateKeyImplementation

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

                /// Determines if two private keys are equal.
                ///
                /// - Parameters:
                ///   - lhs: The left-hand side private key.
                ///   - rhs: The right-hand side private key.
                /// - Returns: True if the private keys are equal, false otherwise.
                public static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.baseKey.key == rhs.baseKey.key
                }
            }

            /// A struct representing a secp256k1 public key for recovery purposes.
            public struct PublicKey {
                /// Generated secp256k1 Public Key.
                let baseKey: PublicKeyImplementation

                /// A data representation of the public key.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// Initializes a secp256k1 public key using a data message and a recovery signature.
                /// - Parameters:
                ///   - data: The data to be hash and assumed signed.
                ///   - signature: A raw representation of the initialized signature that supports pubkey recovery.
                ///   - format: The format of the public key object.
                public init<D: DataProtocol>(
                    _ data: D,
                    signature: P256K.Recovery.ECDSASignature,
                    format: P256K.Format = .compressed
                ) {
                    self.baseKey = PublicKeyImplementation(
                        SHA256.hash(data: data),
                        signature: signature,
                        format: format
                    )
                }

                /// Initializes a secp256k1 public key using a hash digest and a recovery signature.
                /// - Parameters:
                ///   - digest: The hash digest assumed to be signed.
                ///   - signature: A raw representation of the initialized signature that supports pubkey recovery.
                ///   - format: The format of the public key object.
                public init<D: Digest>(
                    _ digest: D,
                    signature: P256K.Recovery.ECDSASignature,
                    format: P256K.Format = .compressed
                ) {
                    self.baseKey = PublicKeyImplementation(digest, signature: signature, format: format)
                }

                /// Initializes a secp256k1 public key for recovery.
                /// - Parameter baseKey: Generated secp256k1 public key.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }
            }
        }
    }

#endif
