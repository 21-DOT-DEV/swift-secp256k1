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
        /// BIP-327 MuSig2 multi-signature namespace for secp256k1: aggregate signer public keys with ``aggregate(_:)``, coordinate nonce generation, collect partial signatures, and aggregate into a final 64-byte ``AggregateSignature``.
        ///
        /// MuSig2 allows N parties to collaboratively produce a single BIP-340 Schnorr signature
        /// that verifies against an aggregated public key (`secp256k1_musig_pubkey_agg`), without
        /// revealing each signer's individual key. The aggregate key is indistinguishable from a
        /// regular secp256k1 public key, making multi-signatures compatible with all Schnorr
        /// verifiers including Taproot (BIP-341).
        ///
        /// ## Signing Protocol Order
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
        /// ## Nonce Reuse
        ///
        /// **Nonce reuse leaks the secret signing key.** The ``P256K/Schnorr/SecureNonce`` type is `~Copyable`
        /// to prevent accidental duplication. The underlying `secp256k1_musig_secnonce` struct is
        /// zeroed by `secp256k1_musig_partial_sign` after use; never copy or serialize the secret
        /// nonce bytes. Always provide a unique `sessionID` per signing session.
        enum MuSig {
            /// secp256k1 MuSig2 aggregate public key produced by ``aggregate(_:)`` via `secp256k1_musig_pubkey_agg`, used for partial signature verification and Taproot tweaking.
            public struct PublicKey {
                /// The internal backing public key implementation.
                let baseKey: PublicKeyImplementation

                /// The serialized public key bytes in the key's ``format``.
                var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// The 197-byte opaque `secp256k1_musig_keyagg_cache` required for signing sessions and Taproot tweaking.
                var keyAggregationCache: Data {
                    Data(baseKey.cache)
                }

                /// The serialization format of this public key: `.compressed` (33 bytes) or `.uncompressed` (65 bytes).
                public var format: P256K.Format {
                    baseKey.format
                }

                /// The serialized public key bytes as `Data`, in the key's ``format``.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The 32-byte x-only form of this aggregate public key for BIP-340 Schnorr signature verification and Taproot output construction.
                public var xonly: XonlyKey {
                    XonlyKey(baseKey: baseKey.xonly)
                }

                /// Creates a MuSig public key from a validated backing implementation.
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

            /// The 32-byte x-only form of a MuSig2 aggregate public key, used for BIP-340 Schnorr signature verification and Taproot tweaking via ``add(_:)``.
            public struct XonlyKey: Equatable {
                /// The internal backing x-only key implementation.
                private let baseKey: XonlyKeyImplementation

                /// The 32-byte X coordinate of the aggregate public key.
                public var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// The parity of the aggregate public key's Y coordinate, as returned by `secp256k1_xonly_pubkey_from_pubkey`; used in Taproot tweak verification.
                public var parity: Bool {
                    baseKey.keyParity.boolValue
                }

                /// The 197-byte opaque `secp256k1_musig_keyagg_cache` required for Taproot tweaking and signing sessions; must be preserved alongside the key bytes.
                public var cache: Data {
                    Data(baseKey.cache)
                }

                /// Creates a MuSig x-only key from a validated backing implementation.
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
