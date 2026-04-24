//
//  SHA256.swift
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

/// SHA-256 hash function
/// ([RFC 6234](https://datatracker.ietf.org/doc/html/rfc6234))
/// backed by the `secp256k1_swift_sha256` shim
/// ([`Sources/libsecp256k1/src/Utility.c`](https://github.com/21-DOT-DEV/swift-secp256k1/blob/main/Sources/libsecp256k1/src/Utility.c)),
/// producing 32-byte ``SHA256Digest`` values; also provides BIP-340 tagged-hash support via
/// ``taggedHash(tag:data:)`` using upstream `secp256k1_tagged_sha256`.
///
/// ## Overview
///
/// Re-exported from libsecp256k1's internal SHA-256 implementation rather than linking a
/// separate hash library — this keeps the cryptographic dependency surface to a single
/// audited component. The same implementation backs upstream signing and verification,
/// so hashes produced here are byte-for-byte identical to the ones consumed by
/// `secp256k1_schnorrsig_sign_custom`, `secp256k1_ecdsa_sign`, etc.
///
/// ## Topics
///
/// ### Hashing
/// - ``hash(data:)``
/// - ``taggedHash(tag:data:)``
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public enum SHA256 {
    /// The number of bytes in a SHA-256 digest (32).
    ///
    /// Fixed by the SHA-256 specification ([RFC 6234](https://datatracker.ietf.org/doc/html/rfc6234)):
    /// the hash produces a 256-bit (32-byte) output regardless of input length. Used to
    /// size output buffers for the upstream C helpers.
    @inlinable
    static var digestByteCount: Int {
        32
    }

    /// Hashes `data` with SHA-256 via the `secp256k1_swift_sha256` shim and returns a
    /// 32-byte ``SHA256Digest``.
    ///
    /// The shim wraps the internal libsecp256k1 SHA-256 implementation so the Swift layer
    /// and the C layer share a single implementation for all hashing operations that feed
    /// into signing / verification.
    ///
    /// - Parameter data: The data to hash; no length restriction.
    /// - Returns: A 32-byte ``SHA256Digest``.
    public static func hash<D: DataProtocol>(data: D) -> SHA256Digest {
        let stringData = Array(data)
        var output = [UInt8](repeating: 0, count: Self.digestByteCount)

        secp256k1_swift_sha256(&output, stringData, stringData.count)

        return .init(output)
    }

    /// Computes a BIP-340 tagged hash `SHA256(SHA256(tag) || SHA256(tag) || data)` via
    /// upstream `secp256k1_tagged_sha256`, producing a 32-byte ``SHA256Digest``.
    ///
    /// Tagged hashes prevent cross-protocol attacks by domain-separating hashes with an
    /// application-specific `tag`. The construction is defined in
    /// [BIP-340 § Design](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#design)
    /// and reused throughout the Bitcoin Taproot stack:
    ///
    /// - `"BIP0340/challenge"` for the Schnorr signing challenge
    /// - `"BIP0340/nonce"` for BIP-340 nonce derivation
    /// - `"BIP0340/aux"` for auxiliary-randomness mixing
    /// - `"TapLeaf"`, `"TapBranch"`, `"TapTweak"`, `"TapSighash"` for
    ///   [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) Taproot
    ///
    /// Because the upstream SHA-256 implementation is shared between this Swift surface and
    /// libsecp256k1's internal signing / verification code, the tag-hash output here is
    /// byte-for-byte identical to what a libsecp256k1 signer would compute internally for
    /// the same `(tag, data)` pair.
    ///
    /// - Parameter tag: The domain-separation tag bytes; repeated twice before `data` as
    ///   specified by BIP-340.
    /// - Parameter data: The message bytes to hash after the two tag hashes.
    /// - Returns: A 32-byte ``SHA256Digest``.
    public static func taggedHash<D: DataProtocol>(tag: D, data: D) -> SHA256Digest {
        let context = P256K.Context.rawRepresentation
        let tagBytes = Array(tag)
        let messageBytes = Array(data)
        var output = [UInt8](repeating: 0, count: Self.digestByteCount)

        guard secp256k1_tagged_sha256(
            context,
            &output,
            tagBytes,
            tagBytes.count,
            messageBytes,
            messageBytes.count
        ).boolValue else {
            fatalError("secp256k1_tagged_sha256 failed — library bug")
        }

        return .init(output)
    }
}
