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

/// SHA-256 hash function backed by `secp256k1_swift_sha256`, producing 32-byte ``SHA256Digest`` values; also provides BIP-340 tagged hash support via ``taggedHash(tag:data:)`` using `secp256k1_tagged_sha256`.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public enum SHA256 {
    /// The number of bytes in a SHA256 digest.
    @inlinable
    static var digestByteCount: Int {
        32
    }

    /// Hashes `data` with SHA-256 via `secp256k1_swift_sha256` and returns a 32-byte ``SHA256Digest``.
    ///
    /// - Parameter data: The data to hash; no length restriction.
    /// - Returns: A 32-byte ``SHA256Digest``.
    public static func hash<D: DataProtocol>(data: D) -> SHA256Digest {
        let stringData = Array(data)
        var output = [UInt8](repeating: 0, count: Self.digestByteCount)

        secp256k1_swift_sha256(&output, stringData, stringData.count)

        return .init(output)
    }

    /// Computes a BIP-340 tagged hash `SHA256(SHA256(tag) || SHA256(tag) || data)` via `secp256k1_tagged_sha256`, producing a 32-byte ``SHA256Digest``.
    ///
    /// Tagged hashes prevent cross-protocol attacks by domain-separating hashes with an application-specific `tag`.
    /// BIP-340 uses this scheme for Schnorr signature challenges and key tweaks (e.g., tag `"BIP0340/challenge"`).
    ///
    /// - Parameter tag: The domain-separation tag bytes; repeated twice before `data` as specified by BIP-340.
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
