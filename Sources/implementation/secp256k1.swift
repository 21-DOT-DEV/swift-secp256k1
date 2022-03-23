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

/// Flags passed to secp256k1_context_create, secp256k1_context_preallocated_size, and secp256k1_context_preallocated_create.
extension secp256k1 {
    public enum Context: UInt32 {
        case none, sign, verify

        public var rawValue: UInt32 {
            let value: Int32

            switch self {
                case .none: value = SECP256K1_CONTEXT_NONE
                case .sign: value = SECP256K1_CONTEXT_SIGN
                case .verify: value = SECP256K1_CONTEXT_VERIFY
            }

            return UInt32(value)
        }

        public static func create(_ context: Context = .none) throws -> OpaquePointer {
            var randomBytes = SecureBytes(count: 32).bytes
            guard let context = secp256k1_context_create(context.rawValue),
                  secp256k1_context_randomize(context, &randomBytes) == 1 else {
                      throw secp256k1Error.underlyingCryptoError
            }

            return context
        }
    }
}

/// Flag to pass to secp256k1_ec_pubkey_serialize.
extension secp256k1 {
    public enum Format: UInt32 {
        case compressed, uncompressed

        public var length: Int {
            switch self {
                case .compressed: return 33
                case .uncompressed: return 65
            }
        }

        public var rawValue: UInt32 {
            let value: Int32

            switch self {
                case .compressed: value = SECP256K1_EC_COMPRESSED
                case .uncompressed: value = SECP256K1_EC_UNCOMPRESSED
            }

            return UInt32(value)
        }
    }
}

extension secp256k1 {
    @usableFromInline
    struct CurveDetails {
        @inlinable
        static var coordinateByteCount: Int {
            16
        }
    }
}

/// The secp256k1 Elliptic Curve.
extension secp256k1 {
    /// Signing operations on secp256k1
    public enum Signing {
        /// A Private Key for signing.
        public struct PrivateKey: ECPrivateKey, Equatable {
            /// Generated secp256k1 Signing Key.
            private var baseKey: secp256k1.Signing.PrivateKeyImplementation

            /// The secp256k1 private key object
            var key: SecureBytes {
                baseKey.key
            }

            /// ECDSA Signing object.
            public var ecdsa: secp256k1.Signing.ECDSASigner

            /// Schnorr Signing object.
            public var schnorr: secp256k1.Signing.SchnorrSigner

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
                baseKey = try secp256k1.Signing.PrivateKeyImplementation(format: format)
                ecdsa = secp256k1.Signing.ECDSASigner(signingKey: baseKey)
                schnorr = secp256k1.Signing.SchnorrSigner(signingKey: baseKey)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                baseKey = try secp256k1.Signing.PrivateKeyImplementation(rawRepresentation: data, format: format)
                ecdsa = secp256k1.Signing.ECDSASigner(signingKey: baseKey)
                schnorr = secp256k1.Signing.SchnorrSigner(signingKey: baseKey)
            }

            public static func == (lhs: secp256k1.Signing.PrivateKey, rhs: secp256k1.Signing.PrivateKey) -> Bool {
                lhs.key == rhs.key
            }
        }

        /// The corresponding public key.
        public struct PublicKey {
            /// Generated secp256k1 public key.
            private var baseKey: secp256k1.Signing.PublicKeyImplementation

            /// The secp256k1 public key object
            var keyBytes: [UInt8] {
                baseKey.keyBytes
            }

            /// ECDSA Validating object.
            public var ecdsa: secp256k1.Signing.ECDSAValidator

            /// Schnorr Validating object.
            public var schnorr: secp256k1.Signing.SchnorrValidator

            /// A data representation of the public key
            public var rawRepresentation: Data {
                baseKey.rawRepresentation
            }

            public var xonlyKeyBytes: [UInt8] {
                baseKey.xonlyKeyBytes
            }

            /// A key format representation of the public key
            public var format: secp256k1.Format {
                baseKey.format
            }

            /// Generates a secp256k1 public key.
            /// - Parameter baseKey: generated secp256k1 public key.
            fileprivate init(baseKey: secp256k1.Signing.PublicKeyImplementation) {
                self.baseKey = baseKey
                ecdsa = secp256k1.Signing.ECDSAValidator(validatingKey: baseKey)
                schnorr = secp256k1.Signing.SchnorrValidator(validatingKey: baseKey)
            }

