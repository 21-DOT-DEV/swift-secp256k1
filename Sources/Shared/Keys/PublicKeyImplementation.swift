//
//  PublicKeyImplementation.swift
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

/// Internal backing implementation for a validated secp256k1 public key, storing serialized bytes, the derived x-only key, key parity, and an optional MuSig2 aggregation cache.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
@usableFromInline struct PublicKeyImplementation: Sendable {
    /// Serialized secp256k1 public key bytes in the key's ``P256K/Format``, as output by `secp256k1_ec_pubkey_serialize`.
    @usableFromInline let bytes: [UInt8]

    /// Serialized x-only public key bytes (32-byte X coordinate), as output by `secp256k1_xonly_pubkey_serialize`.
    @usableFromInline let xonlyBytes: [UInt8]

    /// Parity of the public key's Y coordinate: 0 if Y is even, 1 if Y is odd, as returned by `secp256k1_xonly_pubkey_from_pubkey`.
    @usableFromInline let keyParity: Int32

    /// A key format representation of the backing public key
    @usableFromInline let format: P256K.Format

    /// Serialized MuSig2 public key aggregation cache, populated when this key was created as part of an aggregate key computation. Empty for non-aggregated keys.
    @usableFromInline let cache: [UInt8]

    /// The x-only public key derived from this public key, used for Schnorr signature verification.
    @usableFromInline var xonly: XonlyKeyImplementation {
        XonlyKeyImplementation(xonlyBytes, keyParity: keyParity, cache: cache)
    }

    /// The serialized public key bytes as `Data`, in the key's ``P256K/Format``.
    @usableFromInline var dataRepresentation: Data {
        Data(bytes)
    }

    /// The 65-byte uncompressed representation of this public key, produced by `secp256k1_ec_pubkey_serialize` with `SECP256K1_EC_UNCOMPRESSED`.
    var uncompressedRepresentation: Data {
        let context = P256K.Context.rawRepresentation
        var pubKey = rawRepresentation
        var pubKeyLen = P256K.ByteLength.uncompressedPublicKey
        var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        _ = secp256k1_ec_pubkey_serialize(
            context,
            &pubKeyBytes,
            &pubKeyLen,
            &pubKey,
            P256K.Format.uncompressed.rawValue
        )

        return Data(pubKeyBytes)
    }

    /// The parsed `secp256k1_pubkey` struct reconstructed from `bytes` via `secp256k1_ec_pubkey_parse`.
    var rawRepresentation: secp256k1_pubkey {
        var pubKey = secp256k1_pubkey()
        _ = secp256k1_ec_pubkey_parse(P256K.Context.rawRepresentation, &pubKey, bytes, bytes.count)
        return pubKey
    }

    /// The additive inverse of this public key on the secp256k1 curve, produced by `secp256k1_ec_pubkey_negate`.
    @usableFromInline var negation: Self {
        let context = P256K.Context.rawRepresentation
        var key = rawRepresentation
        var keyLength = format.length
        var bytes = [UInt8](repeating: 0, count: keyLength)

        guard secp256k1_ec_pubkey_negate(context, &key).boolValue,
              secp256k1_ec_pubkey_serialize(context, &bytes, &keyLength, &key, format.rawValue).boolValue else {
            fatalError("secp256k1_ec_pubkey_negate or serialize failed — library bug")
        }

        return Self(validatedBytes: bytes, format: format)
    }

    /// Backing initialization that generates a secp256k1 public key from only a data representation and key format.
    /// - Parameters:
    ///   - data: A data representation of the public key.
    ///   - format: an enum that represents the format of the public key
    @usableFromInline init<D: ContiguousBytes>(
        dataRepresentation data: D,
        format: P256K.Format,
        cache: [UInt8] = []
    ) throws {
        var keyParity = Int32()

        self.xonlyBytes = try XonlyKeyImplementation.generate(
            bytes: data.bytes,
            keyParity: &keyParity,
            format: format
        )

        self.bytes = data.bytes
        self.format = format
        self.cache = cache.bytes
        self.keyParity = keyParity
    }

    /// Backing initialization that sets the public key from a public key object.
    /// - Parameter keyBytes: a public key object
    @usableFromInline init(
        _ bytes: [UInt8],
        xonly: [UInt8],
        keyParity: Int32,
        format: P256K.Format,
        cache: [UInt8] = []
    ) {
        self.bytes = bytes
        self.format = format
        self.cache = cache
        self.xonlyBytes = xonly
        self.keyParity = keyParity
    }

