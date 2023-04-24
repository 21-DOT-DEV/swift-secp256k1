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

/// The secp256k1 Elliptic Curve.
public enum secp256k1 {}

/// An extension to secp256k1 containing a Context structure that represents the flags
/// passed to secp256k1_context_create, secp256k1_context_preallocated_size, and secp256k1_context_preallocated_create.
public extension secp256k1 {
    struct Context: OptionSet {
        /// The raw representation of `secp256k1.Context`
        public static let rawRepresentation = try! secp256k1.Context.create()
        /// Raw value representing the underlying UInt32 flags.
        public let rawValue: UInt32

        /// Initializes a new Context with the specified raw value.
        /// - Parameter rawValue: The UInt32 raw value for the context flags.
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// Initializes a new Context with the specified raw value.
        /// - Parameter rawValue: The Int32 raw value for the context flags.
        init(rawValue: Int32) { self.rawValue = UInt32(rawValue) }

        /// No context flag.
        public static let none = Context(rawValue: SECP256K1_CONTEXT_NONE)

        /// Creates a new secp256k1 context with the specified flags.
        /// - Parameter context: The context flags to create a new secp256k1 context.
        /// - Throws: Throws an error if the context creation or randomization fails.
        /// - Returns: Returns an opaque pointer to the created context.
        public static func create(_ context: Context = .none) throws -> OpaquePointer {
            var randomBytes = SecureBytes(count: secp256k1.ByteDetails.count).bytes
            guard let context = secp256k1_context_create(context.rawValue),
                  secp256k1_context_randomize(context, &randomBytes).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return context
        }
    }
}

/// An extension to secp256k1 containing an enum for public key formats.
public extension secp256k1 {
    /// Enum representing public key formats to be passed to `secp256k1_ec_pubkey_serialize`.
    enum Format: UInt32 {
        /// Compressed public key format.
        case compressed
        /// Uncompressed public key format.
        case uncompressed

        /// The length of the public key in bytes, based on the format.
        public var length: Int {
            switch self {
            case .compressed: return 33
            case .uncompressed: return 65
            }
        }

        /// The raw UInt32 value corresponding to the public key format.
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

/// An extension for secp256k1 containing nested enums for curve and byte details.
extension secp256k1 {
    /// An enum containing details about the secp256k1 curve.
    @usableFromInline
    enum CurveDetails {
        /// The number of bytes in a coordinate of the secp256k1 curve.
        @inlinable
        static var coordinateByteCount: Int {
            16
        }
    }

    /// An enum containing details about bytes in secp256k1.
    @usableFromInline
    enum ByteDetails {
        /// The number of bytes in a secp256k1 object.
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
    private var privateBytes: SecureBytes

    /// Backing public key object
    @usableFromInline let publicBytes: [UInt8]

    /// Backing x-only public key object
    @usableFromInline let xonlyBytes: [UInt8]

    /// Backing public key format
    @usableFromInline let format: secp256k1.Format

    /// Backing strict adherence to BIP340
    @usableFromInline let strict: Bool

    /// Backing key parity
    @usableFromInline var keyParity: Int32

    /// Backing implementation for a public key object
    @usableFromInline var publicKey: PublicKeyImplementation {
        PublicKeyImplementation(publicBytes, xonly: xonlyBytes, keyParity: keyParity, format: format)
    }

    /// Backing secp256k1 private key object
    var key: SecureBytes {
        privateBytes
    }

    /// A data representation of the backing private key
    @usableFromInline var rawRepresentation: Data {
        Data(privateBytes)
    }

    /// Backing initialization that creates a random secp256k1 private key for signing
    @usableFromInline init(format: secp256k1.Format = .compressed, strict: Bool = false) throws {
        let privateKey = SecureBytes(count: secp256k1.ByteDetails.count)
        // Verify Private Key here
        self.keyParity = 0
        self.format = format
        self.strict = strict
        self.privateBytes = privateKey
        self.publicBytes = try PublicKeyImplementation.generate(bytes: &privateBytes, format: format, strict: strict)
        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: publicBytes,
            keyParity: &keyParity,
            format: format,
            strict: strict
        )
    }

