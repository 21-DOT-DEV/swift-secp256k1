//
//  UInt256.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if Xcode || ENABLE_UINT256

    //===----------------------------------------------------------------------===//

    // MARK: - 256-bit Integer Types

    //===----------------------------------------------------------------------===//

    // A 256-bit unsigned integer backed by two stdlib UInt128 limbs.

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct UInt256 {
        @usableFromInline var _low: Swift.UInt128
        @usableFromInline var _high: Swift.UInt128

        @inlinable public init() {
            self._low = 0
            self._high = 0
        }

        @usableFromInline
        init(_low: Swift.UInt128, _high: Swift.UInt128) {
            self._low = _low
            self._high = _high
        }
    }

    // A 256-bit signed integer backed by two stdlib UInt128/Int128 limbs.

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct Int256 {
        @usableFromInline var _low: Swift.UInt128
        @usableFromInline var _high: Swift.Int128

        @inlinable public init() {
            self._low = 0
            self._high = 0
        }

        @usableFromInline
        init(_low: Swift.UInt128, _high: Swift.Int128) {
            self._low = _low
            self._high = _high
        }
    }

    // MARK: - Bit-pattern conversions

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public extension UInt256 {
        @inlinable
        init(bitPattern source: Int256) {
            self._low = source._low
            self._high = Swift.UInt128(bitPattern: source._high)
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public extension Int256 {
        @inlinable
        init(bitPattern source: UInt256) {
            self._low = source._low
            self._high = Swift.Int128(bitPattern: source._high)
        }
    }

    // MARK: - Sendable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Sendable {}

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Sendable {}

#endif
