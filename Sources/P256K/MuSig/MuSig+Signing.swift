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
        /// Upstream's `partial_sig_verify` takes a session rather than a message —
        /// the message is bound into the session by `secp256k1_musig_nonce_process`,
        /// not consulted at verify time — so this method rebuilds the session locally
        /// from `publicNonceAggregate`, `message`, and this aggregate key's
        /// aggregation cache, the same flow upstream's `doc/musig.md` prescribes for a
        /// verifying party. The ``P256K/Schnorr/PartialSignature/session`` carried
        /// inside `partialSignature` must then match that rebuilt session exactly: a
        /// signature produced over a different message or nonce set, or one paired
        /// with a foreign session blob through
        /// ``P256K/Schnorr/PartialSignature/init(dataRepresentation:session:)``, fails
        /// rather than verifying against a session the caller never declared.
        /// Because the rebuild runs through this key's aggregation cache, a session
        /// produced under a BIP-341 tweaked aggregate verifies only through a
        /// `PublicKey` carrying the tweaked cache — ``init(xonlyKey:)`` on the
        /// tweaked ``P256K/MuSig/XonlyKey`` — not the untweaked aggregate.
        ///
        /// - Parameter partialSignature: The signer's ``P256K/Schnorr/PartialSignature`` to verify.
        /// - Parameter publicKey: The individual signer's ``P256K/Schnorr/PublicKey`` (not the aggregate).
        /// - Parameter nonce: The same signer's public nonce used in this session.
        /// - Parameter message: The message that was signed — must be exactly 32 bytes;
        ///   `secp256k1_musig_nonce_process` binds a fixed `msg32` into the session,
        ///   so hash arbitrary-length application messages to 32 bytes first
        ///   (variable-length BIP-327 messages are unsupported by libsecp256k1).
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` aggregated from
        ///   all signers' public nonces for this session — rebuild it with
        ///   ``P256K/MuSig/Nonce/init(aggregating:)`` or
        ///   ``P256K/MuSig/Nonce/init(dataRepresentation:)`` if you did not take
        ///   part in nonce generation yourself.
        /// - Returns: `true` if the partial signature is valid under this aggregate key
        ///   for the session rebuilt from the supplied inputs and the signature's
        ///   carried session blob matches it, `false` otherwise — where `false`
        ///   can also mean the declared inputs are stale rather than the cosigner
        ///   being at fault.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `message` is not
        ///   exactly 32 bytes.
        func isValidSignature(
            _ partialSignature: P256K.Schnorr.PartialSignature,
            publicKey: P256K.Schnorr.PublicKey,
            nonce: P256K.Schnorr.Nonce,
            for message: some ContiguousBytes,
            publicNonceAggregate: P256K.MuSig.Nonce
        ) throws -> Bool {
            let context = P256K.Context.rawRepresentation
            var partialSig = secp256k1_musig_partial_sig()
            var pubnonce = secp256k1_musig_pubnonce()
            var publicKey = publicKey.baseKey.rawRepresentation
            var cache = secp256k1_musig_keyagg_cache()
            var session = secp256k1_musig_session()
            var aggnonce = secp256k1_musig_aggnonce()

            // `secp256k1_musig_nonce_process` reads a fixed `msg32` — reject any
            // other length rather than silently verifying against the wrong session.
            let messageBytes = try message.exactMsg32Bytes

            // `keyagg_cache_load` checks the blob's magic prefix inside `ARG_CHECK`,
            // which aborts on mismatch — a key that fails validation is simply an
            // unverifiable input here.
            guard MuSigOpaqueState.isValidKeyAggregationCache(keyAggregationCache) else {
                return false
            }

            nonce.pubnonce.copyToUnsafeMutableBytes(of: &pubnonce.data)
            keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)
            publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

            guard secp256k1_musig_partial_sig_parse(context, &partialSig, Array(partialSignature.dataRepresentation)).boolValue else {
                return false
            }

            // `nonce_process` is deterministic — the same (aggregate nonce, msg32,
            // keyagg cache) triple always produces the same session bytes — so an
            // honestly produced `PartialSignature` embeds exactly the session this
            // rebuilds. A carried blob that differs pairs the signature with a
            // different session and fails before the verify call. `nonce_process`
            // itself fails only when the copied cache or aggregate nonce fails to
            // load — both returns run before `session_save` — so the guard's `&&`
            // short-circuit, not a zeroed session, is what keeps a bogus match out.
            guard secp256k1_musig_nonce_process(context, &session, &aggnonce, messageBytes, &cache).boolValue,
                  partialSignature.session == session.dataValue else {
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
        /// The method self-verifies the produced signature before returning.
        /// Upstream's `secp256k1_musig_partial_sign` "does not verify the output
        /// partial signature, deviating from the
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)
        /// specification" — BIP-327's reference `Sign` ends with
        /// `assert partial_sig_verify_internal(...)`, and this method performs
        /// that check: the produced partial signature is serialized, re-parsed
        /// from its escaping 32-byte wire form, and verified via
        /// `secp256k1_musig_partial_sig_verify` under the session this call
        /// rebuilds, the companion public nonce bound inside `secureNonce`, and
        /// this key's public half. A failure is unreachable on the validated
        /// inputs, so it reports through ``P256K/setInvariantViolationHandler(_:)``
        /// and terminates rather than letting corrupted output escape.
        ///
        /// - Parameter message: The message to sign — must be exactly 32 bytes;
        ///   `secp256k1_musig_nonce_process` binds a fixed `msg32` into the session,
        ///   so hash arbitrary-length application messages to 32 bytes first
        ///   (variable-length BIP-327 messages are unsupported by libsecp256k1).
        /// - Parameter pubnonce: This signer's own public nonce from nonce
        ///   generation — the ``P256K/MuSig/NonceResult/pubnonce`` returned in the
        ///   same pair as `secureNonce`. `secp256k1_musig_partial_sign` takes no
        ///   public-nonce argument — the nonce pair is bound inside `secureNonce`
        ///   — so the value is instead byte-compared against the companion
        ///   `SecureNonce` retains at generation; a mismatch throws
        ///   ``secp256k1Error/underlyingCryptoError`` before `secureNonce` reaches
        ///   upstream, naming the caller's bookkeeping bug at the signer where
        ///   it is provable rather than surfacing later as an unattributed
        ///   session failure. The companion also supplies the public nonce the
        ///   produced signature is verified under.
        /// - Parameter secureNonce: This signer's secret nonce (`~Copyable`); consumed and zeroed on return.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` aggregated from all signers' public nonces.
        /// - Parameter xonlyKeyAggregate: The x-only form of the ``P256K/MuSig/aggregate(_:)`` result;
        ///   must carry the key aggregation ``P256K/MuSig/XonlyKey/cache`` from that call.
        /// - Returns: A ``P256K/Schnorr/PartialSignature`` to send to the aggregator.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `message` is not exactly
        ///   32 bytes; ``secp256k1Error/underlyingCryptoError`` if `xonlyKeyAggregate` lacks a
        ///   usable key aggregation cache, if `secureNonce` was generated for a different
        ///   public key than this signing key (BIP-327 binds the signer's public key into the
        ///   secret nonce; upstream enforces the match via an aborting `ARG_CHECK`, which is
        ///   unreachable after this method's own check), or if `pubnonce` differs
        ///   from the companion public nonce bound inside `secureNonce` at
        ///   generation. Other upstream signing failures are
        ///   unreachable on the validated inputs and report through
        ///   ``P256K/setInvariantViolationHandler(_:)`` instead of throwing.
        ///   `secureNonce` is consumed and zeroed on every exit including a throw —
        ///   a rejected input burns the nonce pair, so retrying requires fresh
        ///   nonce generation.
        func partialSignature(
            for message: some ContiguousBytes,
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
            // `secp256k1_musig_nonce_process` reads a fixed `msg32` — reject any
            // other length rather than silently committing the session to the
            // wrong message.
            let messageBytes = try message.exactMsg32Bytes

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

            // `partial_sign` never sees `pubnonce` — upstream binds the nonce
            // pair inside the secnonce — so the declared value is byte-compared
            // against the companion `Nonce.generate` stored inside `secureNonce`
            // instead. A mismatch means the caller's session bookkeeping is
            // wrong; thrown before `secureNonce` reaches upstream, the error
            // names the bug at the signer where it is provable rather than
            // surfacing later as an unattributed session failure.
            guard pubnonce.pubnonce == secureNonce.publicNonce.pubnonce else {
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

            // Test seam (spec 004 Group E): mutates the produced wire bytes
            // between serialization and the self-check; a no-op when unbound.
            partialSignature.withUnsafeMutableBytes(P256K.corruptProducedSignature)

            var verifiedSignature = secp256k1_musig_partial_sig()
            var signerPublicNonce = secp256k1_musig_pubnonce()
            var signerPublicKey = publicKey.baseKey.rawRepresentation
            secureNonce.publicNonce.pubnonce.copyToUnsafeMutableBytes(of: &signerPublicNonce.data)

            // Verify-after-sign (spec 004 T012): re-parse the escaping 32-byte
            // wire form — `partial_sig_parse` cannot legitimately reject bytes
            // `partial_sig_serialize` just produced — then prove it via
            // `partial_sig_verify` under the session this call rebuilt, the
            // companion public nonce, and the signing keypair's public half:
            // every input's provenance is established, so failure is
            // unreachable — output corruption or a library bug. BIP-327's
            // reference `Sign` ends with the same `partial_sig_verify` assert.
            guard secp256k1_musig_partial_sig_parse(context, &verifiedSignature, partialSignature).boolValue else {
                P256K.invariantFailure("secp256k1_musig_partial_sig_parse failed on upstream-serialized signature — library bug")
            }
            guard secp256k1_musig_partial_sig_verify(
                context,
                &verifiedSignature,
                &signerPublicNonce,
                &signerPublicKey,
                &cache,
                &session
            ).boolValue else {
                P256K.invariantFailure("produced MuSig partial signature failed verification — output corruption or library bug")
            }

            return P256K.Schnorr.PartialSignature(
                Data(partialSignature),
                session: session.dataValue
            )
        }

        /// Convenience overload of ``partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)`` that derives the x-only key from a ``P256K/MuSig/PublicKey``.
        ///
        /// - Parameter message: The message to sign — must be exactly 32 bytes;
        ///   `secp256k1_musig_nonce_process` binds a fixed `msg32` into the session,
        ///   so hash arbitrary-length application messages to 32 bytes first
        ///   (variable-length BIP-327 messages are unsupported by libsecp256k1).
        /// - Parameter pubnonce: This signer's public nonce; byte-compared against
        ///   the companion bound inside `secureNonce` (see the canonical overload).
        /// - Parameter secureNonce: This signer's secret nonce; consumed and zeroed on return.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` from all signers' public nonces.
        /// - Parameter publicKeyAggregate: The ``P256K/MuSig/PublicKey`` returned by ``P256K/MuSig/aggregate(_:)``.
        /// - Returns: A ``P256K/Schnorr/PartialSignature`` to send to the aggregator.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `message` is not exactly
        ///   32 bytes; ``secp256k1Error/underlyingCryptoError`` if `publicKeyAggregate` lacks a
        ///   usable key aggregation cache, if `secureNonce` was generated for a different
        ///   public key than this signing key, or if `pubnonce` differs from the
        ///   companion public nonce bound inside `secureNonce`. Other upstream signing failures are
        ///   unreachable on the validated inputs and report through
        ///   ``P256K/setInvariantViolationHandler(_:)`` instead of throwing.
        ///   `secureNonce` is consumed and zeroed on every exit including a throw —
        ///   a rejected message burns the nonce pair, so retrying requires fresh
        ///   nonce generation.
        func partialSignature(
            for message: some ContiguousBytes,
            pubnonce: P256K.Schnorr.Nonce,
            secureNonce: consuming P256K.Schnorr.SecureNonce,
            publicNonceAggregate: P256K.MuSig.Nonce,
            publicKeyAggregate: P256K.MuSig.PublicKey
        ) throws -> P256K.Schnorr.PartialSignature {
            try partialSignature(
                for: message,
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
        /// The digest's bytes are verified **at their natural length** — the upstream
        /// verify API accepts arbitrary-length messages, so no `msg32` reduction
        /// applies here (matching ``P256K/Schnorr/XonlyKey/isValidSignature(_:for:)``).
        /// For non-`Digest` message bytes use ``isValid(_:for:)``.
        ///
        /// - Parameters:
        ///   - signature: The 64-byte ``P256K/MuSig/AggregateSignature`` to verify.
        ///   - digest: The pre-computed digest that was signed.
        /// - Returns: `true` if the aggregate signature is valid for `digest` under this x-only aggregate key, `false` otherwise.
        func isValidSignature<D: Digest>(_ signature: P256K.MuSig.AggregateSignature, for digest: D) -> Bool {
            isValid(signature, for: digest)
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

            // `dataRepresentation` is guaranteed a validated 32-byte coordinate by construction.
            return message.withUnsafeBytes { messageBuffer in
                secp256k1_xonly_pubkey_parse(context, &pubKey, Array(dataRepresentation)).boolValue &&
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
