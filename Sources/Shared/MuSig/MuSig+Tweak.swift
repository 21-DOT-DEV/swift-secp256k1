//
//  MuSig+Tweak.swift
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

#if Xcode || ENABLE_MODULE_MUSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig.PublicKey {
        /// Creates a new `PublicKey` by adding a tweak to the public key.
        ///
        /// This function implements the tweaking process for MuSig public keys as described in BIP-327.
        ///
        /// - Parameters:
        ///   - tweak: The 32-byte tweak to apply.
        ///   - format: The format of the tweaked `PublicKey` object.
        /// - Returns: A new tweaked `PublicKey` object.
        /// - Throws: An error if tweaking fails.
        func add(_ tweak: [UInt8], format: P256K.Format = .compressed) throws -> Self {
            let context = P256K.Context.rawRepresentation
            var pubKey = secp256k1_pubkey()
            var cache = secp256k1_musig_keyagg_cache()
            var pubKeyLen = format.length
            var pubKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

            keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)

            guard secp256k1_ec_pubkey_parse(context, &pubKey, bytes, pubKeyLen).boolValue,
                  secp256k1_musig_pubkey_ec_tweak_add(context, &pubKey, &cache, tweak).boolValue,
                  secp256k1_ec_pubkey_serialize(context, &pubKeyBytes, &pubKeyLen, &pubKey, format.rawValue).boolValue
            else {
                throw secp256k1Error.underlyingCryptoError
            }

            return Self(
                baseKey: PublicKeyImplementation(
                    validatedBytes: pubKeyBytes,
                    format: format,
                    cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
                )
            )
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig.XonlyKey {
        /// Creates a new `XonlyKey` by adding a tweak to the x-only public key.
        ///
        /// This function implements the tweaking process for MuSig x-only public keys as described in BIP-327.
        ///
        /// - Parameter tweak: The 32-byte tweak to apply.
        /// - Returns: A new tweaked `XonlyKey` object.
        /// - Throws: An error if tweaking fails.
        func add(_ tweak: [UInt8]) throws -> Self {
            let context = P256K.Context.rawRepresentation
            var pubKey = secp256k1_pubkey()
            var cache = secp256k1_musig_keyagg_cache()
            var outXonlyPubKey = secp256k1_xonly_pubkey()
            var xonlyBytes = [UInt8](repeating: 0, count: P256K.Schnorr.xonlyByteCount)
            var keyParity = Int32()

            self.cache.copyToUnsafeMutableBytes(of: &cache.data)

            guard secp256k1_musig_pubkey_xonly_tweak_add(context, &pubKey, &cache, tweak).boolValue,
                  secp256k1_xonly_pubkey_from_pubkey(context, &outXonlyPubKey, &keyParity, &pubKey).boolValue,
                  secp256k1_xonly_pubkey_serialize(context, &xonlyBytes, &outXonlyPubKey).boolValue
            else {
                throw secp256k1Error.underlyingCryptoError
            }

            return Self(
                dataRepresentation: xonlyBytes,
                keyParity: keyParity,
                cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
            )
        }
    }

#endif
