//
//  Schnorr+XonlyKey.swift
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

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// The corresponding x-only public key for the secp256k1 curve, as defined by
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki).
        ///
        /// ## Overview
        ///
        /// X-only keys drop the Y-coordinate parity bit from the 33-byte compressed
        /// encoding, matching the representation BIP-340 verifiers consume directly. The
        /// 1-bit parity is preserved separately as ``parity`` so Taproot tweak verification
        /// can reconstruct the full `(x, y)` point.
        ///
        /// ## Topics
        ///
        /// ### Inspection
        /// - ``bytes``
        /// - ``parity``
        /// - ``cache``
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:keyParity:cache:)``
        struct XonlyKey: Equatable {
            /// The internal `XonlyKeyImplementation` backing this x-only key.
            ///
            /// Kept `private` — the backing type is an internal convenience over the
            /// upstream `secp256k1_xonly_pubkey` struct; consumers never see or manipulate
            /// it directly.
            private let baseKey: XonlyKeyImplementation

            /// The 32-byte X coordinate of this x-only public key.
            ///
            /// Stable across libsecp256k1 versions — safe to persist as a BIP-340-style
            /// key identifier. Pair with ``parity`` if the full `(x, y)` point must be
            /// reconstructed downstream (e.g. for Taproot tweak verification).
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            /// The Y-coordinate parity of the underlying secp256k1 public key.
            ///
            /// `false` = even Y (canonical BIP-340 form), `true` = odd Y. BIP-340 verifiers
            /// operate against the even-Y representative, so the parity bit is tracked
            /// separately and consulted during BIP-341 Taproot tweak verification
            /// (`secp256k1_xonly_pubkey_tweak_add_check`).
            public var parity: Bool {
                baseKey.keyParity.boolValue
            }

            /// Cached `secp256k1_pubkey` bytes associated with this x-only key, avoiding
            /// re-derivation on each operation that needs the full curve point.
            ///
            /// > Important: These bytes are the opaque upstream `secp256k1_pubkey` struct
            /// > and are **not** a stable serialization format across libsecp256k1
            /// > versions. Treat as a within-process session token; use
            /// > ``P256K/Schnorr/PublicKey/dataRepresentation`` for persistence.
            public var cache: Data {
                Data(baseKey.cache)
            }

            /// Creates an x-only public key from a validated backing implementation.
            ///
            /// Internal-visibility constructor used by ``P256K/Schnorr/PublicKey/xonly`` and
            /// related accessors; consumers use the public initializer below.
            ///
            /// - Parameter baseKey: A validated `XonlyKeyImplementation`.
            init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Creates an x-only public key from a 32-byte X-coordinate, parity bit, and
            /// optional pre-computed full-pubkey cache.
            ///
            /// Useful when reconstructing from persisted state (e.g. a Taproot output-key
            /// identifier and its parity stored in a wallet database).
            ///
            /// - Parameter data: The 32-byte X coordinate of the x-only public key.
            /// - Parameter keyParity: The Y-coordinate parity as an `Int32`: `0` = even,
            ///   `1` = odd.
            /// - Parameter cache: Optional pre-computed `secp256k1_pubkey` bytes associated
            ///   with the x-only key; pass an empty array to have the backing
            ///   implementation recompute the full pubkey on demand.
            public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32 = 0, cache: [UInt8] = []) {
                self.baseKey = XonlyKeyImplementation(dataRepresentation: data, keyParity: keyParity, cache: cache)
            }

            /// Determines if two x-only keys are equal.
            ///
            /// - Parameters:
            ///   - lhs: The left-hand side private key.
            ///   - rhs: The right-hand side private key.
            /// - Returns: True if the private keys are equal, false otherwise.
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.baseKey.bytes == rhs.baseKey.bytes
            }
        }
    }

#endif
