//
//  MuSig.swift
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
    public extension P256K {
        /// MuSig2 multi-signature namespace for secp256k1
        /// ([BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)):
        /// aggregate signer public keys with ``aggregate(_:)``, coordinate nonce generation,
        /// collect partial signatures, and aggregate into a final 64-byte ``AggregateSignature``.
        ///
        /// ## Overview
        ///
        /// MuSig2 allows N parties to collaboratively produce a single
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// signature that verifies against an aggregated public key (`secp256k1_musig_pubkey_agg`),
        /// without revealing each signer's individual key. The aggregate key is indistinguishable
        /// from a regular secp256k1 public key, making multi-signatures compatible with all
        /// Schnorr verifiers including Taproot
        /// ([BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)).
        ///
        /// Key aggregation requires **no trusted dealer** — every signer runs the aggregation
        /// locally and arrives at the same result by deterministic protocol. The upstream C
        /// implementation
        /// ([`secp256k1/include/secp256k1_musig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_musig.h))
        /// is the normative reference for every method here; the Swift surface wraps those
        /// functions with type-safe session state.
        ///
        /// ### Signing Protocol Order
        ///
        /// The upstream `secp256k1_musig.h` mandates a strict protocol order. Deviating from
        /// this order may produce invalid or insecure signatures:
        ///
        /// 1. **Key aggregation**: Call ``aggregate(_:)`` once with all signers' public keys
        ///    in the protocol's agreed order — the aggregate depends on that order, so use
        ///    ``sortedPublicKeys(_:)`` when no protocol-defined ordering applies.
        /// 2. **Nonce generation**: Each signer calls ``Nonce/generate(secretKey:publicKey:msg32:extraInput32:)``,
        ///    which supplies a fresh ``SessionSecretRand`` internally. The
        ///    ``Nonce/generate(sessionSecretRand:secretKey:publicKey:msg32:extraInput32:)`` overload
        ///    exists for deterministic inputs such as test vectors — never reuse a value across sessions.
        /// 3. **Nonce aggregation**: Collect all ``P256K/Schnorr/Nonce`` values; any party calls ``Nonce/init(aggregating:)``.
        /// 4. **Partial signing**: Each signer calls ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``.
        /// 5. **Signature aggregation**: Any party calls
        ///    ``aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``.
        ///
        /// ### Nonce Reuse
        ///
        /// **Nonce reuse leaks the secret signing key.** The ``P256K/Schnorr/SecureNonce`` type is `~Copyable`
        /// to prevent accidental duplication. The underlying `secp256k1_musig_secnonce` struct is
        /// zeroed by `secp256k1_musig_partial_sign` after use; never copy or serialize the secret
        /// nonce bytes. Always provide a unique ``SessionSecretRand`` per signing session.
        ///
        /// ### Taproot Compatibility
        ///
        /// The aggregate public key's ``PublicKey/xonly`` form is directly usable as a BIP-341
        /// Taproot internal key, and the aggregate signature is a valid BIP-340 Schnorr
        /// signature over the aggregate x-only key. Consumers can therefore MuSig-aggregate
        /// N cosigners and plug the result into any Taproot-compatible wallet or script-path
        /// without a custom verifier.
        ///
        /// ## Topics
        ///
        /// ### Aggregation
        /// - ``PublicKey``
        /// - ``XonlyKey``
        /// - ``aggregate(_:)``
        /// - ``sortedPublicKeys(_:)``
        /// - ``aggregateSignatures(_:for:publicNonceAggregate:xonlyKeyAggregate:)``
        ///
        /// ### Session Types
        /// - ``AggregateSignature``
        /// - ``SessionSecretRand``
        enum MuSig {
            /// secp256k1 MuSig2 aggregate public key produced by ``aggregate(_:)`` via `secp256k1_musig_pubkey_agg`, used for partial signature verification and Taproot tweaking.
            ///
            /// An aggregate public key is indistinguishable from a single-signer secp256k1
            /// public key by any external observer, which is precisely what gives MuSig2 its
            /// Taproot compatibility. Internally the key carries the 197-byte
            /// `secp256k1_musig_keyagg_cache` produced by `secp256k1_musig_pubkey_agg`; that
            /// cache reconstructs the key-aggregation coefficients during the
            /// partial-signing phase. It is an opaque upstream struct with no blessed
            /// serialization — same-process session state only, never exposed as bytes —
            /// so a key rebuilt from ``dataRepresentation`` verifies but cannot sign or
            /// tweak: re-run ``aggregate(_:)`` on the participant public keys (and re-apply
            /// any tweaks) to resume a signing session.
            ///
            /// ## Topics
            ///
            /// ### Serialized Forms
            /// - ``dataRepresentation``
            /// - ``format``
            /// - ``xonly``
            ///
            /// ### Reconstruction
            /// - ``init(xonlyKey:)``
            /// - ``init(dataRepresentation:format:)``
            public struct PublicKey {
                /// The internal `PublicKeyImplementation` backing this aggregate, produced
                /// by `secp256k1_musig_pubkey_agg` and carrying the 197-byte
                /// `secp256k1_musig_keyagg_cache` required for signing sessions.
                ///
                /// Kept `internal` — consumers never see or manipulate the raw C cache through
                /// the public API; the serialization story is ``dataRepresentation`` + ``xonly``
                /// for verification, and ``aggregate(_:)`` re-derivation for signing.
                let baseKey: PublicKeyImplementation

                /// The serialized public key bytes in the key's ``format``.
                ///
                /// Internal-visibility passthrough used by the Swift-side MuSig signing and
                /// verification helpers. Callers should use ``dataRepresentation`` for
                /// cross-boundary serialization.
                var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// The 197-byte opaque `secp256k1_musig_keyagg_cache` required for signing
                /// sessions and Taproot tweaking.
                ///
                /// Internal-visibility: the cache is an opaque upstream struct whose bytes
                /// are **not** a stable serialization format across libsecp256k1 versions.
                /// Read in-module by the signing and tweak paths; external persistence goes
                /// through ``xonly``'s stable 32-byte identifier plus re-aggregation.
                var keyAggregationCache: Data {
                    Data(baseKey.cache)
                }

                /// The serialization format of this public key: `.compressed` (33 bytes) or
                /// `.uncompressed` (65 bytes).
                ///
                /// Inherited from whichever format was used when aggregating or reconstructing
                /// the key. Most Bitcoin / Taproot workflows use ``P256K/Format/compressed``;
                /// ``P256K/Format/uncompressed`` is supported for interoperability with
                /// legacy systems that require the full `(x, y)` point encoding.
                public var format: P256K.Format {
                    baseKey.format
                }

                /// The serialized public key bytes as `Data`, in the key's ``format``.
                ///
                /// Suitable for transmission and storage. **Note**: a key rebuilt from
                /// these bytes is verification-only — the signing-side key-aggregation
                /// state upstream stores in its opaque cache struct does not survive
                /// serialization, so resuming a signing session means re-running
                /// ``aggregate(_:)`` over the participant public keys.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The 32-byte x-only form of this aggregate public key for BIP-340 Schnorr
                /// signature verification and Taproot output construction.
                ///
                /// The x-only form is the **canonical** external representation for a MuSig
                /// aggregate: it matches what a BIP-340 verifier expects, and its parity bit
                /// is exactly what a BIP-341 Taproot output-key derivation consumes. The
                /// returned ``XonlyKey`` carries the key-aggregation session state
                /// internally when this key came from ``aggregate(_:)`` or a MuSig
                /// tweak of one — signing and tweaking stay live. An ``XonlyKey``
                /// derived from a key rebuilt via ``init(dataRepresentation:format:)``
                /// is verification-only (no cache was ever loaded).
                public var xonly: XonlyKey {
                    XonlyKey(baseKey: baseKey.xonly)
                }

                /// Creates a MuSig public key from a validated backing implementation.
                ///
                /// Internal-visibility constructor used by ``aggregate(_:)`` after
                /// `secp256k1_musig_pubkey_agg` returns successfully. Consumers reconstruct
                /// via ``init(xonlyKey:)`` or ``init(dataRepresentation:format:)``
                /// instead.
                ///
                /// - Parameter baseKey: A `PublicKeyImplementation` produced by the upstream
                ///   C aggregation call, with its 197-byte keyagg cache populated.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// Creates a MuSig aggregate public key from its x-only form, restoring the key aggregation session state.
                ///
                /// `XonlyKey` validates its coordinate at construction, so the lifted point
                /// is parseable by construction and this initializer cannot fail.
                ///
                /// - Parameter xonlyKey: An ``XonlyKey`` produced by ``aggregate(_:)`` or a
                ///   MuSig tweak — one carrying the key-aggregation session state
                ///   internally. An ``XonlyKey`` rebuilt from ``XonlyKey/dataRepresentation``
                ///   carries none, and the lifted key is verification-only.
                public init(xonlyKey: XonlyKey) {
                    let key = XonlyKeyImplementation(
                        validatedBytes: Array(xonlyKey.dataRepresentation),
                        keyParity: xonlyKey.parity ? 1 : 0,
                        cache: xonlyKey.cache.byteArray
                    )
                    self.baseKey = PublicKeyImplementation(xonlyKey: key)
                }

                /// Creates a MuSig aggregate public key from serialized bytes.
                ///
                /// The reconstructed key verifies signatures but cannot join a signing
                /// session or take MuSig tweaks — the key-aggregation session state lives
                /// in an upstream struct with no blessed serialization, so it exists only
                /// on keys produced by ``aggregate(_:)`` (or a MuSig tweak of one).
                /// Re-aggregate the participant public keys, then re-apply any tweaks, to
                /// resume signing.
                ///
                /// - Parameter data: Serialized public key bytes matching `format.length`.
                /// - Parameter format: The serialization format of `data`.
                /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` does not match `format.length`;
                ///   ``secp256k1Error/underlyingCryptoError`` if parsing via `secp256k1_ec_pubkey_parse` fails.
                public init<D: ContiguousBytes>(
                    dataRepresentation data: D,
                    format: P256K.Format
                ) throws {
                    self.baseKey = try PublicKeyImplementation(
                        dataRepresentation: data,
                        format: format
                    )
                }
            }

            /// The 32-byte x-only form of a MuSig2 aggregate public key, used for BIP-340
            /// Schnorr signature verification and Taproot tweaking via ``add(_:)``.
            ///
            /// X-only keys drop the Y-coordinate parity bit from the standard 33-byte
            /// compressed encoding, matching the representation BIP-340 verifiers consume
            /// directly. The 1-bit parity is retained separately as ``parity`` so Taproot
            /// tweak verification can reconstruct the full point when computing `t * G` and
            /// the subsequent conditional negation.
            ///
            /// ## Topics
            ///
            /// ### Inspection
            /// - ``dataRepresentation``
            /// - ``parity``
            ///
            /// ### Reconstruction
            /// - ``init(dataRepresentation:keyParity:)``
            public struct XonlyKey: Equatable {
                /// The internal `XonlyKeyImplementation` backing this aggregate x-only key.
                ///
                /// Kept `private` — the backing type is an internal convenience over the
                /// upstream `secp256k1_xonly_pubkey` struct; consumers never see or manipulate
                /// it directly through the public API.
                private let baseKey: XonlyKeyImplementation

                /// The 32-byte X coordinate of the aggregate public key as `Data`.
                ///
                /// Stable across libsecp256k1 versions — safe to persist as a Bitcoin-
                /// address-style identifier. Pair with ``parity`` when the aggregate's
                /// full point must be reconstructed; a key rebuilt from bytes verifies
                /// but carries no signing session state — re-run ``aggregate(_:)`` to
                /// resume one.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// Deprecated alias for ``dataRepresentation`` — renamed to match the
                /// library-wide `dataRepresentation: Data` convention.
                @available(*, deprecated, renamed: "dataRepresentation")
                public var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// The parity of the aggregate public key's Y coordinate, as returned by
                /// `secp256k1_xonly_pubkey_from_pubkey`; used in Taproot tweak verification.
                ///
                /// `true` = odd Y, `false` = even Y. BIP-340 signatures are verified against
                /// the even-Y representative of a point, so the parity bit is tracked
                /// separately and consulted during tweak verification (`secp256k1_musig_pubkey_xonly_tweak_add_check`)
                /// and the Taproot output-key derivation (`secp256k1_xonly_pubkey_tweak_add_check`).
                public var parity: Bool {
                    baseKey.keyParity.boolValue
                }

                /// The 197-byte opaque `secp256k1_musig_keyagg_cache` required for Taproot
                /// tweaking and signing sessions.
                ///
                /// Internal-visibility: these bytes are the opaque upstream struct, which
                /// upstream ships with no serialization or parsing functions — not a
                /// stable format across libsecp256k1 versions. Read in-module by the
                /// signing, tweak, and ``PublicKey/init(xonlyKey:)`` paths; the public
                /// surface never hands it out.
                var cache: Data {
                    Data(baseKey.cache)
                }

                /// Creates a MuSig x-only key from a validated backing implementation.
                ///
                /// Internal-visibility constructor used by the aggregate public key's
                /// ``PublicKey/xonly`` accessor; consumers reconstruct via the public
                /// initializer below.
                ///
                /// - Parameter baseKey: A `XonlyKeyImplementation` produced by the upstream
                ///   C conversion from an aggregate `secp256k1_pubkey`.
                init(baseKey: XonlyKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// Creates a MuSig x-only public key from 32-byte serialized data and its Y-coordinate parity.
                ///
                /// The reconstructed key verifies aggregate signatures but carries no
                /// key-aggregation session state — partial signing and MuSig tweaks throw
                /// ``secp256k1Error/underlyingCryptoError`` against it. Re-run
                /// ``aggregate(_:)`` on the participant public keys (and re-apply any
                /// tweaks) to resume a signing session.
                ///
                /// - Parameter data: The 32-byte X coordinate of the aggregate public key.
                /// - Parameter keyParity: The Y-coordinate parity of the full public key:
                ///   `false` = even (the canonical BIP-340 representative — the only honest
                ///   value when parity was never persisted, since it cannot be recovered from
                ///   the X coordinate alone), `true` = odd. Round-trips directly from
                ///   ``parity``.
                /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not exactly 32 bytes;
                ///   ``secp256k1Error/underlyingCryptoError`` if the coordinate fails
                ///   `secp256k1_xonly_pubkey_parse` (out of range or no curve point).
                public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Bool = false) throws {
                    self.baseKey = try XonlyKeyImplementation(dataRepresentation: data, keyParity: keyParity ? 1 : 0)
                }

                /// Returns `true` if both x-only keys have identical 32-byte X coordinates.
                ///
                /// - Parameters:
                ///   - lhs: The left-hand side x-only key.
                ///   - rhs: The right-hand side x-only key.
                /// - Returns: `true` if the X coordinates are equal, `false` otherwise.
                public static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.baseKey.bytes == rhs.baseKey.bytes
                }
            }
        }
    }

    extension secp256k1_musig_session {
        var dataValue: Data {
            var mutableSession = self
            return Data(bytes: &mutableSession.data, count: MemoryLayout.size(ofValue: data))
        }
    }

#endif