    /// Backing initialization that creates a secp256k1 private key for signing from a data representation.
    /// - Parameter data: A raw representation of the key.
    /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
    init<D: ContiguousBytes>(
        rawRepresentation data: D,
        format: secp256k1.Format = .compressed,
        strict: Bool = false
    ) throws {
        let privateKey = SecureBytes(bytes: data)
        // Verify Private Key here
        self.keyParity = 0
        self.format = format
        self.strict = strict
        self.privateBytes = privateKey
        self.publicBytes = try PublicKeyImplementation.generate(bytes: &privateBytes, format: format, strict: strict)
        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: publicBytes,
            keyParity: &keyParity,
            format: format,
            strict: strict
        )
    }
}

/// Public key for signing implementation
@usableFromInline struct PublicKeyImplementation {
    /// Implementation public key object
    @usableFromInline let bytes: [UInt8]

    /// Backing x-only public key object
    @usableFromInline let xonlyBytes: [UInt8]

    /// Backing key parity object
    @usableFromInline let keyParity: Int32

    /// A key format representation of the backing public key
    @usableFromInline let format: secp256k1.Format

    /// Backing strict adherence to BIP340
    @usableFromInline let strict: Bool

    /// Backing implementation for a public key object
    @usableFromInline var xonly: XonlyKeyImplementation {
        XonlyKeyImplementation(xonlyBytes, keyParity: keyParity, strict: strict)
    }

    /// A data representation of the backing public key
    @usableFromInline var rawRepresentation: Data {
        Data(bytes)
    }

    /// Backing initialization that generates a secp256k1 public key from only a raw representation and key format.
    /// - Parameters:
    ///   - data: A raw representation of the public key.
    ///   - format: an enum that represents the format of the public key
    @usableFromInline init<D: ContiguousBytes>(
        rawRepresentation data: D,
        format: secp256k1.Format,
        strict: Bool = false
    ) throws {
        var keyParity = Int32()

        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: data.bytes,
            keyParity: &keyParity,
            format: format,
            strict: strict
        )

        self.bytes = data.bytes
        self.format = format
        self.strict = strict
        self.keyParity = keyParity
    }

    /// Backing initialization that sets the public key from a public key object.
    /// - Parameter keyBytes: a public key object
    @usableFromInline init(
        _ bytes: [UInt8],
        xonly: [UInt8],
        keyParity: Int32,
        format: secp256k1.Format,
        strict: Bool = false
    ) {
        self.bytes = bytes
        self.format = format
        self.strict = strict
        self.xonlyBytes = xonly
        self.keyParity = keyParity
    }

    /// Backing initialization that sets the public key from a xonly key object.
    /// - Parameter xonlyKey: a xonly key object
    @usableFromInline init(xonlyKey: XonlyKeyImplementation) {
        let yCoord: [UInt8] = xonlyKey.keyParity.boolValue ? [3] : [2]

        self.format = .compressed
        self.strict = xonlyKey.strict
        self.xonlyBytes = xonlyKey.bytes
        self.keyParity = xonlyKey.keyParity
        self.bytes = yCoord + xonlyKey.bytes
    }

