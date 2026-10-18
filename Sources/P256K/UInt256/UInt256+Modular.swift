//
//  UInt256+Modular.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

// Modular arithmetic helpers (`addMod`, `mulMod`) for `UInt256`. See `UInt256` for the
// timing caveat; these helpers are not constant-time and must not hold secret scalars.

#if Xcode || ENABLE_UINT256

    // MARK: - Modular arithmetic

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public extension UInt256 {
        /// Returns `(self + other) % modulus`.
        ///
        /// Uses `addingReportingOverflow` to detect the 257-bit intermediate, then reduces
        /// modulo `modulus` via `dividingFullWidth` when overflow occurs or via a simple
        /// compare-and-subtract when it doesn't.
        ///
        /// - Parameter other: The value to add.
        /// - Parameter modulus: The modulus (must be ≥ 2).
        /// - Returns: `(self + other) mod modulus`.
        /// - Precondition: `modulus >= 2`.
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
        /// Computes the full 512-bit intermediate via `multipliedFullWidth(by:)` and
        /// reduces with a single `dividingFullWidth` call. Assumes both operands are
        /// already reduced modulo `modulus` (`self < modulus` and `other < modulus`) so
        /// the intermediate does not overflow the 512-bit `(high, low)` tuple when
        /// `modulus` is near `2^256`.
        ///
        /// - Parameter other: The value to multiply.
        /// - Parameter modulus: The modulus (must be non-zero).
        /// - Returns: `(self * other) mod modulus`.
        /// - Precondition: `modulus != 0`, `self < modulus`, `other < modulus`.
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
        /// Reinterprets this `UInt256` value as an ``Int256`` with the same bit pattern.
        ///
        /// Internal-visibility convenience used by arithmetic helpers that need a signed
        /// interpretation of the same 256 bits (e.g. `Stride` computations). No data
        /// conversion occurs; see ``UInt256/init(bitPattern:)`` for the equivalent
        /// external API.
        @inlinable
        func toInt256() -> Int256 {
            Int256(bitPattern: self)
        }
    }

#endif