    /// Non-throwing initialization for bytes already proven valid by a libsecp256k1 operation (e.g. negation).
    init(validatedBytes bytes: [UInt8], format: P256K.Format, cache: [UInt8] = []) {
        let context = P256K.Context.rawRepresentation
        var keyParity = Int32()
        var pubKey = secp256k1_pubkey()
        var xonlyPubKey = secp256k1_xonly_pubkey()
        var xonlyBytes = [UInt8](repeating: 0, count: P256K.ByteLength.privateKey)

        precondition(
            secp256k1_ec_pubkey_parse(context, &pubKey, bytes, format.length).boolValue &&
                secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubKey, &keyParity, &pubKey).boolValue &&
                secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey).boolValue,
            "X-only key generation failed for validated public key"
        )

        self.bytes = bytes
        self.format = format
        self.cache = cache
        self.xonlyBytes = xonlyBytes
        self.keyParity = keyParity
    }

    /// Backing initialization that sets the public key from a xonly key object.
    /// - Parameter xonlyKey: a xonly key object
    @usableFromInline init(xonlyKey: XonlyKeyImplementation) {
        let yCoord: [UInt8] = xonlyKey.keyParity.boolValue ? [3] : [2]

        self.format = .compressed
        self.cache = xonlyKey.cache
        self.xonlyBytes = xonlyKey.bytes
        self.keyParity = xonlyKey.keyParity
        self.bytes = yCoord + xonlyKey.bytes
    }

    #if Xcode || ENABLE_MODULE_RECOVERY
        /// Backing initialization that sets the public key from a digest and recoverable signature.
        /// - Parameters:
        ///   - digest: The digest that was signed.
        ///   - signature: The signature to recover the public key from
        ///   - format: the format of the public key object
        @usableFromInline init<D: Digest>(
            _ digest: D,
            signature: P256K.Recovery.ECDSASignature,
            format: P256K.Format
        ) {
            let context = P256K.Context.rawRepresentation
            var keyParity = Int32()
            var pubKeyLen = format.length
            var pubKey = secp256k1_pubkey()
            var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)
            var recoverySignature = secp256k1_ecdsa_recoverable_signature()

            signature.dataRepresentation.copyToUnsafeMutableBytes(of: &recoverySignature.data)

            guard secp256k1_ecdsa_recover(context, &pubKey, &recoverySignature, Array(digest)).boolValue,
                  secp256k1_ec_pubkey_serialize(context, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue else {
                fatalError("secp256k1_ecdsa_recover failed with valid signature — library bug")
            }

            var xonlyPubKey = secp256k1_xonly_pubkey()
            var xonlyBytes = [UInt8](repeating: 0, count: P256K.ByteLength.privateKey)

            precondition(
                secp256k1_ec_pubkey_parse(context, &pubKey, pubBytes, format.length).boolValue &&
                    secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubKey, &keyParity, &pubKey).boolValue &&
                    secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &xonlyPubKey).boolValue,
                "X-only key generation failed for recovered public key"
            )

            self.xonlyBytes = xonlyBytes
            self.keyParity = keyParity
            self.format = format
            self.cache = []
            self.bytes = pubBytes
        }
    #endif

    /// Generates a serialized secp256k1 public key from a private key using `secp256k1_ec_pubkey_create` and `secp256k1_ec_pubkey_serialize`.
    /// - Parameter privateBytes: A 32-byte private key as `SecureBytes`; must pass `secp256k1_ec_seckey_verify`.
    /// - Parameter format: The output serialization format.
    /// - Returns: The serialized public key bytes in the requested format.
    /// - Throws: ``secp256k1Error/incorrectKeySize`` if `privateBytes` is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if key generation fails.
    static func generate(
        bytes privateBytes: inout SecureBytes,
        format: P256K.Format
    ) throws -> [UInt8] {
        guard privateBytes.count == P256K.ByteLength.privateKey else {
            throw secp256k1Error.incorrectKeySize
        }

        let context = P256K.Context.rawRepresentation
        var pubKeyLen = format.length
        var pubKey = secp256k1_pubkey()
        var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard secp256k1_ec_seckey_verify(context, privateBytes.bytes).boolValue,
              secp256k1_ec_pubkey_create(context, &pubKey, privateBytes.bytes).boolValue,
              secp256k1_ec_pubkey_serialize(context, &pubBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue
        else {
            throw secp256k1Error.underlyingCryptoError
        }

        return pubBytes
    }
}
