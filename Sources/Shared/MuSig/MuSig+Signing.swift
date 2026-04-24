//
//  MuSig+Signing.swift
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
        /// Verifies one signer's ``P256K/Schnorr/PartialSignature`` against this aggregate
        /// public key using `secp256k1_musig_partial_sig_verify` (declared in
        /// [`Vendor/secp256k1-zkp/include/secp256k1_musig.h`](https://github.com/BlockstreamResearch/secp256k1-zkp/blob/master/include/secp256k1_musig.h)).
        ///
        /// Partial signature verification is optional in regular
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki) MuSig2
        /// sessions — if any partial signature is wrong, the final
        /// ``P256K/MuSig/AggregateSignature`` will simply fail to verify. Call this method
        /// to identify *which* signer produced an invalid partial signature, which matters
        /// when you need to attribute failure and evict a faulty cosigner.
        ///
        /// - Parameter partialSignature: The signer's ``P256K/Schnorr/PartialSignature`` to verify.
        /// - Parameter publicKey: The individual signer's ``P256K/Schnorr/PublicKey`` (not the aggregate).
        /// - Parameter nonce: The same signer's public nonce used in this session.
        /// - Parameter digest: The message digest that was signed.
        /// - Returns: `true` if the partial signature is valid for `digest` under this aggregate key, `false` otherwise.
        func isValidSignature<D: Digest>(
            _ partialSignature: P256K.Schnorr.PartialSignature,
            publicKey: P256K.Schnorr.PublicKey,
            nonce: P256K.Schnorr.Nonce,
            for digest: D
        ) -> Bool {
            let context = P256K.Context.rawRepresentation
            var partialSig = secp256k1_musig_partial_sig()
            var pubnonce = secp256k1_musig_pubnonce()
            var publicKey = publicKey.baseKey.rawRepresentation
            var cache = secp256k1_musig_keyagg_cache()
            var session = secp256k1_musig_session()

            nonce.pubnonce.copyToUnsafeMutableBytes(of: &pubnonce.data)
            keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)
            partialSignature.session.copyToUnsafeMutableBytes(of: &session.data)

            guard secp256k1_musig_partial_sig_parse(context, &partialSig, Array(partialSignature.dataRepresentation)).boolValue else {
                return false
            }

            return secp256k1_musig_partial_sig_verify(
                context,
                &partialSig,
                &pubnonce,
                &publicKey,
                &cache,
                &session
            ).boolValue
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr.PrivateKey {
        /// Produces a ``P256K/Schnorr/PartialSignature`` via `secp256k1_musig_partial_sign`,
        /// consuming and zeroing the secret nonce to prevent reuse. The resulting partial
        /// signature is an opaque 36-byte in-memory struct; its stable wire format is
        /// 32 bytes (see ``P256K/Schnorr/PartialSignature/dataRepresentation``).
        ///
        /// > Warning: **The secret nonce is zeroed after this call.**
        /// > `secp256k1_musig_partial_sign` overwrites `secureNonce` with zeros as a
        /// > best-effort defence against nonce reuse. Because ``P256K/Schnorr/SecureNonce``
        /// > is `~Copyable`, the Swift layer additionally prevents static misuse. Nonce
        /// > reuse leaks the secret signing key.
        ///
        /// This method does **not** verify the output partial signature, deviating from the
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)
        /// specification. Call
        /// ``P256K/MuSig/PublicKey/isValidSignature(_:publicKey:nonce:for:)`` afterwards to
        /// detect computation errors.
        ///
        /// - Parameter digest: The message digest to sign.
        /// - Parameter pubnonce: This signer's own public nonce from nonce generation.
        /// - Parameter secureNonce: This signer's secret nonce (`~Copyable`); consumed and zeroed on return.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` aggregated from all signers' public nonces.
        /// - Parameter xonlyKeyAggregate: The x-only form of the ``P256K/MuSig/aggregate(_:)`` result.
        /// - Returns: A ``P256K/Schnorr/PartialSignature`` to send to the aggregator.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if signing fails or the secnonce was already used.
        func partialSignature<D: Digest>(
            for digest: D,
            pubnonce: P256K.Schnorr.Nonce,
            secureNonce: consuming P256K.Schnorr.SecureNonce,
            publicNonceAggregate: P256K.MuSig.Nonce,
            xonlyKeyAggregate: P256K.MuSig.XonlyKey
        ) throws -> P256K.Schnorr.PartialSignature {
            let context = P256K.Context.rawRepresentation
            var signature = secp256k1_musig_partial_sig()
            var secnonce = secp256k1_musig_secnonce()
            var keypair = secp256k1_keypair()
            var cache = secp256k1_musig_keyagg_cache()
            var session = secp256k1_musig_session()
            var aggnonce = secp256k1_musig_aggnonce()
            var partialSignature = [UInt8](repeating: 0, count: P256K.ByteLength.partialSignature)

            guard secp256k1_keypair_create(context, &keypair, Array(dataRepresentation)).boolValue else {
                fatalError("secp256k1_keypair_create failed with valid key — library bug")
            }

            secureNonce.data.copyToUnsafeMutableBytes(of: &secnonce.data)
            xonlyKeyAggregate.cache.copyToUnsafeMutableBytes(of: &cache.data)
            publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

            #if canImport(libsecp256k1_zkp)
                guard secp256k1_musig_nonce_process(context, &session, &aggnonce, Array(digest), &cache, nil).boolValue,
                      secp256k1_musig_partial_sign(context, &signature, &secnonce, &keypair, &cache, &session).boolValue,
                      secp256k1_musig_partial_sig_serialize(context, &partialSignature, &signature).boolValue
                else {
                    throw secp256k1Error.underlyingCryptoError
                }
            #elseif canImport(libsecp256k1)
                guard secp256k1_musig_nonce_process(context, &session, &aggnonce, Array(digest), &cache).boolValue,
                      secp256k1_musig_partial_sign(context, &signature, &secnonce, &keypair, &cache, &session).boolValue,
                      secp256k1_musig_partial_sig_serialize(context, &partialSignature, &signature).boolValue
                else {
                    throw secp256k1Error.underlyingCryptoError
                }
            #endif

            return P256K.Schnorr.PartialSignature(
                Data(bytes: &partialSignature, count: P256K.ByteLength.partialSignature),
                session: session.dataValue
            )
        }

        /// Convenience overload of ``partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)`` that derives the x-only key from a ``P256K/MuSig/PublicKey``.
        ///
        /// - Parameter digest: The message digest to sign.
        /// - Parameter pubnonce: This signer's public nonce.
        /// - Parameter secureNonce: This signer's secret nonce; consumed and zeroed on return.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` from all signers' public nonces.
        /// - Parameter publicKeyAggregate: The ``P256K/MuSig/PublicKey`` returned by ``P256K/MuSig/aggregate(_:)``.
        /// - Returns: A ``P256K/Schnorr/PartialSignature`` to send to the aggregator.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if signing fails or the secnonce was already used.
        func partialSignature<D: Digest>(
            for digest: D,
            pubnonce: P256K.Schnorr.Nonce,
            secureNonce: consuming P256K.Schnorr.SecureNonce,
            publicNonceAggregate: P256K.MuSig.Nonce,
            publicKeyAggregate: P256K.MuSig.PublicKey
        ) throws -> P256K.Schnorr.PartialSignature {
            try partialSignature(
                for: digest,
                pubnonce: pubnonce,
                secureNonce: secureNonce,
                publicNonceAggregate: publicNonceAggregate,
                xonlyKeyAggregate: publicKeyAggregate.xonly
            )
        }
    }

    // MARK: - MuSig XonlyKey Signature Verification

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig.XonlyKey {
        /// Verifies a MuSig2 ``P256K/MuSig/AggregateSignature`` against a pre-computed digest using `secp256k1_schnorrsig_verify`.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``P256K/MuSig/AggregateSignature`` to verify.
        ///   - digest: The pre-computed digest that was signed.
        /// - Returns: `true` if the aggregate signature is valid for `digest` under this x-only aggregate key, `false` otherwise.
        func isValidSignature<D: Digest>(_ signature: P256K.MuSig.AggregateSignature, for digest: D) -> Bool {
            var hashDataBytes = Array(digest).bytes

            return isValid(signature, for: &hashDataBytes)
        }

        /// Verifies a MuSig2 aggregate signature over an arbitrary-length message using `secp256k1_schnorrsig_verify`.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``P256K/MuSig/AggregateSignature`` to verify.
        ///   - message: The message bytes that were signed (must match those used in the signing session).
        /// - Returns: `true` if the aggregate signature is valid, `false` otherwise.
        func isValid(_ signature: P256K.MuSig.AggregateSignature, for message: inout [UInt8]) -> Bool {
            let context = P256K.Context.rawRepresentation
            var pubKey = secp256k1_xonly_pubkey()

            return secp256k1_xonly_pubkey_parse(context, &pubKey, bytes).boolValue &&
                secp256k1_schnorrsig_verify(
                    context,
                    signature.dataRepresentation.bytes,
                    message,
                    message.count,
                    &pubKey
                ).boolValue
        }
    }

#endif
