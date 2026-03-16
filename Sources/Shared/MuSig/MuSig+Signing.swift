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
        /// Verifies a partial signature against this public key.
        ///
        /// This function implements the partial signature verification process as described in BIP-327.
        ///
        /// - Parameters:
        ///   - partialSignature: The partial signature to verify.
        ///   - publicKey: The signer's public key.
        ///   - nonce: The signer's public nonce.
        ///   - digest: The message digest being signed.
        /// - Returns: `true` if the partial signature is valid, `false` otherwise.
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
        /// Generates a partial signature for MuSig.
        ///
        /// This function implements the partial signing process as described in BIP-327.
        ///
        /// - Parameters:
        ///   - digest: The message digest to sign.
        ///   - pubnonce: The signer's public nonce.
        ///   - secureNonce: The signer's secret nonce.
        ///   - publicNonceAggregate: The aggregate of all signers' public nonces.
        ///   - publicKeyAggregate: The aggregate of all signers' public keys.
        /// - Returns: A partial MuSig signature.
        /// - Throws: An error if partial signature generation fails.
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

        /// Generates a partial signature for MuSig using SHA256 as the hash function.
        ///
        /// This is a convenience method that extracts the xonlyKeyAggregate from the public key aggregate.
        ///
        /// - Parameters:
        ///   - data: The data to sign.
        ///   - pubnonce: The signer's public nonce.
        ///   - secureNonce: The signer's secret nonce.
        ///   - publicNonceAggregate: The aggregate of all signers' public nonces.
        ///   - publicKeyAggregate: The aggregate of all signers' public keys.
        /// - Returns: A partial MuSig signature.
        /// - Throws: An error if partial signature generation fails.
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
        /// Verifies a MuSig aggregate signature with a digest.
        ///
        /// This function is used when a hash digest has been created before invoking.
        /// Enables BIP-340 signatures assuming the hash digest used the `Tagged Hashes` scheme as defined in the proposal.
        ///
        /// [BIP-340 Design](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#design)
        ///
        /// - Parameters:
        ///   - signature: The aggregate signature to verify.
        ///   - digest: The digest that was signed.
        /// - Returns: True if the signature is valid, false otherwise.
        func isValidSignature<D: Digest>(_ signature: P256K.MuSig.AggregateSignature, for digest: D) -> Bool {
            var hashDataBytes = Array(digest).bytes

            return isValid(signature, for: &hashDataBytes)
        }

        /// Verifies a MuSig aggregate signature with a variable length message.
        ///
        /// This function provides flexibility for verifying a MuSig aggregate signature without assumptions about message format.
        ///
        /// [secp256k1_schnorrsig_verify](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L149L158)
        ///
        /// - Parameters:
        ///   - signature: The aggregate signature to verify.
        ///   - message: The message that was signed.
        /// - Returns: True if the signature is valid, false otherwise.
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
