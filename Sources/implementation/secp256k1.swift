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
                  secp256k1_context_randomize(context, &randomBytes).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return context
        }

        static let raw = try! secp256k1.Context.create()
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
            32
        }
    }
}

/// Implementations for signing, we use bindings to libsecp256k1 for these operations.

/// Private key for signing implementation
@usableFromInline struct PrivateKeyImplementation {
    /// Backing private key object
    private var _privateBytes: SecureBytes

    /// Backing public key object
    @usableFromInline let _publicBytes: [UInt8]

    /// Backing x-only public key object
    @usableFromInline let _xonlyBytes: [UInt8]

    /// Backing public key format
    @usableFromInline let _format: secp256k1.Format

    /// Backing implementation for a public key object
    @usableFromInline var publicKey: PublicKeyImplementation {
        PublicKeyImplementation(_publicBytes, xonly: _xonlyBytes, format: _format)
    }

    /// Backing secp256k1 private key object
    var key: SecureBytes {
        _privateBytes
    }

    /// A data representation of the backing private key
    @usableFromInline var rawRepresentation: Data {
        Data(_privateBytes)
    }

    /// Backing initialization that creates a random secp256k1 private key for signing
    @usableFromInline init(format: secp256k1.Format = .compressed) throws {
        let privateKey = SecureBytes(count: secp256k1.ByteDetails.count)
        // Verify Private Key here
        self._format = format
        self._privateBytes = privateKey
        self._publicBytes = try PublicKeyImplementation.generate(bytes: privateKey, format: format)
        self._xonlyBytes = try XonlyKeyImplementation.generate(bytes: _publicBytes, format: format)
    }

    /// Backing initialization that creates a secp256k1 private key for signing from a data representation.
    /// - Parameter data: A raw representation of the key.
    /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
    init<D: ContiguousBytes>(rawRepresentation data: D, format: secp256k1.Format = .compressed) throws {
        let privateKey = SecureBytes(bytes: data)
        // Verify Private Key here
        self._format = format
        self._privateBytes = privateKey
        self._publicBytes = try PublicKeyImplementation.generate(bytes: privateKey, format: format)
        self._xonlyBytes = try XonlyKeyImplementation.generate(bytes: _publicBytes, format: format)
    }
}

/// Public key for signing implementation
@usableFromInline struct PublicKeyImplementation {
    /// Implementation public key object
    @usableFromInline let bytes: [UInt8]

    /// Backing x-only public key object
    @usableFromInline let _xonlyBytes: [UInt8]

    /// Backing implementation for a public key object
    @usableFromInline var xonly: XonlyKeyImplementation {
        XonlyKeyImplementation(_xonlyBytes)
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

        var pubKeyLen = format.length
        var pubKey = secp256k1_pubkey()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard secp256k1_ec_pubkey_create(secp256k1.Context.raw, &pubKey, privateBytes.bytes).boolValue,
              secp256k1_ec_pubkey_serialize(secp256k1.Context.raw, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return pubBytes
    }
}

/// Public X-only public key for Schnorr implementation
@usableFromInline struct XonlyKeyImplementation {
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
    static func generate(bytes publicBytes: [UInt8], format: secp256k1.Format) throws -> [UInt8] {
        guard publicBytes.count == format.length else {
            throw secp256k1Error.incorrectKeySize
        }

        var pubKey = secp256k1_pubkey()
        var xonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.ByteDetails.count)

        guard secp256k1_ec_pubkey_parse(secp256k1.Context.raw, &pubKey, publicBytes, format.length).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(secp256k1.Context.raw, &xonlyPubKey, nil, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(secp256k1.Context.raw, &xonlyBytes, &xonlyPubKey).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return xonlyBytes
    }
}
