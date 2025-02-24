//
//  HashDigest.swift
//  GigaBitcoin/secp256k1.swift
//
//  Modifications Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
//
//  NOTICE: THIS FILE HAS BEEN MODIFIED BY GigaBitcoin LLC
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

/// A typealias for the `HashDigest` struct as `SHA256Digest`.
public typealias SHA256Digest = HashDigest

/// A struct representing a hash digest.
public struct HashDigest: Digest {
    let bytes: (UInt64, UInt64, UInt64, UInt64)

    /// Initializes a hash digest from an array of bytes.
    ///
    /// - Parameter output: An array of bytes to create the hash digest.
    public init(_ output: [UInt8]) {
        let first = output[0..<8].withUnsafeBytes { $0.load(as: UInt64.self) }
        let second = output[8..<16].withUnsafeBytes { $0.load(as: UInt64.self) }
        let third = output[16..<24].withUnsafeBytes { $0.load(as: UInt64.self) }
        let forth = output[24..<32].withUnsafeBytes { $0.load(as: UInt64.self) }

        self.bytes = (first, second, third, forth)
    }

    /// The byte count of the hash digest.
    public static var byteCount: Int {
        get { SHA256.digestByteCount }
        set { fatalError("Cannot set SHA256.byteCount") }
    }

    /// Executes a closure while passing an `UnsafeRawBufferPointer`.
    ///
    /// - Parameter body: A closure that takes an `UnsafeRawBufferPointer` as its argument.
    /// - Returns: The value returned from the closure.
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

    /// A string representation of the hash digest.
    public var description: String {
        "SHA256 digest: \(toArray().hexString)"
    }

    /// Hashes the hash digest into the hasher.
    ///
    /// - Parameter hasher: An inout hasher.
    public func hash(into hasher: inout Hasher) {
        withUnsafeBytes { hasher.combine(bytes: $0) }
    }
}

extension HashDigest: Comparable {
    public static func < (lhs: HashDigest, rhs: HashDigest) -> Bool {
        Data(lhs).lexicographicallyPrecedes(Data(rhs))
    }
}
