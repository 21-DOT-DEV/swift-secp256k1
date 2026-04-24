//
//  P256K.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
#if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
    import SwiftSystem
#else
    #if canImport(FoundationEssentials)
        import FoundationEssentials
    #else
        import Foundation
    #endif
#endif

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// secp256k1 elliptic curve namespace providing ECDSA signing, Schnorr signatures
/// ([BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)),
/// MuSig2 multi-signatures, ECDH key agreement, and key recovery.
///
/// ## Overview
///
/// `P256K` is the top-level Swift namespace for cryptographic operations on the secp256k1 elliptic
/// curve, which is used in Bitcoin, Lightning Network, and Nostr. The namespace enum itself holds
/// no state; it exists to group cryptographic sub-types (``Signing``, ``Schnorr``, ``MuSig``,
/// ``KeyAgreement``, ``Recovery``) under a single import-friendly prefix that matches the curve
/// name used throughout the Bitcoin ecosystem.
///
/// Every operation requires a secp256k1 context managed by ``P256K/Context``. The library provides
/// a shared, pre-randomized instance via ``P256K/Context/rawRepresentation`` that is suitable for
/// all standard operations; applications do not need to create or manage contexts directly unless
/// they have unusual side-channel or multi-threading requirements.
///
/// ### Side-Channel Protection
///
/// Context randomization seeds a blinding factor applied to base-point multiplications during
/// ECDSA / Schnorr signing and public-key derivation, mitigating timing and power-analysis
/// attacks. ECDH (``KeyAgreement``) uses a different primitive (variable-point multiplication)
/// and does **not** benefit from context blinding — consumers needing side-channel-hardened
/// ECDH should perform it on an air-gapped device or with platform-specific mitigations.
///
/// ### Concurrency
///
/// `P256K` conforms to `Sendable`. The shared context is thread-safe for all const-qualified
/// upstream functions, which covers every public API in this library. No locking is required.
///
/// ## Topics
///
/// ### Sub-Namespaces
///
/// - ``P256K/Signing``
/// - ``P256K/Schnorr``
/// - ``P256K/MuSig``
/// - ``P256K/KeyAgreement``
/// - ``P256K/Recovery``
/// - ``P256K/Context``
///
/// ### Serialization
///
/// - ``P256K/Format``
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public enum P256K: Sendable {}

/// Serialization format selection for secp256k1 public key operations.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// Compressed (33-byte) and uncompressed (65-byte) serialization formats for secp256k1
    /// public keys, passed as flags to `secp256k1_ec_pubkey_serialize`.
    ///
    /// ## Overview
    ///
    /// Use ``compressed`` for standard secp256k1 key storage and transmission in Bitcoin and
    /// Nostr contexts — this has been the default since Bitcoin Core 0.6 (2012) and saves
    /// 32 bytes per key on the wire. Use ``uncompressed`` when interoperating with systems
    /// that require the full `(x, y)` curve point, including legacy Bitcoin addresses, some
    /// OpenSSL wire formats, and non-Bitcoin ECDSA consumers that have not adopted the
    /// point-compression optimization.
    ///
    /// Schnorr / BIP-340 / Taproot workflows use a third representation (x-only, 32 bytes)
    /// which is modeled separately via ``Schnorr/XonlyKey`` and is **not** a `Format` case.
    ///
    /// ## Topics
    ///
    /// ### Cases
    /// - ``compressed``
    /// - ``uncompressed``
    ///
    /// ### Serialization Details
    /// - ``length``
    /// - ``rawValue``
    enum Format: UInt32, Sendable {
        /// 33-byte secp256k1 public key: a 1-byte parity prefix (`0x02` for even Y, `0x03` for
        /// odd Y) followed by the 32-byte X coordinate.
        ///
        /// Default format in `P256K` and the Bitcoin ecosystem at large. Equivalent to the
        /// upstream `SECP256K1_EC_COMPRESSED` flag (`1 << 1 | 1 << 8`). Safe for persistence
        /// and cross-process transmission.
        case compressed

        /// 65-byte secp256k1 public key: a `0x04` prefix byte followed by the full 32-byte X
        /// coordinate and 32-byte Y coordinate.
        ///
        /// Equivalent to the upstream `SECP256K1_EC_UNCOMPRESSED` flag (`1 << 1`). Used only
        /// when interoperating with systems that cannot (or will not) perform the Y-recovery
        /// step required by compressed keys. Consider migrating such systems to ``compressed``
        /// where possible — the Y coordinate can always be recovered from X and parity.
        case uncompressed

        /// The serialized byte length of the public key: 33 bytes for ``compressed``, 65 bytes
        /// for ``uncompressed``.
        ///
        /// Pre-computed from the 32-byte curve-coordinate dimension so that buffer sizing
        /// downstream does not depend on hard-coded magic numbers.
        ///
        /// - Returns: `33` for ``compressed``, `65` for ``uncompressed``.
        public var length: Int {
            switch self {
            case .compressed: return P256K.ByteLength.dimension + 1
            case .uncompressed: return 2 * P256K.ByteLength.dimension + 1
            }
        }

        /// The `secp256k1_ec_pubkey_serialize` format flag: `SECP256K1_EC_COMPRESSED` for
        /// ``compressed``, `SECP256K1_EC_UNCOMPRESSED` for ``uncompressed``.
        ///
        /// Exposed as the `RawValue` of the enum so the flag can be passed directly into the
        /// upstream C API without additional translation. The numeric values match the
        /// upstream `#define` pattern exactly.
        ///
        /// - Returns: The `UInt32` flag the upstream C serialization helpers expect.
        public var rawValue: UInt32 {
            let value: Int32

            switch self {
            case .compressed: value = SECP256K1_EC_COMPRESSED
            case .uncompressed: value = SECP256K1_EC_UNCOMPRESSED
            }

            return UInt32(value)
        }
    }
}