    /// Backing initialization that sets the public key from a digest and recoverable signature.
    /// - Parameters:
    ///   - digest: The digest that was signed.
    ///   - signature: The signature to recover the public key from
    ///   - format: the format of the public key object
    /// - Throws: An error is thrown when a public key is not recoverable from the  signature.
    @usableFromInline init<D: Digest>(
        _ digest: D,
        signature: secp256k1.Recovery.ECDSASignature,
        format: secp256k1.Format
    ) throws {
        let context = secp256k1.Context.rawRepresentation
        var keyParity = Int32()
        var pubKeyLen = format.length
        var pubKey = secp256k1_pubkey()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var recoverySignature = secp256k1_ecdsa_recoverable_signature()

        signature.rawRepresentation.copyToUnsafeMutableBytes(of: &recoverySignature.data)

        guard secp256k1_ecdsa_recover(context, &pubKey, &recoverySignature, Array(digest)).boolValue,
              secp256k1_ec_pubkey_serialize(context, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: pubBytes,
            keyParity: &keyParity,
            format: format,
            strict: false
        )

        self.keyParity = keyParity
        self.format = format
        self.strict = false
        self.bytes = pubBytes
    }

    /// Generates a secp256k1 public key from bytes representation.
    /// - Parameter privateBytes: a private key object in bytes form
    /// - Returns: a public key object
    /// - Throws: An error is thrown when the bytes does not create a public key.
    static func generate(
        bytes privateBytes: inout SecureBytes,
        format: secp256k1.Format,
        strict: Bool
    ) throws -> [UInt8] {
        guard privateBytes.count == secp256k1.ByteDetails.count else {
            throw secp256k1Error.incorrectKeySize
        }

        let context = secp256k1.Context.rawRepresentation
        var pubKeyLen = format.length
        var keyParity = Int32()
        var pubKey = secp256k1_pubkey()
        var keypair = secp256k1_keypair()
        var xonly = secp256k1_xonly_pubkey()
        var pubBytes = [UInt8](repeating: 0, count: format.length)
        var secBytes = privateBytes.bytes

        // Verify seckey and get key parity for BIP340
        guard secp256k1_keypair_create(context, &keypair, privateBytes.bytes).boolValue,
              secp256k1_keypair_pub(context, &pubKey, &keypair).boolValue,
              secp256k1_keypair_xonly_pub(context, &xonly, &keyParity, &keypair).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        // For BIP340, negate the private key when the Y coordinate is odd
        if strict, keyParity.boolValue,
           secp256k1_ec_seckey_negate(context, &secBytes).boolValue {
            privateBytes = SecureBytes(bytes: secBytes)
        }

        guard secp256k1_ec_pubkey_serialize(context, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue else {
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

    /// Backing key parity object
    @usableFromInline let keyParity: Int32

    /// Backing strict adherence to BIP340
    @usableFromInline let strict: Bool

    /// Backing initialization that generates a x-only public key from a raw representation.
    /// - Parameter data: A raw representation of the key.
    @usableFromInline init<D: ContiguousBytes>(
        rawRepresentation data: D,
        keyParity: Int32,
        strict: Bool = false
    ) {
        self.bytes = data.bytes
        self.keyParity = keyParity
        self.strict = strict
    }

    /// Backing initialization that sets the public key from a x-only public key object.
    /// - Parameter bytes: a x-only public key in byte form
    @usableFromInline init(
        _ bytes: [UInt8],
        keyParity: Int32,
        strict: Bool = false
    ) {
        self.bytes = bytes
        self.keyParity = keyParity
        self.strict = strict
    }

    /// Create a x-only public key from bytes representation.
    /// - Parameter privateBytes: a private key object in byte form
    /// - Returns: a public key object
    /// - Throws: An error is thrown when the bytes does not create a public key.
    static func generate(
        bytes publicBytes: [UInt8],
        keyParity: inout Int32,
        format: secp256k1.Format,
        strict: Bool = false
    ) throws -> [UInt8] {
        guard publicBytes.count == format.length else {
            throw secp256k1Error.incorrectKeySize
        }

        let context = secp256k1.Context.rawRepresentation
        var pubKey = secp256k1_pubkey()
        var xonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: secp256k1.ByteDetails.count)

        guard secp256k1_ec_pubkey_parse(context, &pubKey, publicBytes, format.length).boolValue,
              secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubKey, &keyParity, &pubKey).boolValue,
              secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return xonlyBytes
    }
}
