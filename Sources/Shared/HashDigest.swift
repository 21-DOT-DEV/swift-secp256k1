//
//  HashDigest.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Modifications Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
//
//  NOTICE: THIS FILE HAS BEEN MODIFIED BY Timechain Software Initiative, Inc.
//  UNDER COMPLIANCE WITH THE APACHE 2.0 LICENSE FROM THE
//  ORIGINAL WORK OF THE COMPANY Apple Inc.
//
//  THE FOLLOWING IS THE COPYRIGHT OF THE ORIGINAL DOCUMENT:
//
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftCrypto open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the SwiftCrypto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of SwiftCrypto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

// MARK: - HashDigest + DigestPrivate

/// A type alias for ``HashDigest`` used as the concrete return type of ``SHA256/hash(data:)`` and ``SHA256/taggedHash(tag:data:)``.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public typealias SHA256Digest = HashDigest

/// 32-byte SHA-256 digest conforming to `Digest` so it can be passed directly to secp256k1 signing and verification APIs (the `signature(for:)` overloads on ``P256K/Signing/PrivateKey`` and ``P256K/Schnorr/PrivateKey`` that take a `Digest`).
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public struct HashDigest: Digest {
    let bytes: (UInt64, UInt64, UInt64, UInt64)

    /// Creates a ``HashDigest`` from a 32-byte array, storing the bytes as four packed `UInt64` limbs.
    ///
    /// - Parameter output: Exactly 32 bytes; behaviour is undefined if `output.count < 32`.
    public init(_ output: [UInt8]) {
        let first = output[0..<8].withUnsafeBytes { $0.load(as: UInt64.self) }
        let second = output[8..<16].withUnsafeBytes { $0.load(as: UInt64.self) }
        let third = output[16..<24].withUnsafeBytes { $0.load(as: UInt64.self) }
        let forth = output[24..<32].withUnsafeBytes { $0.load(as: UInt64.self) }

        self.bytes = (first, second, third, forth)
    }

    /// The number of bytes in a SHA-256 digest: always 32.
    public static var byteCount: Int {
        get { SHA256.digestByteCount }
        set { fatalError("Cannot set SHA256.byteCount") }
    }

    /// Calls `body` with an unsafe pointer to the digest's 32 raw bytes.
    ///
    /// - Parameter body: A closure receiving a bounds-checked `UnsafeRawBufferPointer` of exactly `byteCount` bytes.
    /// - Returns: The value returned by `body`.
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try Swift.withUnsafeBytes(of: bytes) {
            let boundsCheckedPtr = UnsafeRawBufferPointer(
                start: $0.baseAddress,
                count: Self.byteCount
            )
            return try body(boundsCheckedPtr)
        }
    }

    /// Converts the hash digest to an array slice of bytes.
    ///
    /// - Returns: An array slice of bytes.
    private func toArray() -> ArraySlice<UInt8> {
        var array = [UInt8]()
        array.appendByte(bytes.0)
        array.appendByte(bytes.1)
        array.appendByte(bytes.2)
        array.appendByte(bytes.3)
        return array.prefix(upTo: Self.byteCount)
    }

    /// A human-readable hex string representation of the digest, e.g. `"SHA256 digest: aabbcc..."`.
    public var description: String {
        "SHA256 digest: \(toArray().hexString)"
    }

    /// Feeds the digest bytes into a Swift `Hasher` to support `Hashable` conformance.
    ///
    /// - Parameter hasher: The hasher to combine bytes into.
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes { hasher.combine(bytes: $0) }
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension HashDigest: Comparable {
    public static func < (lhs: HashDigest, rhs: HashDigest) -> Bool {
        Data(lhs).lexicographicallyPrecedes(Data(rhs))
    }
}
