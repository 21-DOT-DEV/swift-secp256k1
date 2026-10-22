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
        /// aggregate public key via `secp256k1_musig_pubkey_agg`, sorting keys first with
        /// `secp256k1_ec_pubkey_sort` so the result is order-independent. Upstream
        /// reference:
        /// [`secp256k1/include/secp256k1_musig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_musig.h).
        ///
        /// The returned ``PublicKey`` includes the 197-byte `secp256k1_musig_keyagg_cache`
        /// needed for signing sessions and Taproot tweaking. Different orderings of the
        /// same multiset of public keys produce the same aggregate because keys are sorted
        /// before aggregation.
        ///
        /// - Parameter pubkeys: All signers' ``P256K/Schnorr/PublicKey`` values; must
        ///   contain at least one key.
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

            // Every pubkey was parse-validated at construction, so sorting and
            // aggregating them cannot legitimately fail. Upstream calls a
            // point-at-infinity aggregate unreachable ("negligible probability" —
            // the per-key coefficients are hash-derived) and guards it only with
            // `VERIFY_CHECK`, which is compiled out in release builds — in that
            // case `pubkey_load`'s `ARG_CHECK` inside `ec_pubkey_serialize` reports
            // through the installed invariant handler before the process ends.
            PointerArrayUtility
                .withUnsafePointerArray(pubkeys.map { $0.baseKey.rawRepresentation }) { pointers in
                    guard secp256k1_ec_pubkey_sort(context, &pointers, pointers.count).boolValue else {
                        P256K.invariantFailure("secp256k1_ec_pubkey_sort failed on validated keys — library bug")
                    }
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
                )
            )
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// 64-byte
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// signature produced by ``aggregateSignatures(_:)`` from all signers'
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
        /// > guarantee the resulting signature is valid — always verify with
        /// > ``XonlyKey/isValidSignature(_:for:)``.
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
        /// ``AggregateSignature`` via `secp256k1_musig_partial_sig_agg`.
        ///
        /// > Important: A return value of `1` from the underlying C function does **not**
        /// > guarantee the result verifies — always call
        /// > ``XonlyKey/isValidSignature(_:for:)`` on the output to confirm the aggregate
        /// > signature is valid against the aggregate public key.
        ///
        /// - Parameter partialSignatures: All signers' ``P256K/Schnorr/PartialSignature``
        ///   values; must include every participant's partial signature.
        /// - Returns: A 64-byte ``AggregateSignature`` that may be verified with
        ///   `secp256k1_schnorrsig_verify`.
        /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `partialSignatures` is
        ///   empty; ``secp256k1Error/underlyingCryptoError`` if the signatures were made
        ///   against different sessions or `secp256k1_musig_partial_sig_agg` fails.
        static func aggregateSignatures(
            _ partialSignatures: [P256K.Schnorr.PartialSignature]
        ) throws -> P256K.MuSig.AggregateSignature {
            guard partialSignatures.isEmpty == false else {
                throw secp256k1Error.incorrectParameterSize
            }

            let context = P256K.Context.rawRepresentation
            var signature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
            var session = secp256k1_musig_session()

            // `secp256k1_musig_session_load` checks the blob's magic prefix inside
            // `ARG_CHECK`, which aborts on mismatch — validate before the copy so
            // malformed state throws instead of terminating the process. Upstream's
            // model is a single shared session, so every signature must carry the
            // same session blob — mixing sessions would silently aggregate under
            // the first signature's session.
            guard let sessionBytes = partialSignatures.first?.session,
                  MuSigOpaqueState.isValidSession(sessionBytes),
                  partialSignatures.allSatisfy({ $0.session == sessionBytes }) else {
                throw secp256k1Error.underlyingCryptoError
            }

            sessionBytes.copyToUnsafeMutableBytes(of: &session.data)

            // Every wire blob must parse into a live `secp256k1_musig_partial_sig`;
            // `partial_sig_load` aborts on a zeroed or malformed struct, and a
            // parse failure previously went unchecked here.
            var partialSigs = [secp256k1_musig_partial_sig]()
            partialSigs.reserveCapacity(partialSignatures.count)

            for partialSignature in partialSignatures {
                var partialSig = secp256k1_musig_partial_sig()
                guard secp256k1_musig_partial_sig_parse(
                    context,
                    &partialSig,
                    Array(partialSignature.dataRepresentation)
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }
                partialSigs.append(partialSig)
            }

            guard PointerArrayUtility.withUnsafePointerArray(
                partialSigs,
                { pointers in
                    secp256k1_musig_partial_sig_agg(context, &signature, &session, pointers, pointers.count).boolValue
                }
            ) else {
                throw secp256k1Error.underlyingCryptoError
            }

            return Self.AggregateSignature(Data(signature))
        }
    }

    // MARK: - PartialSignature

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// MuSig2 partial signature produced by one signer via
        /// ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``;
        /// combined with all others by ``P256K/MuSig/aggregateSignatures(_:)``.
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
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:session:)``
        ///
        /// ### Inspection
        /// - ``dataRepresentation``
        /// - ``session``
        struct PartialSignature: ContiguousBytes {
            /// The 32-byte canonical wire representation of the partial signature.
            ///
            /// Validated at construction by `secp256k1_musig_partial_sig_parse` —
            /// the encoded scalar must be below the curve order — and rebuilt
            /// through that parse entry point at each upstream use rather than
            /// copied into the 36-byte opaque struct.
            public private(set) var dataRepresentation: Data

            /// The 133-byte `secp256k1_musig_session` state required for aggregation and
            /// verification.
            ///
            /// Opaque upstream struct holding the per-session state (aggregate nonce,
            /// message hash, tweak state, etc.) populated by `secp256k1_musig_nonce_process`
            /// and consumed by `secp256k1_musig_partial_sig_agg`. Validated at
            /// construction by exact length and the upstream magic prefix. Treat as a
            /// within-process session token; not a stable serialization format.
            public private(set) var session: Data

            /// Creates a ``PartialSignature`` from serialized partial signature bytes and session data.
            ///
            /// - Parameter dataRepresentation: The 32-byte wire form from
            ///   `secp256k1_musig_partial_sig_serialize` (or another BIP-327 implementation).
            /// - Parameter session: The 133-byte `secp256k1_musig_session` state blob.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `dataRepresentation` is
            ///   not exactly 32 bytes or `session` is not exactly 133 bytes;
            ///   ``secp256k1Error/underlyingCryptoError`` if the scalar fails
            ///   `secp256k1_musig_partial_sig_parse` or `session` lacks the upstream
            ///   magic prefix.
            public init<D: DataProtocol, S: DataProtocol>(dataRepresentation: D, session: S) throws {
                guard dataRepresentation.count == P256K.ByteLength.dimension, session.count == MuSigOpaqueState.sessionByteCount else {
                    throw secp256k1Error.incorrectParameterSize
                }

                var partialSig = secp256k1_musig_partial_sig()

                // `secp256k1_musig_partial_sig_parse` reads exactly 32 bytes and
                // rejects out-of-range scalars; `session_load` would `abort()` on
                // a missing magic prefix, so both are checked up front.
                guard secp256k1_musig_partial_sig_parse(
                    P256K.Context.rawRepresentation,
                    &partialSig,
                    Array(dataRepresentation)
                ).boolValue, MuSigOpaqueState.isValidSession(session) else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.dataRepresentation = Data(dataRepresentation)
                self.session = Data(session)
            }

            /// Creates a ``PartialSignature`` from pre-validated wire-form partial signature and session data.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.dimension` (32) and `session.count` must equal ``MuSigOpaqueState/sessionByteCount``.
            init(_ dataRepresentation: Data, session: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.dimension, "Invalid partial signature size")
                precondition(session.count == MuSigOpaqueState.sessionByteCount, "Invalid session size")
                self.dataRepresentation = dataRepresentation
                self.session = session
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
