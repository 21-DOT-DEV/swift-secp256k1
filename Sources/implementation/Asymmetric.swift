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

/// The secp256k1 Elliptic Curve.
public extension secp256k1 {
    /// Signing operations on secp256k1
    enum Signing {
        /// A Private Key for signing.
        public struct PrivateKey: Equatable {
            /// Generated secp256k1 Signing Key.
            private let baseKey: PrivateKeyImplementation

            /// The secp256k1 private key object
            var key: SecureBytes {
                baseKey.key
            }

            /// ECDSA Signing object.
            public var ecdsa: secp256k1.Signing.ECDSASigner {
                ECDSASigner(signingKey: baseKey)
            }

            /// Schnorr Signing object.
            public var schnorr: secp256k1.Signing.SchnorrSigner {
                SchnorrSigner(signingKey: baseKey)
            }

            /// The associated public key for verifying signatures done with this private key.
            ///
            /// - Returns: The associated public key
            public var publicKey: PublicKey {
                PublicKey(baseKey: baseKey.publicKey)
            }

            /// A data representation of the private key
            public var rawRepresentation: Data {
                baseKey.rawRepresentation
            }

            /// Creates a random secp256k1 private key for signing
            public init(format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(rawRepresentation: data, format: format)
            }

            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.key == rhs.key
            }
        }

        /// The corresponding public key.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            private let baseKey: PublicKeyImplementation

            /// The secp256k1 public key object
            var bytes: [UInt8] {
                baseKey.bytes
            }

            /// A data representation of the public key
            public var rawRepresentation: Data {
                baseKey.rawRepresentation
            }

            /// ECDSA Validating object.
            public var ecdsa: secp256k1.Signing.ECDSAValidator {
                ECDSAValidator(validatingKey: baseKey)
            }

            /// Schnorr Validating object.
            public var schnorr: secp256k1.Signing.SchnorrValidator {
                SchnorrValidator(validatingKey: baseKey)
            }

            /// The associated x-only public key for verifying Schnorr signatures.
            ///
            /// - Returns: The associated x-only public key
            public var xonly: XonlyKey {
                XonlyKey(baseKey: baseKey.xonly)
            }

            /// A key format representation of the public key
            public var format: secp256k1.Format {
                baseKey.format
            }

            /// Generates a secp256k1 public key.
            /// - Parameter baseKey: generated secp256k1 public key.
            fileprivate init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 public key from a raw representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a public key.
            public init<D: ContiguousBytes>(rawRepresentation data: D, xonly: D, keyParity: Int32, format: secp256k1.Format) {
                self.baseKey = PublicKeyImplementation(rawRepresentation: data, xonly: xonly, keyParity: keyParity, format: format)
            }
        }

        /// The corresponding x-only public key.
        public struct XonlyKey {
            /// Generated secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// The secp256k1 x-only public key object
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            /// A boolean that will be set to true if the point encoded by xonly is the
            /// negation of the pubkey and set to false otherwise.
            public var parity: Bool {
                baseKey.keyParity.boolValue
            }

            fileprivate init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }

            public init<D: ContiguousBytes>(rawRepresentation data: D, keyParity: Int32) {
                self.baseKey = XonlyKeyImplementation(rawRepresentation: data, keyParity: keyParity)
            }
        }
    }
}
