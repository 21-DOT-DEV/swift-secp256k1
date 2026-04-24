//
//  Schnorr.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// signatures over secp256k1: sign with ``PrivateKey``, verify against ``XonlyKey``,
        /// using a fixed 64-byte ``SchnorrSignature`` encoding.
        ///
        /// ## Overview
        ///
        /// BIP-340 Schnorr signatures are used by Bitcoin Taproot
        /// ([BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki), activated
        /// at block 709632 in November 2021) and by Nostr for event signing. Compared to ECDSA,
        /// Schnorr signatures are **linear** — they combine additively, which is what makes
        /// MuSig2 aggregation
        /// ([BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)) possible
        /// — and verify against a **32-byte x-only** public key instead of the 33-byte
        /// compressed form ECDSA requires.
        ///
        /// All signing operations call `secp256k1_schnorrsig_sign_custom` (declared in
        /// `Vendor/secp256k1/include/secp256k1_schnorrsig.h`) with the default BIP-340 nonce
        /// function `secp256k1_nonce_function_bip340`. Verification uses
        /// `secp256k1_schnorrsig_verify` against the x-only public key.
        ///
        /// ### Nonce Generation
        ///
        /// BIP-340 uses a deterministic nonce derived from the private key and message hash via
        /// tagged SHA-256 (`BIP0340/nonce`). Unlike ECDSA's
        /// [RFC 6979](https://datatracker.ietf.org/doc/html/rfc6979) nonce, the BIP-340 scheme
        /// also mixes an auxiliary random value if one is provided, which strengthens resistance
        /// to fault-injection attacks on the signing device. The swift-secp256k1 wrapper uses
        /// the upstream default auxiliary randomness drawn from the Swift-side RNG.
        ///
        /// ### X-Only Keys
        ///
        /// Verification uses the 32-byte X-coordinate of the public key rather than the full
        /// 33-byte compressed encoding. BIP-340 defines the "implicit Y" to be the even
        /// Y-coordinate, which saves one byte on the wire and simplifies the verification
        /// equation. See ``XonlyKey`` for conversion to/from the full public-key forms.
        ///
        /// ## Topics
        ///
        /// ### Key Types
        /// - ``PrivateKey``
        /// - ``PublicKey``
        /// - ``XonlyKey``
        /// - ``SecureNonce``
        ///
        /// ### Signing Primitives
        /// - ``Nonce``
        /// - ``SchnorrSignature``
        enum Schnorr {
            /// The fixed byte length of a BIP-340 Schnorr signature: 64 bytes (`R.x || s`).
            ///
            /// The encoding is the concatenation of the 32-byte X-coordinate of the ephemeral
            /// nonce point `R` and the 32-byte scalar `s`. This is a stable wire format; safe
            /// to persist and cross process boundaries.
            ///
            /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
            @inlinable static var signatureByteCount: Int {
                64
            }

            /// The fixed byte length of a BIP-340 x-only public key: 32 bytes (X coordinate only).
            ///
            /// Compare to ``P256K/Format/compressed`` (33 bytes, includes parity prefix) and
            /// ``P256K/Format/uncompressed`` (65 bytes, includes both `(x, y)`). The x-only
            /// form is the canonical Taproot / Nostr identifier and the one BIP-340 verifiers
            /// consume directly.
            ///
            /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
            @inlinable static var xonlyByteCount: Int {
                32
            }

            /// Tuple representation of `SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC`.
            ///
            /// This 4-byte magic value (`0xDA6FB38C`) is written into the upstream
            /// `secp256k1_schnorrsig_extraparams.magic` field to signal that the struct has
            /// been initialized to a known layout. It is used only at initialization time and
            /// has no cryptographic role. Pre-computed as a tuple so the swift-side ABI match
            /// to the upstream C struct is zero-overhead.
            ///
            /// [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L88)
            @inlinable static var magic: (UInt8, UInt8, UInt8, UInt8) {
                (218, 111, 179, 140)
            }
        }
    }

#endif
