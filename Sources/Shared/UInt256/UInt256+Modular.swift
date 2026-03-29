//
//  UInt256+Modular.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if Xcode || ENABLE_UINT256

    // MARK: - Modular arithmetic

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public extension UInt256 {
        /// Returns `(self + other) % modulus`.
        ///
        /// - Requires: `modulus >= 2`.
        @inlinable
        func addMod(_ other: UInt256, modulus: UInt256) -> UInt256 {
            precondition(modulus >= 2, "Modulus must be ≥ 2")
            let (sum, overflow) = addingReportingOverflow(other)
            if overflow {
                return modulus.dividingFullWidth((high: 1, low: sum)).remainder
            }
            return sum >= modulus ? sum - modulus : sum
        }

        /// Returns `(self * other) % modulus`.
        ///
        /// - Requires: `modulus != 0`, `self < modulus`, `other < modulus`.
        @inlinable
        func mulMod(_ other: UInt256, modulus: UInt256) -> UInt256 {
            precondition(modulus != .zero, "Modulus must be non-zero")
            let (hi, lo) = multipliedFullWidth(by: other)
            return modulus.dividingFullWidth((high: hi, low: lo)).remainder
        }
    }

    // MARK: - Helpers

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256 {
        @inlinable
        func toInt256() -> Int256 {
            Int256(bitPattern: self)
        }
    }

#endif
