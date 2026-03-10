//
//  MuSig.swift
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

#if Xcode || ENABLE_MODULE_MUSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        /// MuSig is a multi-signature scheme that allows multiple parties to sign a message using their own private keys,
        /// but only reveal their public keys. The aggregated public key is then used to verify the signature.
        ///
        /// This implementation follows the MuSig algorithm as described in BIP-327.
        enum MuSig {
            /// Represents a public key in the MuSig scheme.
            public struct PublicKey {
                /// Generated secp256k1 public key.
                let baseKey: PublicKeyImplementation

                /// The secp256k1 public key object.
                var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// The cache of information about public key aggregation.
                var keyAggregationCache: Data {
                    Data(baseKey.cache)
                }

                /// The key format representation of the public key.
                public var format: P256K.Format {
                    baseKey.format
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

                /// Generates a secp256k1 public key.
                ///
                /// - Parameter baseKey: Generated secp256k1 public key.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// Creates a MuSig public key from an x-only key.
                ///
                /// - Parameter xonlyKey: An x-only key object.
                public init(xonlyKey: XonlyKey) {
                    let key = XonlyKeyImplementation(
                        dataRepresentation: xonlyKey.bytes,
                        keyParity: xonlyKey.parity ? 1 : 0,
                        cache: xonlyKey.cache.bytes
                    )
                    self.baseKey = PublicKeyImplementation(xonlyKey: key)
                }

                /// Creates a MuSig public key from raw data.
                ///
                /// - Parameters:
                ///   - data: A data representation of the key.
                ///   - format: The key format.
                ///   - cache: The key aggregation cache.
                /// - Throws: An error if the raw representation does not create a valid public key.
                public init<D: ContiguousBytes>(
                    dataRepresentation data: D,
                    format: P256K.Format,
                    cache: [UInt8]
                ) throws {
                    self.baseKey = try PublicKeyImplementation(
                        dataRepresentation: data,
                        format: format,
                        cache: cache
                    )
                }
            }

            /// Represents an x-only public key in the MuSig scheme.
            public struct XonlyKey: Equatable {
                /// Generated secp256k1 x-only public key.
                private let baseKey: XonlyKeyImplementation

                /// The secp256k1 x-only public key object.
                public var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// Schnorr x-only public key are implicit of the point being even, therefore this will always return `false`.`
                public var parity: Bool {
                    baseKey.keyParity.boolValue
                }

                /// The cache of information about public key aggregation.
                public var cache: Data {
                    Data(baseKey.cache)
                }

                /// Generates a secp256k1 x-only public key.
                ///
                /// - Parameter baseKey: Generated secp256k1 x-only public key.
                init(baseKey: XonlyKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// Creates a MuSig x-only public key from raw data.
                ///
                /// - Parameters:
                ///   - data: A data representation of the x-only public key.
                ///   - keyParity: The key parity as an `Int32`.
                ///   - cache: The key aggregation cache.
                public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32 = 0, cache: [UInt8] = []) {
                    self.baseKey = XonlyKeyImplementation(dataRepresentation: data, keyParity: keyParity, cache: cache)
                }

                /// Determines if two x-only keys are equal.
                ///
                /// - Parameters:
                ///   - lhs: The left-hand side private key.
                ///   - rhs: The right-hand side private key.
                /// - Returns: True if the private keys are equal, false otherwise.
                public static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.baseKey.bytes == rhs.baseKey.bytes
                }
            }
        }
    }

    /// An extension for secp256k1_musig_session providing a convenience property.
    extension secp256k1_musig_session {
        var dataValue: Data {
            var mutableSession = self
            return Data(bytes: &mutableSession.data, count: MemoryLayout.size(ofValue: data))
        }
    }

    /// An extension for secp256k1_musig_partial_sig providing a convenience property.
    extension secp256k1_musig_partial_sig {
        /// A property that returns the Data representation of the `secp256k1_musig_partial_sig` object.
        var dataValue: Data {
            var mutableSig = self
            return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
        }
    }

#endif
