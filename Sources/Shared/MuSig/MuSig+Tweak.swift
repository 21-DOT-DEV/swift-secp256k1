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
        /// Creates a new ``PublicKey`` by computing `agg_pk' = agg_pk + G × tweak` via `secp256k1_musig_pubkey_ec_tweak_add`, updating the key aggregation cache in-place.
        ///
        /// Use this method when you need to sign for a BIP-32 child key derived from the aggregate
        /// key. If you only need the tweaked public key for verification (not signing), use
        /// `secp256k1_ec_pubkey_tweak_add` directly instead.
        ///
        /// - Parameter tweak: A 32-byte tweak scalar; must pass `secp256k1_ec_seckey_verify` and must not negate the aggregate key.
        /// - Parameter format: The serialization format of the returned ``PublicKey``; defaults to `.compressed`.
        /// - Returns: A new ``PublicKey`` equal to the original aggregate key plus the tweak times the generator.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or the result is the point at infinity.
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
        /// Creates a new ``XonlyKey`` by computing `agg_pk' = agg_pk + G × tweak` via `secp256k1_musig_pubkey_xonly_tweak_add`, as required for BIP-341 Taproot output key construction.
        ///
        /// Use this method to produce Taproot outputs where `tweak` is the TapTweak hash (BIP-341).
        /// This method is required if you want to *sign* for the tweaked aggregate key. If you only
        /// need the tweaked public key and are not signing, use `secp256k1_xonly_pubkey_tweak_add`.
        ///
        /// - Parameter tweak: A 32-byte tweak scalar; must pass `secp256k1_ec_seckey_verify` and must not negate the aggregate key.
        /// - Returns: A new ``XonlyKey`` representing the Taproot output key.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the tweak is invalid or the result is the point at infinity.
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
