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

/// secp256k1 elliptic curve namespace providing ECDSA signing, Schnorr signatures (BIP-340), MuSig2 multi-signatures, ECDH key agreement, and key recovery.
///
/// `P256K` is the top-level Swift namespace for cryptographic operations on the secp256k1 elliptic
/// curve, which is used in Bitcoin, Lightning Network, and Nostr. Every operation requires a
/// secp256k1 context managed by ``P256K/Context``. The library provides a shared, pre-randomized
/// instance via ``P256K/Context/rawRepresentation`` that is suitable for all standard operations.
///
/// ## Submodules
///
/// - ``P256K/Signing``: ECDSA signing and verification. Signatures are normalized to lower-S form,
///   the only form accepted by `secp256k1_ecdsa_verify`.
/// - ``P256K/Schnorr``: BIP-340 Schnorr signatures. Verification uses 32-byte x-only public keys
///   that encode only the X coordinate of the public key point.
/// - ``P256K/MuSig``: BIP-327 MuSig2 multi-signatures. Multiple independent signers produce a
///   single Schnorr signature over an aggregated public key without a trusted dealer.
/// - ``P256K/KeyAgreement``: ECDH key agreement via `secp256k1_ecdh`. Context randomization does
///   **not** provide side-channel protection for ECDH; it uses a different kind of point
///   multiplication than ECDSA or Schnorr signing.
/// - ``P256K/Recovery``: ECDSA recoverable signatures. A recovered public key is a candidate key
///   consistent with the signature and message digest — it is not proof that the signature is valid.
/// - ``P256K/Context``: Context lifecycle and side-channel protection. Use
///   ``P256K/Context/rawRepresentation`` for all standard operations.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public enum P256K: Sendable {}

/// Serialization format selection for secp256k1 public key operations.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// Compressed (33-byte) and uncompressed (65-byte) serialization formats for secp256k1 public keys, passed as flags to `secp256k1_ec_pubkey_serialize`.
    ///
    /// Use `.compressed` for standard secp256k1 key storage and transmission in Bitcoin and Nostr
    /// contexts. Use `.uncompressed` when interoperating with systems that require the full curve
    /// point, including both X and Y coordinates.
    enum Format: UInt32, Sendable {
        /// 33-byte secp256k1 public key: a 1-byte parity prefix (0x02 for even Y, 0x03 for odd Y) followed by the 32-byte X coordinate.
        case compressed
        /// 65-byte secp256k1 public key: a 0x04 prefix byte followed by the full 32-byte X coordinate and 32-byte Y coordinate.
        case uncompressed

        /// The serialized byte length of the public key: 33 bytes for `.compressed`, 65 bytes for `.uncompressed`.
        public var length: Int {
            switch self {
            case .compressed: return P256K.ByteLength.dimension + 1
            case .uncompressed: return 2 * P256K.ByteLength.dimension + 1
            }
        }

        /// The `secp256k1_ec_pubkey_serialize` format flag: `SECP256K1_EC_COMPRESSED` for `.compressed`, `SECP256K1_EC_UNCOMPRESSED` for `.uncompressed`.
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
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K {
    /// Byte length constants for secp256k1 keys, coordinates, and signatures.
    @usableFromInline
    enum ByteLength {
        /// Number of bytes in one coordinate dimension of the secp256k1 elliptic curve (32).
        @inlinable
        static var dimension: Int {
            32
        }

        /// Number of bytes in a secp256k1 private key (32).
        @inlinable
        static var privateKey: Int {
            32
        }

        /// Number of bytes in a secp256k1 ECDSA or Schnorr signature (64).
        @inlinable
        static var signature: Int {
            64
        }

        /// Number of bytes in a MuSig2 partial signature (36).
        @inlinable
        static var partialSignature: Int {
            36
        }

        @inlinable
        static var uncompressedPublicKey: Int {
            65
        }
    }
}
