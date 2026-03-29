//
//  PrivateKeyImplementation.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
#if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
    public import SwiftSystem
#else
    #if canImport(FoundationEssentials)
        public import FoundationEssentials
    #else
        public import Foundation
    #endif
#endif

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// Internal backing implementation for a secp256k1 private key, storing 32 secret bytes as `SecureBytes` alongside the derived public key, x-only key, and key parity.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
@usableFromInline struct PrivateKeyImplementation: Sendable {
    /// The raw 32-byte secret key, stored in `SecureBytes` to prevent accidental disclosure.
    private var privateBytes: SecureBytes

    /// The raw 32-byte secret key as `SecureBytes`.
    var key: SecureBytes {
        privateBytes
    }

    /// Serialized secp256k1 public key bytes derived from `privateBytes` via `secp256k1_ec_pubkey_create` and `secp256k1_ec_pubkey_serialize`.
    @usableFromInline let publicBytes: [UInt8]

    /// Serialized x-only public key bytes (32-byte X coordinate) derived from `publicBytes` via `secp256k1_xonly_pubkey_serialize`.
    @usableFromInline let xonlyBytes: [UInt8]

    /// Serialization format of `publicBytes`.
    @usableFromInline let format: P256K.Format

    /// Parity of the public key's Y coordinate: 0 if even, 1 if odd, as returned by `secp256k1_xonly_pubkey_from_pubkey`.
    @usableFromInline var keyParity: Int32

    /// The public key implementation derived from this private key.
    @usableFromInline var publicKey: PublicKeyImplementation {
        PublicKeyImplementation(publicBytes, xonly: xonlyBytes, keyParity: keyParity, format: format)
    }

    /// The additive inverse of this private key modulo the secp256k1 curve order, produced by `secp256k1_ec_seckey_negate`.
    @usableFromInline var negation: Self {
        var privateBytes = privateBytes.bytes
        guard secp256k1_ec_seckey_negate(P256K.Context.rawRepresentation, &privateBytes).boolValue else {
            fatalError("secp256k1_ec_seckey_negate failed with valid key — library bug")
        }

        return Self(validatedBytes: privateBytes, format: format)
    }

    /// The raw 32-byte private key as `Data`. Handle with care — this exposes the secret key material.
    @usableFromInline var dataRepresentation: Data {
        Data(privateBytes)
    }

    /// Backing initialization that creates a random secp256k1 private key for signing
    @usableFromInline init(format: P256K.Format = .compressed) throws {
        let privateKey = SecureBytes(count: P256K.ByteLength.privateKey)
        self.keyParity = 0
        self.format = format
        self.privateBytes = privateKey
        self.publicBytes = try PublicKeyImplementation.generate(bytes: &privateBytes, format: format)
        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: publicBytes,
            keyParity: &keyParity,
            format: format
        )
    }

    /// Backing initialization that creates a secp256k1 private key for signing from a data representation.
    /// - Parameter data: A raw representation of the key.
    /// - Throws: An error is thrown when the raw representation does not create a private key for signing.
    init<D: ContiguousBytes>(
        dataRepresentation data: D,
        format: P256K.Format = .compressed
    ) throws {
        let privateKey = SecureBytes(bytes: data)
        // Verify Private Key here
        self.keyParity = 0
        self.format = format
        self.privateBytes = privateKey
        self.publicBytes = try PublicKeyImplementation.generate(bytes: &privateBytes, format: format)
        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: publicBytes,
            keyParity: &keyParity,
            format: format
        )
    }

    /// Non-throwing initialization for bytes already proven valid by a libsecp256k1 operation (e.g. negation).
    init(validatedBytes bytes: [UInt8], format: P256K.Format) {
        let context = P256K.Context.rawRepresentation
        let privateKey = SecureBytes(bytes: bytes)
        var keyParity = Int32()
        var pubKeyLen = format.length
        var pubKey = secp256k1_pubkey()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)
        var xonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: P256K.ByteLength.privateKey)

        precondition(
            secp256k1_ec_seckey_verify(context, privateKey.bytes).boolValue &&
                secp256k1_ec_pubkey_create(context, &pubKey, privateKey.bytes).boolValue &&
                secp256k1_ec_pubkey_serialize(context, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue,
            "Public key generation failed for validated private key"
        )

        precondition(
            secp256k1_ec_pubkey_parse(context, &pubKey, pubBytes, format.length).boolValue &&
                secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubKey, &keyParity, &pubKey).boolValue &&
                secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey).boolValue,
            "X-only key generation failed for validated private key"
        )

        self.keyParity = keyParity
        self.format = format
        self.privateBytes = privateKey
        self.publicBytes = pubBytes
        self.xonlyBytes = xonlyBytes
    }
}
