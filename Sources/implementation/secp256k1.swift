//
//  secp256k1.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import secp256k1_bindings

/// The secp256k1 Elliptic Curve.
public enum secp256k1 {}

/// The secp256k1 Elliptic Curve.
extension secp256k1 {
    /// Signing operations on secp256k1
    public enum Signing {
        /// A Private Key for signing.
        public struct PrivateKey: ECPrivateKey {
            /// Generated secp256k1 Signing Key.
            private var baseKey: secp256k1.Signing.PrivateKeyImplementation

            /// Creates a random secp256k1 private key for signing
            public init() {
                self.baseKey = secp256k1.Signing.PrivateKeyImplementation()
            }

            /// The associated public key for verifying signatures done with this private key.
            ///
            /// - Returns: The associated public key
            public var publicKey: PublicKey {
                return PublicKey(baseKey: self.baseKey.publicKey)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                self.baseKey = try secp256k1.Signing.PrivateKeyImplementation(rawRepresentation: data)
            }

            /// A data representation of the private key
            public var rawRepresentation: Data {
                return self.baseKey.rawRepresentation
            }

            /// The secp256k1 private key object
            var key: SecureBytes {
                return self.baseKey.key
            }
        }

        /// The corresponding public key.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            private var baseKey: secp256k1.Signing.PublicKeyImplementation

            /// Generates a secp256k1 public key from from a raw representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a public key.
            public init<D: ContiguousBytes>(rawRepresentation data: D) throws {
                self.baseKey = try secp256k1.Signing.PublicKeyImplementation(rawRepresentation: data)
            }

            /// Generates a secp256k1 public key.
            /// - Parameter baseKey: generated secp256k1 public key.
            fileprivate init(baseKey: secp256k1.Signing.PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// A data representation of the public key
            public var rawRepresentation: Data {
                return self.baseKey.rawRepresentation
            }

            /// The secp256k1 public key object
            var keyBytes: [UInt8] {
                return self.baseKey.keyBytes
            }
        }
    }
}

/// Implementations for signing, we use bindings to libsecp256k1 for these operations.
extension secp256k1.Signing {
    /// Private key for signing implementation
    @usableFromInline struct PrivateKeyImplementation {
        /// Backing private key object
        var _privateKey: SecureBytes
        /// Backing public key object
        @usableFromInline var _publicKey: [UInt8]

        /// Backing initialization that creates a random secp256k1 private key for signing
        @usableFromInline init() {
            // Initialize context
            let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

            // Destroy context after creation
            defer { secp256k1_context_destroy(context) }

            // Setup private and public key variables
            var pubkeyLen = 33
            var cPubkey = secp256k1_pubkey()
            var pubkey = [UInt8](repeating: 0, count: 33)
            let privatekey = SecureBytes(count: 128)
            let privkey = Data(privatekey).withUnsafeBytes({ keyBytesPtr in Array(keyBytesPtr) })

            // Verify the context and keys are setup correctly
            guard secp256k1_context_randomize(context, privkey) == 1,
                secp256k1_ec_pubkey_create(context, &cPubkey, privkey) == 1,
                secp256k1_ec_pubkey_serialize(context, &pubkey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_COMPRESSED)) == 1 else {
                self._privateKey = privatekey
                self._publicKey = pubkey
                return
            }

            // Save
            self._privateKey = privatekey
            self._publicKey = pubkey
        }

        /// Backing implementation for a public key object
        @usableFromInline var publicKey: secp256k1.Signing.PublicKeyImplementation {
            return PublicKeyImplementation(self._publicKey)
        }

        /// Backing secp256k1 private key object
        var key: SecureBytes {
            return self._privateKey
        }

        /// Backing initialization that creates a secp256k1 private key for signing from a data representation.
        /// - Parameter data: A raw representation of the key.
        /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
        init<D: ContiguousBytes>(rawRepresentation data: D) throws {
            // Initialize context
            let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

            // Destroy context after creation
            defer { secp256k1_context_destroy(context) }

            // Setup private and public key variables
            var pubkeyLen = 33
            var cPubkey = secp256k1_pubkey()
            var pubkey = [UInt8](repeating: 0, count: 33)
            let privatekey = SecureBytes(bytes: data)
            let privkey = data.withUnsafeBytes({ keyBytesPtr in Array(keyBytesPtr) })

            // Verify the context and keys are setup correctly
            guard secp256k1_context_randomize(context, privkey) == 1,
                  secp256k1_ec_pubkey_create(context, &cPubkey, privkey) == 1,
                  secp256k1_ec_pubkey_serialize(context, &pubkey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_COMPRESSED)) == 1 else {
                self._privateKey = privatekey
                self._publicKey = pubkey
                return
            }

            // Save
            self._privateKey = privatekey
            self._publicKey = pubkey
        }

        /// A data representation of the backing private key
        @usableFromInline var rawRepresentation: Data {
            return Data(self._privateKey)
        }
    }

    /// Public key for signing implementation
    @usableFromInline struct PublicKeyImplementation {
        /// Implementation public key object
        @usableFromInline var keyBytes: [UInt8]

        /// Backing initialization that generates a secp256k1 public key from from a raw representation.
        /// - Parameter data: A raw representation of the key.
        /// - Throws: An error is thrown when the raw representation does not create a public key.
        @inlinable init<D: ContiguousBytes>(rawRepresentation data: D) throws {
            self.keyBytes = data.withUnsafeBytes({ keyBytesPtr in Array(keyBytesPtr) })
        }

        /// Backing initialization that sets the public key from from a public key object.
        /// - Parameter keyBytes: a public key object
        init(_ keyBytes: [UInt8]) {
            self.keyBytes = keyBytes
        }

        /// A data representation of the backing public key
        var rawRepresentation: Data {
            return Data(self.keyBytes)
        }
    }
}
