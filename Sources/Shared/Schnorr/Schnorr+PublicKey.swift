//
//  Schnorr+PublicKey.swift
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

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// The corresponding public key for the secp256k1 curve.
        struct PublicKey {
            /// Generated secp256k1 public key.
            let baseKey: PublicKeyImplementation

            /// The secp256k1 public key object.
            var bytes: [UInt8] {
                baseKey.bytes
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

            /// Generates a secp256k1 public key from a raw representation.
            ///
            /// - Parameter data: A data representation of the key.
            /// - Parameter format: The key format.
            /// - Throws: An error if the raw representation does not create a public key.
            public init<D: ContiguousBytes>(
                dataRepresentation data: D,
                format: P256K.Format
            ) throws {
                self.baseKey = try PublicKeyImplementation(
                    dataRepresentation: data,
                    format: format
                )
            }
        }
    }

#endif
