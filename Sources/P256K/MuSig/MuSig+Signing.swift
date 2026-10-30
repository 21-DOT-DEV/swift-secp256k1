//
//  MuSig+Signing.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public import Foundation
import libsecp256k1

#if Xcode || ENABLE_MODULE_MUSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig.PublicKey {
        /// Verifies one signer's ``P256K/Schnorr/PartialSignature`` against this aggregate
        /// public key using `secp256k1_musig_partial_sig_verify` (declared in
        /// [`secp256k1/include/secp256k1_musig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_musig.h)).
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
        /// - Parameter digest: The message digest that was signed; not consulted — the
        ///   signed message is bound inside ``P256K/Schnorr/PartialSignature/session``
        ///   (the `msg32` passed to `secp256k1_musig_nonce_process` at signing time),
        ///   so the parameter documents intent rather than driving the check.
        /// - Returns: `true` if the partial signature is valid for the session's bound message under this aggregate key, `false` otherwise.
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

            // `keyagg_cache_load` and `session_load` check their magic prefixes
            // inside `ARG_CHECK`, which aborts on mismatch — a key or session
            // blob that fails validation is simply an unverifiable input here.
            guard MuSigOpaqueState.isValidKeyAggregationCache(keyAggregationCache),
                  MuSigOpaqueState.isValidSession(partialSignature.session) else {
                return false
            }

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
        /// signature is stored in its stable 32-byte wire format (see
        /// ``P256K/Schnorr/PartialSignature/dataRepresentation``).
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
        /// - Parameter digest: The message digest to sign; reduced to the 32-byte `msg32`
        ///   value per SEC1 §4.1.3 (leftmost 32 bytes for longer digests, integer value
        ///   for shorter).
        /// - Parameter pubnonce: This signer's own public nonce from nonce generation; not
        ///   consulted — upstream binds the signer's public nonce inside `secureNonce`
        ///   already, so no separate pubnonce reaches `secp256k1_musig_partial_sign`.
        /// - Parameter secureNonce: This signer's secret nonce (`~Copyable`); consumed and zeroed on return.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` aggregated from all signers' public nonces.
        /// - Parameter xonlyKeyAggregate: The x-only form of the ``P256K/MuSig/aggregate(_:)`` result;
        ///   must carry the key aggregation ``P256K/MuSig/XonlyKey/cache`` from that call.
        /// - Returns: A ``P256K/Schnorr/PartialSignature`` to send to the aggregator.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `xonlyKeyAggregate` lacks a
        ///   usable key aggregation cache, or if `secureNonce` was generated for a different
        ///   public key than this signing key (BIP-327 binds the signer's public key into the
        ///   secret nonce; upstream enforces the match via an aborting `ARG_CHECK`, which is
        ///   unreachable after this method's own check). Other upstream signing failures are
        ///   unreachable on the validated inputs and report through
        ///   ``P256K/setInvariantViolationHandler(_:)`` instead of throwing.
        func partialSignature<D: Digest>(
            for digest: D,
            pubnonce: P256K.Schnorr.Nonce,
            secureNonce: consuming P256K.Schnorr.SecureNonce,
            publicNonceAggregate: P256K.MuSig.Nonce,
            xonlyKeyAggregate: P256K.MuSig.XonlyKey
        ) throws -> P256K.Schnorr.PartialSignature {
            let context = P256K.Context.rawRepresentation
            var signature = secp256k1_musig_partial_sig()
            var keypair = secp256k1_keypair()
            // `secp256k1_keypair` embeds the secret scalar and upstream never
            // zeroes caller-owned memory — scrub the local after its last use
            // rather than leave the residue in the stack frame.
            defer {
                Swift.withUnsafeMutableBytes(of: &keypair) { buffer in
                    _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
                }
            }
            var cache = secp256k1_musig_keyagg_cache()
            var session = secp256k1_musig_session()
            var aggnonce = secp256k1_musig_aggnonce()
            var partialSignature = [UInt8](repeating: 0, count: P256K.ByteLength.dimension)
            let messageBytes = digest.msg32Bytes

            // `keyagg_cache_load` checks the blob's magic prefix inside `ARG_CHECK`,
            // which aborts on a zeroed or malformed struct — a missing or corrupt
            // cache must throw before the copy, not reach upstream.
            guard MuSigOpaqueState.isValidKeyAggregationCache(xonlyKeyAggregate.cache) else {
                throw secp256k1Error.underlyingCryptoError
            }

            // `secp256k1_musig_partial_sign` `ARG_CHECK`s that the public key bound
            // inside the secnonce matches the signing keypair, and aborts on
            // mismatch — check it here so a caller mixing a nonce generated for a
            // different key gets an error instead of a process abort. BIP-327
            // performs the same check in its signing step. Compare the canonical
            // point identity (x-only bytes + parity): `dataRepresentation` is
            // format-dependent, so the same point in a different `Format` is the
            // same key and must not throw.
            guard secureNonce.publicKey.baseKey.xonlyBytes == publicKey.baseKey.xonlyBytes,
                  secureNonce.publicKey.baseKey.keyParity == publicKey.baseKey.keyParity
            else {
                throw secp256k1Error.underlyingCryptoError
            }

            let keypairCreated = key.withUnsafeBytePointer { keyPtr in
                secp256k1_keypair_create(context, &keypair, keyPtr).boolValue
            }
            guard keypairCreated else {
                P256K.invariantFailure("secp256k1_keypair_create failed in MuSig partial signing with validated key — library bug")
            }

            xonlyKeyAggregate.cache.copyToUnsafeMutableBytes(of: &cache.data)
            publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

            // Every operand below is upstream-produced or construction-validated
            // in this same call — `publicNonceAggregate` was parse-validated as a
            // ``P256K/MuSig/Nonce``, `secureNonce` is consumed `~Copyable` state
            // from ``P256K/MuSig/Nonce/generate`` bound to this key (checked
            // above), the keypair was just created, and the session/cache carry
            // validated magic prefixes — so a failure can only indicate
            // corruption or an upstream defect. rust-secp256k1's MuSig
            // bindings reach the same conclusion: `partial_sign` panics on the
            // reuse path rather than returning `Result`.
            guard secp256k1_musig_nonce_process(context, &session, &aggnonce, messageBytes, &cache).boolValue else {
                P256K.invariantFailure("secp256k1_musig_nonce_process failed on validated session inputs — library bug")
            }
            // `secp256k1_musig_secnonce` is an opaque byte-array struct — bind
            // the consumed nonce's own `SecureBytes` storage so upstream reads
            // and zeroes it in place on success (the `SecureBytes` backing also
            // `memset_s`-zeroes it on release either way).
            let partialSigned = secureNonce.data.withUnsafeMutableBytes(boundTo: secp256k1_musig_secnonce.self) { secnonce in
                secp256k1_musig_partial_sign(
                    context,
                    &signature,
                    secnonce,
                    &keypair,
                    &cache,
                    &session
                ).boolValue
            }
            guard partialSigned else {
                P256K.invariantFailure("secp256k1_musig_partial_sign failed on fresh consumed nonce — library bug")
            }
            guard secp256k1_musig_partial_sig_serialize(context, &partialSignature, &signature).boolValue else {
                P256K.invariantFailure("secp256k1_musig_partial_sig_serialize failed on upstream-produced signature — library bug")
            }

            return P256K.Schnorr.PartialSignature(
                Data(partialSignature),
                session: session.dataValue
            )
        }

        /// Convenience overload of ``partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)`` that derives the x-only key from a ``P256K/MuSig/PublicKey``.
        ///
        /// - Parameter digest: The message digest to sign; reduced to the 32-byte `msg32`
        ///   value per SEC1 §4.1.3 (leftmost 32 bytes for longer digests, integer value
        ///   for shorter).
        /// - Parameter pubnonce: This signer's public nonce.
        /// - Parameter secureNonce: This signer's secret nonce; consumed and zeroed on return.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` from all signers' public nonces.
        /// - Parameter publicKeyAggregate: The ``P256K/MuSig/PublicKey`` returned by ``P256K/MuSig/aggregate(_:)``.
        /// - Returns: A ``P256K/Schnorr/PartialSignature`` to send to the aggregator.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `publicKeyAggregate` lacks a
        ///   usable key aggregation cache, or if `secureNonce` was generated for a different
        ///   public key than this signing key. Other upstream signing failures are
        ///   unreachable on the validated inputs and report through
        ///   ``P256K/setInvariantViolationHandler(_:)`` instead of throwing.
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
        /// The digest is reduced to the 32-byte `msg32` value per SEC1 §4.1.3 —
        /// the same normalization ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``
        /// applies — so a `Digest` of any length maps to the message bytes that
        /// were actually signed. For arbitrary-length message verification use
        /// ``isValid(_:for:)``.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``P256K/MuSig/AggregateSignature`` to verify.
        ///   - digest: The pre-computed digest that was signed.
        /// - Returns: `true` if the aggregate signature is valid for `digest` under this x-only aggregate key, `false` otherwise.
        func isValidSignature<D: Digest>(_ signature: P256K.MuSig.AggregateSignature, for digest: D) -> Bool {
            isValid(signature, for: digest.msg32Bytes)
        }

        /// Verifies a MuSig2 aggregate signature over an arbitrary-length message using `secp256k1_schnorrsig_verify`.
        ///
        /// The message bytes are borrowed read-only for the call — an empty collection
        /// reaches upstream with `msglen = 0` — `msg` may be NULL — the documented empty-message case.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``P256K/MuSig/AggregateSignature`` to verify.
        ///   - message: The message bytes that were signed (any length, including zero; must match those used in the signing session).
        /// - Returns: `true` if the aggregate signature is valid, `false` otherwise.
        func isValid(_ signature: P256K.MuSig.AggregateSignature, for message: some ContiguousBytes) -> Bool {
            let context = P256K.Context.rawRepresentation
            var pubKey = secp256k1_xonly_pubkey()

            // `bytes` is guaranteed a validated 32-byte coordinate by construction.
            return message.withUnsafeBytes { messageBuffer in
                secp256k1_xonly_pubkey_parse(context, &pubKey, bytes).boolValue &&
                    secp256k1_schnorrsig_verify(
                        context,
                        signature.dataRepresentation.byteArray,
                        messageBuffer.bindMemory(to: UInt8.self).baseAddress,
                        messageBuffer.count,
                        &pubKey
                    ).boolValue
            }
        }
    }

#endif
