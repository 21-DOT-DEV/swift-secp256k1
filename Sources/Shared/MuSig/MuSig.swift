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

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

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
        /// ([`Vendor/secp256k1-zkp/include/secp256k1_musig.h`](https://github.com/BlockstreamResearch/secp256k1-zkp/blob/master/include/secp256k1_musig.h))
        /// is the normative reference for every method here; the Swift surface wraps those
        /// functions with type-safe session state.
        ///
        /// ### Signing Protocol Order
        ///
        /// The upstream `secp256k1_musig.h` mandates a strict protocol order. Deviating from
        /// this order may produce invalid or insecure signatures:
        ///
        /// 1. **Key aggregation**: Call ``aggregate(_:)`` once with all signers' public keys.
        /// 2. **Nonce generation**: Each signer calls ``Nonce/generate(secretKey:publicKey:msg32:extraInput32:)`` with a unique session ID.
        /// 3. **Nonce aggregation**: Collect all ``P256K/Schnorr/Nonce`` values; any party calls ``Nonce/init(aggregating:)``.
        /// 4. **Partial signing**: Each signer calls ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``.
        /// 5. **Signature aggregation**: Any party calls ``aggregateSignatures(_:)``.
        ///
        /// ### Nonce Reuse
        ///
        /// **Nonce reuse leaks the secret signing key.** The ``P256K/Schnorr/SecureNonce`` type is `~Copyable`
        /// to prevent accidental duplication. The underlying `secp256k1_musig_secnonce` struct is
        /// zeroed by `secp256k1_musig_partial_sign` after use; never copy or serialize the secret
        /// nonce bytes. Always provide a unique `sessionID` per signing session.
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
        /// - ``aggregateSignatures(_:)``
        ///
        /// ### Session Types
        /// - ``AggregateSignature``
        enum MuSig {
            /// secp256k1 MuSig2 aggregate public key produced by ``aggregate(_:)`` via `secp256k1_musig_pubkey_agg`, used for partial signature verification and Taproot tweaking.
            ///
            /// An aggregate public key is indistinguishable from a single-signer secp256k1
            /// public key by any external observer, which is precisely what gives MuSig2 its
            /// Taproot compatibility. Internally the key carries the 197-byte
            /// `secp256k1_musig_keyagg_cache` produced by `secp256k1_musig_pubkey_agg`; that
            /// cache is required to reconstruct the key-aggregation coefficients during the
            /// partial-signing phase and **must** be preserved alongside the public-key bytes
            /// when serializing the aggregate across a process boundary.
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
            /// - ``init(dataRepresentation:format:cache:)``
            public struct PublicKey {
                /// The internal ``PublicKeyImplementation`` backing this aggregate, produced
                /// by `secp256k1_musig_pubkey_agg` and carrying the 197-byte
                /// `secp256k1_musig_keyagg_cache` required for signing sessions.
                ///
                /// Kept `internal` — consumers never see or manipulate the raw C cache through
                /// the public API; they must round-trip via ``dataRepresentation`` + ``xonly``
                /// + the ``cache`` helper on ``XonlyKey`` when serializing the aggregate.
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
                /// External persistence of the aggregate goes through ``xonly`` which exposes
                /// the cache alongside a stable 32-byte x-only identifier.
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
                /// Suitable for transmission and storage. **Note**: for full reconstruction
                /// on the receiving side, you must also transmit the ``XonlyKey/cache`` from
                /// ``xonly`` — the raw bytes alone do not carry the MuSig key-aggregation
                /// coefficients required for the partial-signing phase.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The 32-byte x-only form of this aggregate public key for BIP-340 Schnorr
                /// signature verification and Taproot output construction.
                ///
                /// The x-only form is the **canonical** external representation for a MuSig
                /// aggregate: it matches what a BIP-340 verifier expects, and its parity bit
                /// is exactly what a BIP-341 Taproot output-key derivation consumes. The
                /// returned ``XonlyKey`` also carries the 197-byte keyagg cache required for
                /// future signing sessions against this aggregate.
                public var xonly: XonlyKey {
                    XonlyKey(baseKey: baseKey.xonly)
                }

                /// Creates a MuSig public key from a validated backing implementation.
                ///
                /// Internal-visibility constructor used by ``aggregate(_:)`` after
                /// `secp256k1_musig_pubkey_agg` returns successfully. Consumers reconstruct
                /// via ``init(xonlyKey:)`` or ``init(dataRepresentation:format:cache:)``
                /// instead.
                ///
                /// - Parameter baseKey: A ``PublicKeyImplementation`` produced by the upstream
                ///   C aggregation call, with its 197-byte keyagg cache populated.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// Creates a MuSig aggregate public key from its x-only form, restoring the key aggregation cache.
                ///
                /// - Parameter xonlyKey: An ``XonlyKey`` whose ``XonlyKey/cache`` was preserved from the original ``aggregate(_:)`` call.
                public init(xonlyKey: XonlyKey) {
                    let key = XonlyKeyImplementation(
                        dataRepresentation: xonlyKey.bytes,
                        keyParity: xonlyKey.parity ? 1 : 0,
                        cache: xonlyKey.cache.bytes
                    )
                    self.baseKey = PublicKeyImplementation(xonlyKey: key)
                }

                /// Creates a MuSig aggregate public key from serialized bytes and a preserved key aggregation cache.
                ///
                /// - Parameter data: Serialized public key bytes matching `format.length`.
                /// - Parameter format: The serialization format of `data`.
                /// - Parameter cache: The 197-byte `secp256k1_musig_keyagg_cache` from the original ``aggregate(_:)`` call; required for signing sessions.
                /// - Throws: ``secp256k1Error/underlyingCryptoError`` if parsing via `secp256k1_ec_pubkey_parse` fails.
                public init<D: ContiguousBytes>(
                    dataRepresentation data: D,
                    format: P256K.Format,
                    cache: [UInt8]
                ) throws {
                    self.baseKey = try PublicKeyImplementation(
                        dataRepresentation: data,
                        format: format,
                        cache: cache
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
            /// - ``bytes``
            /// - ``parity``
            /// - ``cache``
            ///
            /// ### Reconstruction
            /// - ``init(dataRepresentation:keyParity:cache:)``
            public struct XonlyKey: Equatable {
                /// The internal ``XonlyKeyImplementation`` backing this aggregate x-only key.
                ///
                /// Kept `private` — the backing type is an internal convenience over the
                /// upstream `secp256k1_xonly_pubkey` struct; consumers never see or manipulate
                /// it directly through the public API.
                private let baseKey: XonlyKeyImplementation

                /// The 32-byte X coordinate of the aggregate public key.
                ///
                /// Stable across libsecp256k1 versions — safe to persist as a Bitcoin-
                /// address-style identifier. Pair with ``parity`` and ``cache`` when the
                /// aggregate needs to be reconstructed for a future signing session.
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
                /// tweaking and signing sessions; must be preserved alongside the key bytes.
                ///
                /// The cache bytes are **not** a stable serialization format across
                /// libsecp256k1 versions — treat them as a within-process session token.
                /// For cross-process persistence, store them in an ephemeral location
                /// (e.g. alongside a one-shot signing session's other state) rather than
                /// in long-lived configuration.
                public var cache: Data {
                    Data(baseKey.cache)
                }

                /// Creates a MuSig x-only key from a validated backing implementation.
                ///
                /// Internal-visibility constructor used by the aggregate public key's
                /// ``PublicKey/xonly`` accessor; consumers reconstruct via the public
                /// initializer below.
                ///
                /// - Parameter baseKey: A ``XonlyKeyImplementation`` produced by the upstream
                ///   C conversion from an aggregate `secp256k1_pubkey`.
                init(baseKey: XonlyKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// Creates a MuSig x-only public key from 32-byte serialized data and a preserved key aggregation cache.
                ///
                /// - Parameter data: The 32-byte X coordinate of the aggregate public key.
                /// - Parameter keyParity: The Y-coordinate parity (`0` = even, `1` = odd) as returned by `secp256k1_xonly_pubkey_from_pubkey`.
                /// - Parameter cache: The 197-byte `secp256k1_musig_keyagg_cache` from the original ``aggregate(_:)`` call.
                public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32 = 0, cache: [UInt8] = []) {
                    self.baseKey = XonlyKeyImplementation(dataRepresentation: data, keyParity: keyParity, cache: cache)
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

    extension secp256k1_musig_partial_sig {
        var dataValue: Data {
            var mutableSig = self
            return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
        }
    }

#endif
