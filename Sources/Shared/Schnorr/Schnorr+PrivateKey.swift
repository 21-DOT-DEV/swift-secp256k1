//
//  Schnorr+PrivateKey.swift
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

    /// An elliptic curve that enables secp256k1 signatures and key agreement.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// A representation of a secp256k1 private key used for signing.
        struct PrivateKey: Equatable {
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

            /// The associated x-only public key for verifying Schnorr signatures.
            ///
            /// - Returns: The associated x-only public key.
            public var xonly: XonlyKey {
                XonlyKey(baseKey: baseKey.publicKey.xonly)
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
            public init() throws {
                self.baseKey = try PrivateKeyImplementation(format: .uncompressed)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            ///
            /// - Parameter data: A data representation of the key.
            /// - Throws: An error if the data representation does not create a private key for signing.
            public init<D: ContiguousBytes>(dataRepresentation data: D) throws {
                self.baseKey = try PrivateKeyImplementation(dataRepresentation: data)
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
    }

#endif
