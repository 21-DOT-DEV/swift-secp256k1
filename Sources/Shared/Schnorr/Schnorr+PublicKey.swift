//
//  Schnorr+PublicKey.swift
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
        /// secp256k1
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// public key in compressed or uncompressed form, from which the x-only key used
        /// for signature verification is derived via the ``xonly`` property.
        ///
        /// ## Overview
        ///
        /// For BIP-340 Schnorr signature verification, use the ``xonly`` property of this
        /// key. The full ``PublicKey`` is provided for contexts that require the complete
        /// curve point, such as key aggregation (``P256K/MuSig/aggregate(_:)``) or
        /// [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
        /// Taproot key-path spending.
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(xonlyKey:)``
        /// - ``init(dataRepresentation:format:)``
        ///
        /// ### Serialized Forms
        /// - ``dataRepresentation``
        /// - ``format``
        /// - ``xonly``
        struct PublicKey {
            /// The internal `PublicKeyImplementation` backing this Schnorr public key.
            ///
            /// Kept `internal` — the backing type wraps the 64-byte upstream
            /// `secp256k1_pubkey` struct plus the serialization format; consumers never see
            /// the raw C handle through the public API.
            let baseKey: PublicKeyImplementation

            /// The serialized public key bytes in the key's ``format``.
            ///
            /// Internal-visibility accessor used by Swift-side Schnorr verify helpers;
            /// external callers use ``dataRepresentation`` for the `Data` form.
            var bytes: [UInt8] {
                baseKey.bytes
            }

            /// The serialization format of this public key: `.compressed` (33 bytes) or
            /// `.uncompressed` (65 bytes).
            ///
            /// Inherited from the `format:` argument at construction time. Both forms
            /// contain the same underlying `(x, y)` point; pick whichever the downstream
            /// wire format expects.
            public var format: P256K.Format {
                baseKey.format
            }

            /// The serialized public key bytes as `Data`, in the key's ``format``.
            ///
            /// Suitable for transmission and persistence. Most Bitcoin/Taproot workflows
            /// consume the x-only form instead — use ``xonly`` in that case.
            public var dataRepresentation: Data {
                baseKey.dataRepresentation
            }

            /// The 32-byte x-only public key (X coordinate only) derived from this key for
            /// use in BIP-340 Schnorr signature verification.
            ///
            /// Computed on every access via `secp256k1_xonly_pubkey_from_pubkey`. The
            /// returned ``XonlyKey`` carries the original Y-parity in ``XonlyKey/parity``
            /// so callers can reconstruct the full point when needed.
            public var xonly: XonlyKey {
                XonlyKey(baseKey: baseKey.xonly)
            }

            /// Creates a public key from a validated backing implementation.
            ///
            /// Internal-visibility constructor used by factory methods that have already
            /// validated the backing implementation; consumers use the public initializers
            /// below.
            ///
            /// - Parameter baseKey: A validated `PublicKeyImplementation`.
            init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Creates a compressed secp256k1 public key from an x-only key by prepending the 0x02 (even-Y) or 0x03 (odd-Y) parity prefix.
            ///
            /// - Parameter xonlyKey: The 32-byte x-only public key to convert.
            public init(xonlyKey: XonlyKey) {
                let key = XonlyKeyImplementation(
                    dataRepresentation: xonlyKey.bytes,
                    keyParity: xonlyKey.parity ? 1 : 0
                )
                self.baseKey = PublicKeyImplementation(xonlyKey: key)
            }

            /// Creates a secp256k1 Schnorr public key from serialized bytes.
            ///
            /// - Parameter data: Serialized public key bytes whose length must match `format.length`.
            /// - Parameter format: The serialization format of `data` (`.compressed` for 33 bytes, `.uncompressed` for 65 bytes).
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if parsing via `secp256k1_ec_pubkey_parse` fails.
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
    }

#endif
