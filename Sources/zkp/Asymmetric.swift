//
//  Asymmetric.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// An elliptic curve that enables secp256k1 signatures and key agreement.
public extension secp256k1 {
    /// A mechanism used to create or verify a cryptographic signature using the secp256k1
    /// elliptic curve digital signature algorithm (ECDSA).
    enum Signing {
        /// A representation of a secp256k1 private key used for signing.
        public struct PrivateKey: Equatable {
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

            /// A data representation of the private key.
            public var rawRepresentation: Data {
                baseKey.rawRepresentation
            }

            /// Creates a random secp256k1 private key for signing.
            ///
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the private key cannot be generated.
            public init(format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            ///
            /// - Parameter data: A raw representation of the key.
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the raw representation does not create a private key for signing.
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(rawRepresentation: data, format: format)
            }

            /// Determines if two private keys are equal.
            ///
            /// - Parameters:
            ///   - lhs: The left-hand side private key.
            ///   - rhs: The right-hand side private key.
            /// - Returns: True if the private keys are equal, false otherwise.
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.key == rhs.key
            }
        }

        /// The corresponding public key for the secp256k1 curve.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            private let baseKey: PublicKeyImplementation

            /// The secp256k1 public key object.
            var bytes: [UInt8] {
                baseKey.bytes
            }

            /// A data representation of the public key.
            public var rawRepresentation: Data {
                baseKey.rawRepresentation
            }

            /// The associated x-only public key for verifying Schnorr signatures.
            ///
            /// - Returns: The associated x-only public key.
            public var xonly: XonlyKey {
                XonlyKey(baseKey: baseKey.xonly)
            }

            /// The key format representation of the public key.
            public var format: secp256k1.Format {
                baseKey.format
            }

            /// Generates a secp256k1 public key.
            ///
            /// - Parameter baseKey: Generated secp256k1 public key.
            fileprivate init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 public key from an x-only key.
            ///
            /// - Parameter xonlyKey: An x-only key object.
            public init(xonlyKey: XonlyKey) {
                let key = XonlyKeyImplementation(
                    rawRepresentation: xonlyKey.bytes,
                    keyParity: xonlyKey.parity ? 1 : 0
                )
                self.baseKey = PublicKeyImplementation(xonlyKey: key)
            }

            /// Generates a secp256k1 public key from a raw representation.
            ///
            /// - Parameter data: A raw representation of the key.
            /// - Parameter format: The key format.
            /// - Throws: An error if the raw representation does not create a public key.
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format) throws {
                self.baseKey = try PublicKeyImplementation(rawRepresentation: data, format: format)
            }
        }

        /// The corresponding x-only public key for the secp256k1 curve.
        public struct XonlyKey {
            /// Generated secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// The secp256k1 x-only public key object.
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            /// A boolean that indicates the point's parity.
            ///
            /// Set to `true` if the point encoded by the x-only public key is the negation of the public key,
            /// and set to `false` otherwise.
            public var parity: Bool {
                baseKey.keyParity.boolValue
            }

            /// Generates a secp256k1 x-only public key.
            ///
            /// - Parameter baseKey: Generated secp256k1 x-only public key.
            fileprivate init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 x-only public key from a raw representation and key parity.
            ///
            /// - Parameter data: A raw representation of the x-only public key.
            /// - Parameter keyParity: The key parity as an `Int32`.
            public init<D: ContiguousBytes>(rawRepresentation data: D, keyParity: Int32) {
                self.baseKey = XonlyKeyImplementation(rawRepresentation: data, keyParity: keyParity)
            }
        }
    }
}
