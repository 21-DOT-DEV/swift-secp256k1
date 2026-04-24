//
//  ECDSA+XonlyKey.swift
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

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing {
    /// The 32-byte x-only form of a secp256k1 ``P256K/Signing/PublicKey``, as defined by
    /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki): the X
    /// coordinate of the public key point with implicit even-Y parity unless ``parity`` is
    /// `true`.
    ///
    /// Conversion uses `secp256k1_xonly_pubkey_from_pubkey` (declared in
    /// [`Vendor/secp256k1/include/secp256k1_extrakeys.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_extrakeys.h)),
    /// which flips the sign of the point when its Y coordinate is odd and records the
    /// original parity so callers can reconstruct the full point later. Useful when pivoting
    /// from ECDSA-era verification into BIP-340 / Taproot workflows without regenerating the
    /// key material.
    ///
    /// ## Topics
    ///
    /// ### Inspection
    /// - ``bytes``
    /// - ``parity``
    ///
    /// ### Construction
    /// - ``init(dataRepresentation:keyParity:)``
    struct XonlyKey: Sendable {
        /// The internal `XonlyKeyImplementation` backing this x-only key.
        ///
        /// Kept `private` — the backing type is an internal convenience over the upstream
        /// `secp256k1_xonly_pubkey` struct; consumers never see or manipulate it directly.
        private let baseKey: XonlyKeyImplementation

        /// The 32-byte X coordinate of this x-only public key.
        ///
        /// Stable across libsecp256k1 versions — safe to persist as a BIP-340-style key
        /// identifier. Pair with ``parity`` if the full `(x, y)` point must be reconstructed
        /// downstream (e.g. for tweak verification).
        public var bytes: [UInt8] {
            baseKey.bytes
        }

        /// The Y-coordinate parity of the underlying secp256k1 public key, as returned by
        /// `secp256k1_xonly_pubkey_from_pubkey`.
        ///
        /// `false` means the Y coordinate is even (the canonical BIP-340 form); `true`
        /// means it is odd (the public key point is the negation of the even-Y point with
        /// the same X coordinate). BIP-340 verifiers operate against the even-Y
        /// representative, so the parity bit is tracked separately and consulted during
        /// Taproot tweak verification.
        public var parity: Bool {
            baseKey.keyParity.boolValue
        }

        /// Creates a ``XonlyKey`` from a validated backing implementation.
        ///
        /// Internal-visibility constructor used by ``P256K/Signing/PublicKey/xonly``;
        /// consumers access x-only keys through that accessor or via the public
        /// initializer below.
        ///
        /// - Parameter baseKey: A validated `XonlyKeyImplementation`.
        init(baseKey: XonlyKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Creates a ``XonlyKey`` from a 32-byte X-coordinate and its Y-coordinate parity.
        ///
        /// Useful when reconstructing an x-only key from a persisted `(bytes, parity)` pair
        /// (e.g. a Taproot output-key identifier stored in a wallet database).
        ///
        /// - Parameter data: The 32-byte X coordinate of the x-only public key.
        /// - Parameter keyParity: The Y-coordinate parity as `Int32`: `0` = even, `1` = odd.
        public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32) {
            self.baseKey = XonlyKeyImplementation(dataRepresentation: data.bytes, keyParity: keyParity)
        }
    }
}
