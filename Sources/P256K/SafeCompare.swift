//
//  SafeCompare.swift
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
#if CRYPTO_IN_SWIFTPM && !CRYPTO_IN_SWIFTPM_FORCE_BUILD_API
    @_exported import CryptoKit
#else
    #if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
        import SwiftSystem
    #else
        #if canImport(FoundationEssentials)
            import FoundationEssentials
        #else
            import Foundation
        #endif
    #endif

    /// A constant-time comparison function for any two contiguous byte
    /// containers.
    ///
    /// Both operands are borrowed through `withUnsafeBytes` and compared in
    /// place — no `[UInt8]` copy ever leaves zeroizing `SecureBytes` storage
    /// (the shape upstream swift-crypto's `openSSLSafeCompare` uses).
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    func safeCompare<LHS: ContiguousBytes, RHS: ContiguousBytes>(_ lhs: LHS, _ rhs: RHS) -> Bool {
        lhs.withUnsafeBytes { lhsPointer in
            rhs.withUnsafeBytes { rhsPointer in
                constantTimeCompare(lhsPointer, rhsPointer)
            }
        }
    }

    /// A straightforward constant-time comparison function for any two collections of bytes.
    ///
    /// Comparison time is equal only for operands of the **same length** — a
    /// length mismatch returns early, so the caller-visible timing channel is
    /// the operand lengths, not their contents (the same contract as upstream
    /// swift-crypto's `constantTimeCompare`).
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    func constantTimeCompare<LHS: Collection, RHS: Collection>(_ lhs: LHS, _ rhs: RHS) -> Bool
        where LHS.Element == UInt8, RHS.Element == UInt8 {
        guard lhs.count == rhs.count else {
            return false
        }

        return zip(lhs, rhs).reduce(into: 0) { $0 |= $1.0 ^ $1.1 } == 0
    }

#endif // Linux or !SwiftPM
