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
import libsecp256k1

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
        /// - ``dataRepresentation``
        /// - ``parity``
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:keyParity:)``
        struct XonlyKey: Equatable {
            /// The internal `XonlyKeyImplementation` backing this x-only key.
            ///
            /// Kept `private` — the backing type is an internal convenience over the
            /// upstream `secp256k1_xonly_pubkey` struct; consumers never see or manipulate
            /// it directly.
            private let baseKey: XonlyKeyImplementation

            /// The 32-byte X coordinate of this x-only public key as `Data`.
            ///
            /// Stable across libsecp256k1 versions — safe to persist as a BIP-340-style
            /// key identifier. Pair with ``parity`` if the full `(x, y)` point must be
            /// reconstructed downstream (e.g. for Taproot tweak verification).
            public var dataRepresentation: Data {
                baseKey.dataRepresentation
            }

            /// Deprecated alias for ``dataRepresentation`` — renamed to match the
            /// library-wide `dataRepresentation: Data` convention.
            @available(*, deprecated, renamed: "dataRepresentation")
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

            /// The 197-byte `secp256k1_musig_keyagg_cache` associated with this x-only
            /// key when it was produced by MuSig key aggregation; empty otherwise.
            ///
            /// Internal-visibility: these bytes are the opaque upstream
            /// `secp256k1_musig_keyagg_cache` struct, which upstream deliberately ships
            /// with no serialization or parsing functions — not a stable format across
            /// libsecp256k1 versions. Read in-module by `Schnorr.PublicKey.init(xonlyKey:)`
            /// when propagating session state; the public surface never hands it out.
            var cache: Data {
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

            /// Creates an x-only public key from a 32-byte X-coordinate and its
            /// Y-coordinate parity.
            ///
            /// Useful when reconstructing from persisted state (e.g. a Taproot output-key
            /// identifier and its parity stored in a wallet database). A key built this
            /// way carries no MuSig session state — it verifies signatures but cannot
            /// rejoin a signing session; re-run ``P256K/MuSig/aggregate(_:)`` on the
            /// participant public keys to resume one.
            ///
            /// - Parameter data: The 32-byte X coordinate of the x-only public key.
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
