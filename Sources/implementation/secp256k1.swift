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
public extension secp256k1 {
    enum Context: UInt32 {
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
            var randomBytes = SecureBytes(count: secp256k1.ByteDetails.count).bytes
            guard let context = secp256k1_context_create(context.rawValue),
                  secp256k1_context_randomize(context, &randomBytes) == 1 else {
                throw secp256k1Error.underlyingCryptoError
            }

            return context
        }
    }
}

/// Flag to pass to secp256k1_ec_pubkey_serialize.
public extension secp256k1 {
    enum Format: UInt32 {
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
    enum CurveDetails {
        @inlinable
        static var coordinateByteCount: Int {
            16
        }
    }

    @usableFromInline
    enum ByteDetails {
        @inlinable
        static var count: Int {
            secp256k1.CurveDetails.coordinateByteCount * 2
        }
    }
}

/// The secp256k1 Elliptic Curve.
public extension secp256k1 {
    /// Signing operations on secp256k1
    enum Signing {
        /// A Private Key for signing.
        public struct PrivateKey: ECPrivateKey, Equatable {
            /// Generated secp256k1 Signing Key.
            private var baseKey: secp256k1.Signing.PrivateKeyImplementation

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
                self.baseKey = try secp256k1.Signing.PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
            public init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try secp256k1.Signing.PrivateKeyImplementation(rawRepresentation: data, format: format)
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
            public var xonly: XonlyPublicKey {
                XonlyPublicKey(baseKey: baseKey.xonly)
            }

            /// A key format representation of the public key
            public var format: secp256k1.Format {
                baseKey.format
            }

            /// Generates a secp256k1 public key.
            /// - Parameter baseKey: generated secp256k1 public key.
            fileprivate init(baseKey: secp256k1.Signing.PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 public key from a raw representation.
            /// - Parameter data: A raw representation of the key.
            /// - Throws: An error is thrown when the raw representation does not create a public key.
            public init<D: ContiguousBytes>(rawRepresentation data: D, xonly: D, format: secp256k1.Format) {
                self.baseKey = secp256k1.Signing.PublicKeyImplementation(rawRepresentation: data, xonly: xonly, format: format)
            }
        }

        /// The corresponding x-only public key.
        public struct XonlyPublicKey {
            /// Generated secp256k1 x-only public key.
            private var baseKey: secp256k1.Signing.XonlyPublicKeyImplementation

            /// The secp256k1 x-only public key object
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            fileprivate init(baseKey: secp256k1.Signing.XonlyPublicKeyImplementation) {
                self.baseKey = baseKey
            }

            public init<D: ContiguousBytes>(rawRepresentation data: D) {
                self.baseKey = secp256k1.Signing.XonlyPublicKeyImplementation(rawRepresentation: data)
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

        /// Backing x-only public key object
        @usableFromInline var _xonlyPublicKey: [UInt8]

        /// Backing public key format
        @usableFromInline let _format: secp256k1.Format

        /// Backing implementation for a public key object
        @usableFromInline var publicKey: secp256k1.Signing.PublicKeyImplementation {
            PublicKeyImplementation(_publicKey, xonly: _xonlyPublicKey, format: _format)
        }

        /// Backing secp256k1 private key object
        var key: SecureBytes {
            _privateKey
        }

        /// A data representation of the backing private key
        @usableFromInline var rawRepresentation: Data {
            Data(_privateKey)
        }

        /// Backing initialization that creates a random secp256k1 private key for signing
        @usableFromInline init(format: secp256k1.Format = .compressed) throws {
            let privateKey = SecureBytes(count: secp256k1.ByteDetails.count)

            self._privateKey = privateKey
            self._publicKey = try secp256k1.Signing.PublicKeyImplementation.generate(bytes: privateKey, format: format)
            self._xonlyPublicKey = try secp256k1.Signing.XonlyPublicKeyImplementation.generate(bytes: privateKey)
            self._format = format
        }

        /// Backing initialization that creates a secp256k1 private key for signing from a data representation.
        /// - Parameter data: A raw representation of the key.
        /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
        init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
            let privateKey = SecureBytes(bytes: data)

            self._privateKey = privateKey
            self._publicKey = try secp256k1.Signing.PublicKeyImplementation.generate(bytes: privateKey, format: format)
            self._xonlyPublicKey = try secp256k1.Signing.XonlyPublicKeyImplementation.generate(bytes: privateKey)
            self._format = format
        }
    }

