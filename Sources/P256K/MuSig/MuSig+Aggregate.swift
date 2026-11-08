//
//  MuSig+Aggregate.swift
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

    // MARK: - secp256k1 + MuSig

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// Aggregates N secp256k1 public keys into a single
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki) MuSig2
        /// aggregate public key via `secp256k1_musig_pubkey_agg`, preserving the
        /// order of `pubkeys`. Upstream reference:
        /// [`secp256k1/include/secp256k1_musig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_musig.h).
        ///
        /// The returned ``PublicKey`` includes the 197-byte `secp256k1_musig_keyagg_cache`
        /// needed for signing sessions and Taproot tweaking. **Key order is
        /// significant**: BIP-327 assigns coefficient `1` to the second *distinct*
        /// key, so different orderings of the same multiset generally produce
        /// different aggregate keys. All participants must therefore agree on one
        /// ordering convention — a protocol may define its own (e.g. a signer
        /// index), and when it doesn't, ``sortedPublicKeys(_:)`` gives the
        /// canonical order that makes the aggregate independent of how the key
        /// list was assembled.
        ///
        /// - Parameter pubkeys: All signers' ``P256K/Schnorr/PublicKey`` values,
        ///   in the protocol's agreed order; must contain at least one key.
        /// - Returns: An aggregate ``PublicKey`` with an embedded key aggregation cache.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `pubkeys` is empty.
        ///   A point-at-infinity aggregate — which upstream declares unreachable and
        ///   guards only with a release-stripped `VERIFY_CHECK` — terminates through
        ///   ``P256K/setInvariantViolationHandler(_:)`` inside serialization rather
        ///   than producing a bogus key.
        static func aggregate(_ pubkeys: [P256K.Schnorr.PublicKey]) throws -> P256K.MuSig.PublicKey {
            guard pubkeys.isEmpty == false else {
                throw secp256k1Error.incorrectParameterSize
            }

            let context = P256K.Context.rawRepresentation
            let format = P256K.Format.compressed
            var pubKeyLen = format.length
            var aggPubkey = secp256k1_pubkey()
            var cache = secp256k1_musig_keyagg_cache()
            var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

            // Every pubkey was parse-validated at construction, so aggregating
            // them cannot legitimately fail. Upstream calls a point-at-infinity
            // aggregate unreachable ("negligible probability" — the per-key
            // coefficients are hash-derived) and guards it only with
            // `VERIFY_CHECK`, which is compiled out in release builds — in that
            // case `pubkey_load`'s `ARG_CHECK` inside `ec_pubkey_serialize` reports
            // through the installed invariant handler before the process ends.
            PointerArrayUtility
                .withUnsafePointerArray(pubkeys.map { $0.baseKey.rawRepresentation }) { pointers in
                    guard secp256k1_musig_pubkey_agg(context, nil, &cache, pointers, pointers.count).boolValue else {
                        P256K.invariantFailure("secp256k1_musig_pubkey_agg failed on validated keys — library bug")
                    }
                }

            guard secp256k1_musig_pubkey_get(context, &aggPubkey, &cache).boolValue else {
                P256K.invariantFailure("secp256k1_musig_pubkey_get failed on upstream-written cache — library bug")
            }
            guard secp256k1_ec_pubkey_serialize(
                context,
                &pubBytes,
                &pubKeyLen,
                &aggPubkey,
                format.rawValue
            ).boolValue else {
                P256K.invariantFailure("secp256k1_ec_pubkey_serialize failed on aggregate key — library bug")
            }

            return Self.PublicKey(
                baseKey: PublicKeyImplementation(
                    validatedBytes: pubBytes,
                    format: format,
                    cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
                ),
                participants: pubkeys
            )
        }

        /// Returns `pubkeys` in the canonical order
        /// `secp256k1_ec_pubkey_sort` produces — lexicographic over each key's
        /// compressed serialization.
        ///
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)
        /// makes ``aggregate(_:)`` order-sensitive, so every signer must agree on
        /// one ordering before aggregating. When the protocol does not define one,
        /// sorting gives all parties the same aggregate from the same multiset of
        /// keys regardless of the order their key lists were assembled in —
        /// the same role `secp256k1_ec_pubkey_sort` documents for
        /// `secp256k1_musig_pubkey_agg` ("the same `agg_pk` result for the same
        /// multiset of pubkeys").
        ///
        /// Sorting compares the parsed *point*, not the stored wire form: each
        /// returned ``P256K/Schnorr/PublicKey`` is one of the inputs unchanged,
        /// ``P256K/Schnorr/PublicKey/format`` included, and equal points in
        /// different serializations are interchangeable keys whose relative order
        /// is unspecified. Aggregating the result is unaffected by that choice —
        /// `secp256k1_musig_pubkey_agg` consumes the parsed points.
        ///
        /// - Parameter pubkeys: The ``P256K/Schnorr/PublicKey`` values to sort;
        ///   may be empty.
        /// - Returns: The same key objects in canonical order.
        static func sortedPublicKeys(_ pubkeys: [P256K.Schnorr.PublicKey]) -> [P256K.Schnorr.PublicKey] {
            guard pubkeys.isEmpty == false else { return [] }

            let context = P256K.Context.rawRepresentation
            var permutation = [Int]()

            // Every element gets its own allocation in `PointerArrayUtility`, so
            // the sorted pointer array maps back to the input indices by pointer
            // identity — duplicates included — returning the original key objects
            // with their stored formats intact rather than re-serialized copies.
            PointerArrayUtility
                .withUnsafePointerArray(pubkeys.map { $0.baseKey.rawRepresentation }) { pointers in
                    let original = pointers
                    guard secp256k1_ec_pubkey_sort(context, &pointers, pointers.count).boolValue else {
                        P256K.invariantFailure("secp256k1_ec_pubkey_sort failed on validated keys — library bug")
                    }
                    permutation = pointers.map { pointer in
                        guard let index = original.firstIndex(of: pointer) else {
                            P256K.invariantFailure("secp256k1_ec_pubkey_sort returned an unrecognized pointer — library bug")
                        }
                        return index
                    }
                }

            // A sort is a bijection: every sorted pointer must map to a distinct
            // input index. Pointer sharing or reuse in `PointerArrayUtility` —
            // or upstream returning a pointer twice — would otherwise silently
            // surface as a duplicated key and a wrong aggregate.
            guard Set(permutation).count == pubkeys.count else {
                P256K.invariantFailure("secp256k1_ec_pubkey_sort produced a non-bijective permutation — library bug")
            }

            return permutation.map { pubkeys[$0] }
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// 64-byte
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// signature produced by
        /// ``aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``
        /// from all signers'
        /// ``P256K/Schnorr/PartialSignature`` values; verifiable against the MuSig2
        /// aggregate public key.
        ///
        /// ## Overview
        ///
        /// The aggregate signature is a standard BIP-340 Schnorr signature and verifies
        /// with `secp256k1_schnorrsig_verify` against the ``XonlyKey`` from
        /// ``aggregate(_:)``. This is what makes MuSig2 useful: downstream verifiers
        /// cannot distinguish an aggregate from a single-signer BIP-340 signature.
        ///
        /// > Important: `secp256k1_musig_partial_sig_agg` returning `1` does **not**
        /// > guarantee the resulting signature is valid —
        /// > ``P256K/MuSig/aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``
        /// > verifies the produced signature before returning, but an
        /// > ``AggregateSignature`` reconstructed from wire bytes via
        /// > ``init(dataRepresentation:)`` has not been checked — verify those
        /// > with ``XonlyKey/isValidSignature(_:for:)``.
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:)``
        ///
        /// ### Serialization
        /// - ``dataRepresentation``
        struct AggregateSignature: ContiguousBytes, DataSignature {
            /// The 64-byte BIP-340 Schnorr signature (`R.x || s` in big-endian).
            ///
            /// Stable wire format identical to a single-signer BIP-340 signature. Produced
            /// by `secp256k1_musig_partial_sig_agg` after all signers submit their
            /// partial signatures.
            public private(set) var dataRepresentation: Data

            /// Creates an ``AggregateSignature`` from a 64-byte raw representation.
            ///
            /// - Parameter dataRepresentation: Exactly 64 bytes in BIP-340 Schnorr signature format.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count is not 64.
            public init<D: DataProtocol>(dataRepresentation: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
            }

            /// Creates an ``AggregateSignature`` from a pre-validated 64-byte data value.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature` (64).
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature, "Invalid aggregate signature size")
                self.dataRepresentation = dataRepresentation
            }

            /// Calls `body` with an unsafe pointer to the aggregate signature's 64 raw bytes.
            ///
            /// - Parameter body: A closure receiving a raw buffer pointer over the signature data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// Combines all signers' partial signatures into a final 64-byte
        /// ``AggregateSignature`` via `secp256k1_musig_partial_sig_agg`, then
        /// verifies it via `secp256k1_schnorrsig_verify` before returning.
        ///
        /// Upstream's `doc/musig.md` documents that `partial_sig_agg` returning
        /// `1` does **not** guarantee a valid aggregate — the caller is expected
        /// to verify the produced signature, and [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)
        /// prescribes the same final check. This method performs it: the signing
        /// session is rebuilt locally from the declared (aggregate nonce,
        /// message, key aggregation cache) triple — the same reconstruction
        /// `partialSignature` and the partial verifier perform — the submitted
        /// signer identities must equal the session's participant list
        /// (``P256K/MuSig/XonlyKey``'s internal record of the `aggregate(_:)`
        /// input) as a multiset, every partial signature is verified against
        /// the rebuilt session with its bundled ``P256K/Schnorr/PartialSignature/publicKey``
        /// and ``P256K/Schnorr/PartialSignature/nonce`` — BIP-327's
        /// "Identifying Disruptive Signers" — and the bundled public nonces
        /// must re-aggregate to `publicNonceAggregate` itself, since
        /// `partial_sig_verify` cannot prove the nonce it is handed was
        /// contributed. A wrong-session, foreign-identity, or duplicated
        /// contribution throws naming its index, and a nonce-set mismatch —
        /// a participant signing with an unpublished nonce pair, or a partial
        /// resubmitted under a duplicated participant key — throws without
        /// index (a set-level property), rather than corrupting the
        /// aggregate; a verify failure after those checks needs output
        /// corruption, a library bug, or a negligible-probability
        /// effective-nonce-at-infinity (the session's `R₁ + b·R₂` summing to
        /// the point at infinity — upstream substitutes `G`, and forcing the
        /// sum from peer input requires a committed nonce's discrete log) —
        /// so it reports through ``P256K/setInvariantViolationHandler(_:)``
        /// and terminates rather than letting corrupted output escape.
        ///
        /// - Parameter partialSignatures: All signers' ``P256K/Schnorr/PartialSignature``
        ///   values — exactly one per session participant, each bundling the
        ///   signer's ``P256K/Schnorr/PartialSignature/publicKey`` and public
        ///   ``P256K/Schnorr/PartialSignature/nonce``.
        /// - Parameter message: The message that was signed — must be exactly 32
        ///   bytes; `secp256k1_musig_nonce_process` binds a fixed `msg32` into
        ///   the session, so hash arbitrary-length application messages to 32
        ///   bytes first (variable-length BIP-327 messages are unsupported by
        ///   libsecp256k1).
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` aggregated
        ///   from all signers' public nonces for this session.
        /// - Parameter xonlyKeyAggregate: The x-only form of the
        ///   ``P256K/MuSig/aggregate(_:)`` result — including any applied tweaks
        ///   — carrying the key-aggregation session state the session was bound
        ///   to and the aggregate signature verifies against.
        /// - Returns: A verified 64-byte ``AggregateSignature``.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if
        ///   `partialSignatures` is empty, `message` is not exactly 32 bytes, or
        ///   the partial count differs from the session's participant count;
        ///   ``secp256k1Error/underlyingCryptoError`` if `xonlyKeyAggregate`
        ///   lacks a usable key aggregation cache, or if the bundled public
        ///   nonces do not re-aggregate to `publicNonceAggregate` — a set-level
        ///   mismatch thrown without an index; compare each contribution's
        ///   ``P256K/Schnorr/PartialSignature/nonce`` against the round-1
        ///   records to identify the signer;
        ///   ``secp256k1Error/invalidMuSigContribution(index:)`` naming the
        ///   position of a partial signature that fails verification against the
        ///   rebuilt session or whose bundled signer is not a session
        ///   participant — including an over-contribution when one signer
        ///   submits more partials than its key list positions.
        static func aggregateSignatures(
            _ partialSignatures: [P256K.Schnorr.PartialSignature],
            for message: some ContiguousBytes,
            publicNonceAggregate: P256K.MuSig.Nonce,
            xonlyKeyAggregate: P256K.MuSig.XonlyKey
        ) throws -> P256K.MuSig.AggregateSignature {
            guard partialSignatures.isEmpty == false else {
                throw secp256k1Error.incorrectParameterSize
            }

            let context = P256K.Context.rawRepresentation
            var signature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
            var aggPubkey = secp256k1_pubkey()
            var xonlyPubkey = secp256k1_xonly_pubkey()
            var pkParity: Int32 = 0
            var cache = secp256k1_musig_keyagg_cache()
            var session = secp256k1_musig_session()
            var aggnonce = secp256k1_musig_aggnonce()

            // `secp256k1_musig_nonce_process` reads a fixed `msg32` — reject any
            // other length rather than silently rebuilding a session over the
            // wrong message.
            let messageBytes = try message.exactMsg32Bytes

            // `keyagg_cache_load` checks the blob's magic prefix inside `ARG_CHECK`,
            // which aborts on a zeroed or malformed struct — a missing or corrupt
            // cache must throw before the copy, not reach upstream.
            guard MuSigOpaqueState.isValidKeyAggregationCache(xonlyKeyAggregate.cache) else {
                throw secp256k1Error.underlyingCryptoError
            }

            // The submitted signer set must equal the session's participant
            // list — the exact multiset `aggregate(_:)` hashed into the cache as
            // `pks_hash`, retained on the key because the opaque cache cannot
            // return it. `partial_sig_verify` proves only algebraic consistency:
            // `keyaggcoef` assigns a coefficient to any public key, so a
            // stranger's valid partial, a duplicate submission, or a missing
            // signer would each pass per-partial verification yet corrupt the
            // aggregate into the unreachable-failure channel below. The running
            // tally attributes blame by index: a missing `allowance` entry is a
            // non-participant, a depleted one an over-contribution.
            guard partialSignatures.count == xonlyKeyAggregate.participants.count else {
                throw secp256k1Error.incorrectParameterSize
            }
            var allowance = xonlyKeyAggregate.participants.reduce(into: [[UInt8]: Int]()) { tally, participant in
                tally[participant.musigIdentity, default: 0] += 1
            }
            for (index, partial) in partialSignatures.enumerated() {
                let identity = partial.publicKey.musigIdentity
                guard let remaining = allowance[identity], remaining > 0 else {
                    throw secp256k1Error.invalidMuSigContribution(index: index)
                }
                allowance[identity] = remaining - 1
            }

            xonlyKeyAggregate.cache.copyToUnsafeMutableBytes(of: &cache.data)
            publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

            // `nonce_process` is deterministic over (aggregate nonce, msg32,
            // cache) — the session the signers bound is rebuilt here, the same
            // reconstruction `partialSignature` and the partial verifier
            // perform. Cache and aggregate nonce are construction-validated, so
            // `nonce_process` cannot legitimately fail.
            guard secp256k1_musig_nonce_process(context, &session, &aggnonce, messageBytes, &cache).boolValue else {
                P256K.invariantFailure("secp256k1_musig_nonce_process failed on validated session inputs — library bug")
            }

            // Verify every contribution against the rebuilt session before
            // aggregating — BIP-327's "Identifying Disruptive Signers": a
            // signature produced over a different message or nonce set, or
            // bundled with a foreign key/nonce pairing, throws naming the
            // contributor's index instead of corrupting the aggregate and
            // terminating. `dataRepresentation` was parse-validated at
            // `PartialSignature` construction, so a parse failure can only
            // indicate corruption or a library bug.
            var partialSigs = [secp256k1_musig_partial_sig]()
            partialSigs.reserveCapacity(partialSignatures.count)

            for (index, partialSignature) in partialSignatures.enumerated() {
                var partialSig = secp256k1_musig_partial_sig()
                var pubnonce = secp256k1_musig_pubnonce()
                var signerPublicKey = partialSignature.publicKey.baseKey.rawRepresentation

                partialSignature.nonce.pubnonce.copyToUnsafeMutableBytes(of: &pubnonce.data)

                guard secp256k1_musig_partial_sig_parse(
                    context,
                    &partialSig,
                    Array(partialSignature.dataRepresentation)
                ).boolValue else {
                    P256K.invariantFailure("secp256k1_musig_partial_sig_parse failed on construction-validated bytes — output corruption or library bug")
                }
                guard secp256k1_musig_partial_sig_verify(
                    context,
                    &partialSig,
                    &pubnonce,
                    &signerPublicKey,
                    &cache,
                    &session
                ).boolValue else {
                    throw secp256k1Error.invalidMuSigContribution(index: index)
                }
                partialSigs.append(partialSig)
            }

            // Every contribution passed per-partial verification — but
            // `partial_sig_verify` proves each signature against the pubnonce
            // it is handed without proving that nonce contributed to the
            // declared aggregate (upstream makes it a caller precondition:
            // `secp256k1_musig.h` "the `pubnonce` must be the nonce sent by
            // the signer"). A participant signing under this session with an
            // uncontributed nonce pair verifies above yet makes ΣR_i ≠ R,
            // which would trip the final signature check into
            // `invariantFailure`. Re-aggregating the bundled nonces restores
            // BIP-327's structural binding — the submitted set must be exactly
            // the one `publicNonceAggregate` was built from. The mismatch is a
            // set property (no per-index blame is derivable from a point sum),
            // so it throws unattributed; the coordinator identifies the signer
            // by comparing each envelope's ``P256K/Schnorr/PartialSignature/nonce``
            // against its round-1 nonce records. Duplicate submissions under a
            // duplicated participant key land here too.
            guard try Self.Nonce(
                aggregating: partialSignatures.map(\.nonce)
            ).dataRepresentation == publicNonceAggregate.dataRepresentation else {
                throw secp256k1Error.underlyingCryptoError
            }

            // The session was rebuilt in this call and every partial signature
            // parsed into a live `secp256k1_musig_partial_sig` — aggregation
            // cannot legitimately fail on these inputs.
            guard PointerArrayUtility.withUnsafePointerArray(
                partialSigs,
                { pointers in
                    secp256k1_musig_partial_sig_agg(context, &signature, &session, pointers, pointers.count).boolValue
                }
            ) else {
                P256K.invariantFailure("secp256k1_musig_partial_sig_agg failed on rebuilt session and validated signatures — output corruption or library bug")
            }

            // Test seam (spec 004 Group E): mutates the produced bytes between
            // aggregation and the self-check; a no-op when unbound.
            signature.withUnsafeMutableBytes(P256K.corruptProducedSignature)

            // The verifying key derives from the same provenance-established
            // cache — `pubkey_get` yields the tweaked aggregate automatically
            // for Taproot sessions — so every input to the final check is the
            // declared one. `xonly_pubkey_from_pubkey` and `pubkey_get` fail
            // only on unloadable inputs; a `schnorrsig_verify` failure after
            // the checks above needs output corruption, a library bug, or a
            // negligible-probability effective-nonce-at-infinity session —
            // upstream substitutes `G` when `R₁ + b·R₂` sums to the point at
            // infinity (`session_impl.h`), and forcing that sum from peer
            // input requires a committed nonce's discrete log.
            guard secp256k1_musig_pubkey_get(context, &aggPubkey, &cache).boolValue else {
                P256K.invariantFailure("secp256k1_musig_pubkey_get failed on rebuilt cache — library bug")
            }
            guard secp256k1_xonly_pubkey_from_pubkey(context, &xonlyPubkey, &pkParity, &aggPubkey).boolValue else {
                P256K.invariantFailure("secp256k1_xonly_pubkey_from_pubkey failed on aggregate key — library bug")
            }
            guard secp256k1_schnorrsig_verify(context, signature, messageBytes, P256K.ByteLength.dimension, &xonlyPubkey).boolValue else {
                P256K.invariantFailure("produced MuSig aggregate signature failed verification against the aggregate x-only key — output corruption or library bug")
            }

            return Self.AggregateSignature(Data(signature))
        }

        /// Convenience overload of ``aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``
        /// taking the full ``P256K/MuSig/PublicKey`` returned by ``aggregate(_:)``.
        ///
        /// - Parameter partialSignatures: All signers' ``P256K/Schnorr/PartialSignature``
        ///   values; must include every participant's partial signature.
        /// - Parameter message: The message that was signed — must be exactly 32
        ///   bytes; `secp256k1_musig_nonce_process` binds a fixed `msg32` into
        ///   the session.
        /// - Parameter publicNonceAggregate: The ``P256K/MuSig/Nonce`` aggregated
        ///   from all signers' public nonces for this session.
        /// - Parameter publicKeyAggregate: The ``P256K/MuSig/PublicKey`` returned
        ///   by ``aggregate(_:)`` — including any applied tweaks.
        /// - Returns: A verified 64-byte ``AggregateSignature``.
        /// - Throws: The same errors as the canonical overload.
        static func aggregateSignatures(
            _ partialSignatures: [P256K.Schnorr.PartialSignature],
            for message: some ContiguousBytes,
            publicNonceAggregate: P256K.MuSig.Nonce,
            publicKeyAggregate: P256K.MuSig.PublicKey
        ) throws -> P256K.MuSig.AggregateSignature {
            try aggregateSignatures(
                partialSignatures,
                for: message,
                publicNonceAggregate: publicNonceAggregate,
                xonlyKeyAggregate: publicKeyAggregate.xonly
            )
        }
    }

    // MARK: - PartialSignature

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// MuSig2 partial signature produced by one signer via
        /// ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``;
        /// combined with all others by
        /// ``P256K/MuSig/aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``.
        ///
        /// ## Overview
        ///
        /// Each signer produces one ``PartialSignature`` per signing session. The partial
        /// signature does **not** verify as a standalone signature; it only becomes valid
        /// after all partial signatures are aggregated into a
        /// ``P256K/MuSig/AggregateSignature``.
        ///
        /// The stored bytes are the canonical 32-byte wire format produced by
        /// `secp256k1_musig_partial_sig_serialize` and consumed by
        /// `secp256k1_musig_partial_sig_parse` — not the 36-byte opaque
        /// `secp256k1_musig_partial_sig` struct, which is rebuilt via the parse
        /// entry point at each use site. See
        /// [`secp256k1/include/secp256k1_musig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_musig.h)
        /// for the upstream declarations.
        ///
        /// Alongside the wire bytes the value carries the signer's ``publicKey``
        /// and public ``nonce`` — BIP-327's `pk i` and `pubnonce i`, the public
        /// material exchanged in rounds 0–1 — so a coordinator needs nothing else
        /// to verify the contribution. The upstream `secp256k1_musig_session` is
        /// never carried: it is process-local state rebuilt at each use site from
        /// the declared (aggregate nonce, message, key-aggregation cache) triple,
        /// so no opaque caller-supplied blob can reach a crash path.
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:publicKey:nonce:)``
        ///
        /// ### Inspection
        /// - ``dataRepresentation``
        /// - ``publicKey``
        /// - ``nonce``
        struct PartialSignature: ContiguousBytes {
            /// The 32-byte canonical wire representation of the partial signature.
            ///
            /// Validated at construction by `secp256k1_musig_partial_sig_parse` —
            /// the encoded scalar must be below the curve order — and rebuilt
            /// through that parse entry point at each upstream use rather than
            /// copied into the 36-byte opaque struct.
            public private(set) var dataRepresentation: Data

            /// The public key of the signer who produced this partial signature —
            /// BIP-327's `pk i`.
            ///
            /// The same ``P256K/Schnorr/PublicKey`` the signer exchanged when the
            /// key list was agreed upon (round 0); ``P256K/MuSig/PublicKey/isValidSignature(_:for:publicNonceAggregate:)``
            /// and ``P256K/MuSig/aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``
            /// require it to be a participant of the session.
            public let publicKey: P256K.Schnorr.PublicKey

            /// The public nonce this signer contributed to the session's aggregate
            /// nonce — BIP-327's `pubnonce i`.
            ///
            /// The same ``P256K/Schnorr/Nonce`` the signer broadcast in round 1 and
            /// that entered ``P256K/MuSig/Nonce/init(aggregating:)``; verification
            /// binds the partial signature to exactly this nonce.
            public let nonce: P256K.Schnorr.Nonce

            /// Creates a ``PartialSignature`` from serialized partial signature
            /// bytes plus the signer's public key and public nonce.
            ///
            /// - Parameter dataRepresentation: The 32-byte wire form from
            ///   `secp256k1_musig_partial_sig_serialize` (or another BIP-327 implementation).
            /// - Parameter publicKey: The signer's ``P256K/Schnorr/PublicKey`` as
            ///   exchanged in round 0.
            /// - Parameter nonce: The signer's ``P256K/Schnorr/Nonce`` as exchanged
            ///   in round 1 — reconstruct it via ``P256K/Schnorr/Nonce/init(dataRepresentation:)``
            ///   from the 66-byte wire form.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `dataRepresentation`
            ///   is not exactly 32 bytes; ``secp256k1Error/underlyingCryptoError``
            ///   if the encoded scalar fails `secp256k1_musig_partial_sig_parse`.
            public init<D: DataProtocol>(
                dataRepresentation: D,
                publicKey: P256K.Schnorr.PublicKey,
                nonce: P256K.Schnorr.Nonce
            ) throws {
                guard dataRepresentation.count == P256K.ByteLength.dimension else {
                    throw secp256k1Error.incorrectParameterSize
                }

                var partialSig = secp256k1_musig_partial_sig()

                // `secp256k1_musig_partial_sig_parse` reads exactly 32 bytes and
                // rejects out-of-range scalars; the signer key and nonce arrive
                // as already-validated Swift types.
                guard secp256k1_musig_partial_sig_parse(
                    P256K.Context.rawRepresentation,
                    &partialSig,
                    Array(dataRepresentation)
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.dataRepresentation = Data(dataRepresentation)
                self.publicKey = publicKey
                self.nonce = nonce
            }

            /// Creates a ``PartialSignature`` from a pre-validated wire-form
            /// partial signature plus the signer's public key and public nonce.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.dimension` (32).
            init(_ dataRepresentation: Data, publicKey: P256K.Schnorr.PublicKey, nonce: P256K.Schnorr.Nonce) {
                precondition(dataRepresentation.count == P256K.ByteLength.dimension, "Invalid partial signature size")
                self.dataRepresentation = dataRepresentation
                self.publicKey = publicKey
                self.nonce = nonce
            }

            /// Calls `body` with an unsafe pointer to the partial signature's raw bytes.
            ///
            /// - Parameter body: A closure receiving a raw buffer pointer over the signature data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

#endif
