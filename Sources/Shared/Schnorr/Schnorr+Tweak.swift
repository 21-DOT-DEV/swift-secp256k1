//
//  Schnorr+Tweak.swift
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
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr.PrivateKey {
        /// Creates a new ``P256K/Schnorr/PrivateKey`` by applying a BIP-341 Taproot x-only
        /// tweak to the secret scalar via `secp256k1_keypair_xonly_tweak_add` (declared in
        /// [`Vendor/secp256k1/include/secp256k1_extrakeys.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_extrakeys.h)).
        ///
        /// When the x-only representation of the current key has odd Y, the upstream keypair
        /// helper implicitly negates the secret scalar before applying the tweak so the
        /// resulting keypair has even Y (the canonical BIP-340 form). See upstream discussion
        /// at [bitcoin-core/secp256k1#1021](https://github.com/bitcoin-core/secp256k1/issues/1021#issuecomment-983021759).
        ///
        /// This is the signing-side companion to ``P256K/Schnorr/XonlyKey/add(_:)``; applying
        /// the same tweak to both forms yields a valid `(sk', xonly')` pair for
        /// [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
        /// Taproot key-path spending.
        ///
        /// - Parameter tweak: A 32-byte tweak scalar (typically the output of a Taproot
        ///   `TapTweak` tagged hash).
        /// - Returns: A new ``P256K/Schnorr/PrivateKey`` whose x-only public key is the
        ///   Taproot-tweaked form of the original.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or
        ///   any upstream step fails.
        func add(_ tweak: [UInt8]) throws -> Self {
            let context = P256K.Context.rawRepresentation
            var keypair = secp256k1_keypair()
            var privateBytes = [UInt8](repeating: 0, count: P256K.ByteLength.privateKey)
            var xonly = secp256k1_xonly_pubkey()
            var keyParity = Int32()

            guard secp256k1_keypair_create(context, &keypair, key.bytes).boolValue,
                  secp256k1_keypair_xonly_tweak_add(context, &keypair, tweak).boolValue,
                  secp256k1_keypair_sec(context, &privateBytes, &keypair).boolValue,
                  secp256k1_keypair_xonly_pub(context, &xonly, &keyParity, &keypair).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return Self(baseKey: PrivateKeyImplementation(validatedBytes: privateBytes, format: .compressed))
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr.XonlyKey {
        /// Creates a new ``P256K/Schnorr/XonlyKey`` by applying a BIP-341 Taproot tweak to
        /// the x-only public key via `secp256k1_xonly_pubkey_tweak_add` and verifies the
        /// result with `secp256k1_xonly_pubkey_tweak_add_check`.
        ///
        /// This is the verifier-side companion to
        /// ``P256K/Schnorr/PrivateKey/add(_:)`` — the same 32-byte tweak applied to both a
        /// private key and its x-only public key yields a valid `(sk', xonly')` pair for
        /// Taproot key-path spending. The verification check at the end catches
        /// inconsistent tweak + parity combinations that would otherwise produce a
        /// never-verifying output key.
        ///
        /// - Parameter tweak: A 32-byte tweak scalar (typically the output of a Taproot
        ///   `TapTweak` tagged hash).
        /// - Returns: A new ``P256K/Schnorr/XonlyKey`` equal to the Taproot-tweaked
        ///   x-only public key.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid, the
        ///   result is the point at infinity, or the consistency check fails.
        func add(_ tweak: [UInt8]) throws -> Self {
            let context = P256K.Context.rawRepresentation
            var pubKey = secp256k1_pubkey()
            var inXonlyPubKey = secp256k1_xonly_pubkey()
            var outXonlyPubKey = secp256k1_xonly_pubkey()
            var xonlyBytes = [UInt8](repeating: 0, count: P256K.ByteLength.dimension)
            var keyParity = Int32()

            guard secp256k1_xonly_pubkey_parse(context, &inXonlyPubKey, bytes).boolValue,
                  secp256k1_xonly_pubkey_tweak_add(context, &pubKey, &inXonlyPubKey, tweak).boolValue,
                  secp256k1_xonly_pubkey_from_pubkey(context, &outXonlyPubKey, &keyParity, &pubKey).boolValue,
                  secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &outXonlyPubKey).boolValue,
                  secp256k1_xonly_pubkey_tweak_add_check(context, &xonlyBytes, keyParity, &inXonlyPubKey, tweak).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return Self(dataRepresentation: xonlyBytes, keyParity: keyParity)
        }
    }
#endif