    /// Public key for signing implementation
    @usableFromInline struct PublicKeyImplementation {
        /// Implementation public key object
        @usableFromInline let bytes: [UInt8]

        /// Backing x-only public key object
        @usableFromInline var _xonlyBytes: [UInt8]

        /// Backing implementation for a public key object
        @usableFromInline var xonly: secp256k1.Signing.XonlyPublicKeyImplementation {
            XonlyPublicKeyImplementation(_xonlyBytes)
        }

        /// A data representation of the backing public key
        @usableFromInline var rawRepresentation: Data {
            Data(bytes)
        }

        /// A key format representation of the backing public key
        @usableFromInline let format: secp256k1.Format

        /// Backing initialization that generates a secp256k1 public key from a raw representation.
        /// - Parameter data: A raw representation of the key.
        @usableFromInline init<D: ContiguousBytes>(rawRepresentation data: D, xonly: D, format: secp256k1.Format) {
            self.bytes = data.bytes
            self.format = format
            self._xonlyBytes = xonly.bytes
        }

        /// Backing initialization that sets the public key from a public key object.
        /// - Parameter keyBytes: a public key object
        @usableFromInline init(_ bytes: [UInt8], xonly: [UInt8], format: secp256k1.Format) {
            self.bytes = bytes
            self.format = format
            self._xonlyBytes = xonly
        }

        /// Generates a secp256k1 public key from bytes representation.
        /// - Parameter privateBytes: a private key object in bytes form
        /// - Returns: a public key object
        /// - Throws: An error is thrown when the bytes does not create a public key.
        static func generate(bytes privateBytes: SecureBytes, format: secp256k1.Format) throws -> [UInt8] {
            guard privateBytes.count == secp256k1.ByteDetails.count else {
                throw secp256k1Error.incorrectKeySize
            }

            let context = try secp256k1.Context.create()

            defer { secp256k1_context_destroy(context) }

            var pubKeyLen = format.length
            var pubKey = secp256k1_pubkey()
            var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

            guard secp256k1_ec_pubkey_create(context, &pubKey, privateBytes.bytes) == 1,
                  secp256k1_ec_pubkey_serialize(context, &pubBytes, &pubKeyLen, &pubKey, format.rawValue) == 1 else {
                throw secp256k1Error.underlyingCryptoError
            }

            return pubBytes
        }
    }

    /// Public X-only public key for Schnorr implementation
    @usableFromInline struct XonlyPublicKeyImplementation {
        /// Implementation x-only public key object
        @usableFromInline let bytes: [UInt8]

        /// A data representation of the backing x-only public key
        @usableFromInline var rawRepresentation: Data {
            Data(bytes)
        }

        /// Backing initialization that generates a x-only public key from a raw representation.
        /// - Parameter data: A raw representation of the key.
        @usableFromInline init<D: ContiguousBytes>(rawRepresentation data: D) {
            self.bytes = data.bytes
        }

        /// Backing initialization that sets the public key from a x-only public key object.
        /// - Parameter bytes: a x-only public key in byte form
        @usableFromInline init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }

        /// Create a x-only public key from bytes representation.
        /// - Parameter privateBytes: a private key object in byte form
        /// - Returns: a public key object
        /// - Throws: An error is thrown when the bytes does not create a public key.
        static func generate(bytes privateBytes: SecureBytes) throws -> [UInt8] {
            guard privateBytes.count == secp256k1.ByteDetails.count else {
                throw secp256k1Error.incorrectKeySize
            }

            let context = try secp256k1.Context.create()

            defer { secp256k1_context_destroy(context) }

            var keypair = secp256k1_keypair()
            var xonlyPubKey = secp256k1_xonly_pubkey()
            var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.ByteDetails.count)

            guard secp256k1_keypair_create(context, &keypair, privateBytes.bytes) == 1,
                  secp256k1_keypair_xonly_pub(context, &xonlyPubKey, nil, &keypair) == 1,
                  secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey) == 1 else {
                throw secp256k1Error.underlyingCryptoError
            }

            return xonlyBytes
        }
    }
}