/// Internal byte length constants for secp256k1 key and signature data structures.
///
/// These constants exist to avoid scattered `32` / `33` / `64` / `65` magic numbers through the
/// Swift API layer and to make the upstream-C byte-layout contract self-documenting at the
/// call site. All values are fixed by the secp256k1 curve (256-bit prime field) and the BIP-340
/// / libsecp256k1 serialization formats; they do not depend on runtime configuration.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K {
    /// Byte length constants for secp256k1 keys, coordinates, and signatures.
    ///
    /// Kept `@usableFromInline` so each constant can be inlined into public `@inlinable` sites
    /// without forcing the entire namespace to be `public`.
    @usableFromInline
    enum ByteLength {
        /// Number of bytes in one coordinate dimension of the secp256k1 elliptic curve (32).
        ///
        /// Equal to `ceil(log2(p) / 8)` where `p` is the secp256k1 field prime
        /// (`2^256 - 2^32 - 977`). Multiplied by 2 for uncompressed point encodings; used as
        /// the base unit for every other length constant here.
        @inlinable
        static var dimension: Int {
            32
        }

        /// Number of bytes in a secp256k1 private key (32).
        ///
        /// A private key is a scalar in `[1, n-1]` where `n` is the curve order; 32 bytes is
        /// sufficient to represent any valid scalar. The upstream C API refuses key bytes that
        /// encode `0` or a value `>= n` via `secp256k1_ec_seckey_verify`.
        @inlinable
        static var privateKey: Int {
            32
        }

        /// Number of bytes in a secp256k1 ECDSA or Schnorr signature (64).
        ///
        /// Used for the compact / BIP-340 encodings. DER-encoded ECDSA signatures are
        /// variable-length (~70 bytes typical) and are handled separately by the
        /// ``Signing/ECDSASignature/derRepresentation`` helper.
        @inlinable
        static var signature: Int {
            64
        }

        /// Size in bytes of the opaque `secp256k1_musig_partial_sig` in-memory struct (36).
        ///
        /// This is the struct size used for stack / heap allocation when holding a partial
        /// signature in memory; see `Vendor/secp256k1-zkp/include/secp256k1_musig.h` where
        /// `secp256k1_musig_partial_sig` is declared as `unsigned char data[36]`.
        ///
        /// > Important: The 36-byte struct is **opaque**; callers must not inspect or persist
        /// > its raw bytes. The wire-format serialization of a partial signature is 32 bytes,
        /// > produced by `secp256k1_musig_partial_sig_serialize(out32, ...)` and consumed by
        /// > `secp256k1_musig_partial_sig_parse(..., in32)`.
        @inlinable
        static var partialSignature: Int {
            36
        }

        /// Number of bytes in an uncompressed secp256k1 public key (65).
        ///
        /// The 1-byte `0x04` prefix plus two 32-byte coordinates. Pre-computed so the
        /// upstream `secp256k1_ec_pubkey_serialize` buffer can be sized with a single constant
        /// rather than the arithmetic `2 * dimension + 1`.
        @inlinable
        static var uncompressedPublicKey: Int {
            65
        }
    }
}