            /// Generates a secp256k1 public key from a raw representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a public key.
            public init<D: ContiguousBytes>(rawRepresentation data: D, xonlyRawRepresentation xonly: D, format: secp256k1.Format) {
                baseKey = secp256k1.Signing.PublicKeyImplementation(rawRepresentation: data, xonlyRawRepresentation: xonly, format: format)
                ecdsa = secp256k1.Signing.ECDSAValidator(validatingKey: baseKey)
                schnorr = secp256k1.Signing.SchnorrValidator(validatingKey: baseKey)
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
        @usableFromInline var _publicKeys: PubKeyBytes

        /// Backing public key format
        @usableFromInline let _format: secp256k1.Format

        /// Backing implementation for a public key object
        @usableFromInline var publicKey: secp256k1.Signing.PublicKeyImplementation {
            PublicKeyImplementation(_publicKeys, format: _format)
        }

        /// Backing secp256k1 private key object
        var key: SecureBytes {
            _privateKey
        }

        /// A data representation of the backing private key
        @usableFromInline var rawRepresentation: Data {
            Data(_privateKey)
        }

        /// Private key length
        static var byteCount: Int = 2 * secp256k1.CurveDetails.coordinateByteCount

        /// Backing initialization that creates a random secp256k1 private key for signing
        @usableFromInline init(format: secp256k1.Format = .compressed) throws {
            let privateKey = SecureBytes(count: Self.byteCount)
            let pubKeys = try secp256k1.Signing.PublicKeyImplementation.generatePublicKey(bytes: privateKey.backing.bytes, format: format)

            // Save
            _privateKey = privateKey
            _publicKeys = pubKeys
            _format = format
        }

        /// Backing initialization that creates a secp256k1 private key for signing from a data representation.
        /// - Parameter data: A raw representation of the key.
        /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
        init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
            let privateKey = SecureBytes(bytes: data)
            let pubKeys = try secp256k1.Signing.PublicKeyImplementation.generatePublicKey(bytes: privateKey.backing.bytes, format: format)

            // Save
            _privateKey = privateKey
            _publicKeys = pubKeys
            _format = format
        }
    }

    @usableFromInline struct PubKeyBytes {
        /// ECDSA Public key object
        @usableFromInline let keyBytes: [UInt8]

        /// Schnorr X-Only Public key object
        @usableFromInline let xonlyKeyBytes: [UInt8]
    }

    /// Public key for signing implementation
    @usableFromInline struct PublicKeyImplementation {
        /// Implementation public key object
        @usableFromInline let publicKeys: secp256k1.Signing.PubKeyBytes

        /// Implementation public key object
        @usableFromInline var keyBytes: [UInt8] {
            publicKeys.keyBytes
        }

        /// A data representation of the backing public key
        @usableFromInline var rawRepresentation: Data {
            Data(keyBytes)
        }

        /// The Schnorr x-only public key object
        @usableFromInline var xonlyKeyBytes: [UInt8] {
            publicKeys.xonlyKeyBytes
        }

        /// A key format representation of the backing public key
        @usableFromInline let format: secp256k1.Format

        /// Backing initialization that generates a secp256k1 public key from a raw representation.
        /// - Parameter data: A raw representation of the key.
        @usableFromInline init<D: ContiguousBytes>(rawRepresentation data: D, xonlyRawRepresentation xonly: D, format: secp256k1.Format) {
            publicKeys = secp256k1.Signing.PubKeyBytes(keyBytes: data.bytes, xonlyKeyBytes: xonly.bytes)
            self.format = format
        }

        /// Backing initialization that sets the public key from a public key object.
        /// - Parameter keyBytes: a public key object
        @usableFromInline init(_ publicKeys: secp256k1.Signing.PubKeyBytes, format: secp256k1.Format) {
            self.publicKeys = publicKeys
            self.format = format
        }

        /// Generates a secp256k1 public key from bytes representation.
        /// - Parameter privKey: a private key object
        /// - Returns: a public key object
        /// - Throws: An error is thrown when the bytes does not create a public key. 
        static func generatePublicKey(bytes privKey: [UInt8], format: secp256k1.Format) throws -> PubKeyBytes {
            guard privKey.count == secp256k1.Signing.PrivateKeyImplementation.byteCount else {
                throw secp256k1Error.incorrectKeySize
            }

            let context = try secp256k1.Context.create()

            defer { secp256k1_context_destroy(context) }

            // ECDSA
            var pubKeyLen = format.length
            var pubKey = secp256k1_pubkey()
            var keyBytes = [UInt8](repeating: 0, count: pubKeyLen)

            guard secp256k1_ec_pubkey_create(context, &pubKey, privKey) == 1,
                  secp256k1_ec_pubkey_serialize(context, &keyBytes, &pubKeyLen, &pubKey, format.rawValue) == 1 else {
                      throw secp256k1Error.underlyingCryptoError
            }

            // Schnorr
            var keypair = secp256k1_keypair()
            var xonlyPubKey = secp256k1_xonly_pubkey()
            var xonlyKeyBytes = [UInt8](repeating: 0, count: 32)

            guard secp256k1_keypair_create(context, &keypair, privKey) == 1,
                  secp256k1_keypair_xonly_pub(context, &xonlyPubKey, nil, &keypair) == 1,
                  secp256k1_xonly_pubkey_serialize(context, &xonlyKeyBytes, &xonlyPubKey) == 1 else {
                      throw secp256k1Error.underlyingCryptoError
            }

            return PubKeyBytes(keyBytes: keyBytes, xonlyKeyBytes: xonlyKeyBytes)
        }
    }
}
