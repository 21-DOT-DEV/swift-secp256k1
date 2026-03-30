//
//  UInt256+Arithmetic.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if Xcode || ENABLE_UINT256

    // MARK: - BinaryInteger

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: BinaryInteger {
        public typealias Words = _UInt256Words

        @inlinable public static var isSigned: Bool {
            false
        }

        @inlinable public var words: Words {
            Words(self)
        }

        @inlinable public var _lowWord: UInt {
            UInt(truncatingIfNeeded: _low)
        }

        @inlinable
        public var trailingZeroBitCount: Int {
            _low == 0 ? 128 + _high.trailingZeroBitCount : _low.trailingZeroBitCount
        }

        @inlinable
        public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
            let fill: Swift.UInt128 = source < (0 as T) ? ~0 : 0
            let fillWord = UInt(truncatingIfNeeded: fill)
            var iter = source.words.makeIterator()
            let w0 = Swift.UInt128(iter.next() ?? fillWord)
            let w1 = Swift.UInt128(iter.next() ?? fillWord)
            let w2 = Swift.UInt128(iter.next() ?? fillWord)
            let w3 = Swift.UInt128(iter.next() ?? fillWord)
            _low = w0 | (w1 << 64)
            _high = w2 | (w3 << 64)
        }

        @inlinable
        public init<T: BinaryInteger>(_ source: T) {
            precondition(T.isSigned ? source >= 0 : true, "Negative value is not representable")
            self.init(truncatingIfNeeded: source)
        }

        @inlinable
        public static func / (lhs: Self, rhs: Self) -> Self {
            lhs.dividedReportingOverflow(by: rhs).partialValue
        }

        @inlinable
        public static func /= (lhs: inout Self, rhs: Self) {
            lhs = lhs / rhs
        }

        @inlinable
        public static func % (lhs: Self, rhs: Self) -> Self {
            lhs.remainderReportingOverflow(dividingBy: rhs).partialValue
        }

        @inlinable
        public static func %= (lhs: inout Self, rhs: Self) {
            lhs = lhs % rhs
        }

        @inlinable
        public static func & (lhs: Self, rhs: Self) -> Self {
            Self(_low: lhs._low & rhs._low, _high: lhs._high & rhs._high)
        }

        @inlinable public static func &= (lhs: inout Self, rhs: Self) {
            lhs = lhs & rhs
        }

        @inlinable
        public static func | (lhs: Self, rhs: Self) -> Self {
            Self(_low: lhs._low | rhs._low, _high: lhs._high | rhs._high)
        }

        @inlinable public static func |= (lhs: inout Self, rhs: Self) {
            lhs = lhs | rhs
        }

        @inlinable
        public static func ^ (lhs: Self, rhs: Self) -> Self {
            Self(_low: lhs._low ^ rhs._low, _high: lhs._high ^ rhs._high)
        }

        @inlinable public static func ^= (lhs: inout Self, rhs: Self) {
            lhs = lhs ^ rhs
        }

        @inlinable
        public static prefix func ~ (x: Self) -> Self {
            Self(_low: ~x._low, _high: ~x._high)
        }

        @inlinable
        public static func >> <RHS: BinaryInteger>(lhs: Self, rhs: RHS) -> Self {
            lhs &>> Self(truncatingIfNeeded: rhs)
        }

        @inlinable
        public static func >>= <RHS: BinaryInteger>(lhs: inout Self, rhs: RHS) {
            lhs = lhs >> rhs
        }

        @inlinable
        public static func << <RHS: BinaryInteger>(lhs: Self, rhs: RHS) -> Self {
            lhs &<< Self(truncatingIfNeeded: rhs)
        }

        @inlinable
        public static func <<= <RHS: BinaryInteger>(lhs: inout Self, rhs: RHS) {
            lhs = lhs << rhs
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: BinaryInteger {
        public typealias Words = _Int256Words

        @inlinable public static var isSigned: Bool {
            true
        }

        @inlinable public var words: Words {
            Words(self)
        }

        @inlinable public var _lowWord: UInt {
            UInt(truncatingIfNeeded: _low)
        }

        @inlinable
        public var trailingZeroBitCount: Int {
            _low == 0 ? 128 + Swift.UInt128(bitPattern: _high).trailingZeroBitCount : _low.trailingZeroBitCount
        }

        @inlinable
        public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
            let fill: Swift.UInt128 = source < (0 as T) ? ~0 : 0
            let fillInt = UInt(truncatingIfNeeded: fill)
            var iter = source.words.makeIterator()
            let w0 = Swift.UInt128(iter.next() ?? fillInt)
            let w1 = Swift.UInt128(iter.next() ?? fillInt)
            let w2 = Swift.UInt128(iter.next() ?? fillInt)
            let w3 = Swift.UInt128(iter.next() ?? fillInt)
            _low = w0 | (w1 << 64)
            _high = Swift.Int128(bitPattern: w2 | (w3 << 64))
        }

        @inlinable
        public init<T: BinaryInteger>(_ source: T) {
            precondition(
                T.isSigned ? (source >= Self.min && source <= Self.max) : source <= Self.max,
                "Value not representable as Int256"
            )
            self.init(truncatingIfNeeded: source)
        }

        @inlinable
        public static func / (lhs: Self, rhs: Self) -> Self {
            lhs.dividedReportingOverflow(by: rhs).partialValue
        }

        @inlinable public static func /= (lhs: inout Self, rhs: Self) {
            lhs = lhs / rhs
        }

        @inlinable
        public static func % (lhs: Self, rhs: Self) -> Self {
            lhs.remainderReportingOverflow(dividingBy: rhs).partialValue
        }

        @inlinable public static func %= (lhs: inout Self, rhs: Self) {
            lhs = lhs % rhs
        }

        @inlinable
        public static func & (lhs: Self, rhs: Self) -> Self {
            Self(_low: lhs._low & rhs._low, _high: lhs._high & rhs._high)
        }

        @inlinable public static func &= (lhs: inout Self, rhs: Self) {
            lhs = lhs & rhs
        }

        @inlinable
        public static func | (lhs: Self, rhs: Self) -> Self {
            Self(_low: lhs._low | rhs._low, _high: lhs._high | rhs._high)
        }

        @inlinable public static func |= (lhs: inout Self, rhs: Self) {
            lhs = lhs | rhs
        }

        @inlinable
        public static func ^ (lhs: Self, rhs: Self) -> Self {
            Self(_low: lhs._low ^ rhs._low, _high: lhs._high ^ rhs._high)
        }

        @inlinable public static func ^= (lhs: inout Self, rhs: Self) {
            lhs = lhs ^ rhs
        }

        @inlinable
        public static prefix func ~ (x: Self) -> Self {
            Self(_low: ~x._low, _high: ~x._high)
        }

        @inlinable
        public static func >> <RHS: BinaryInteger>(lhs: Self, rhs: RHS) -> Self {
            lhs &>> Self(truncatingIfNeeded: rhs)
        }

        @inlinable
        public static func >>= <RHS: BinaryInteger>(lhs: inout Self, rhs: RHS) {
            lhs = lhs >> rhs
        }

        @inlinable
        public static func << <RHS: BinaryInteger>(lhs: Self, rhs: RHS) -> Self {
            lhs &<< Self(truncatingIfNeeded: rhs)
        }

        @inlinable
        public static func <<= <RHS: BinaryInteger>(lhs: inout Self, rhs: RHS) {
            lhs = lhs << rhs
        }
    }

    // MARK: - Words structs

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public struct _UInt256Words: RandomAccessCollection {
        public typealias Element = UInt
        public typealias Index = Int

        @usableFromInline let _w0, _w1, _w2, _w3: UInt

        @usableFromInline
        init(_ v: UInt256) {
            self._w0 = UInt(truncatingIfNeeded: v._low)
            self._w1 = UInt(truncatingIfNeeded: v._low >> 64)
            self._w2 = UInt(truncatingIfNeeded: v._high)
            self._w3 = UInt(truncatingIfNeeded: v._high >> 64)
        }

        @inlinable public var startIndex: Int {
            0
        }

        @inlinable public var endIndex: Int {
            4
        }

        @inlinable
        public subscript(position: Int) -> UInt {
            switch position {
            case 0: return _w0
            case 1: return _w1
            case 2: return _w2
            default: return _w3
            }
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public struct _Int256Words: RandomAccessCollection {
        public typealias Element = UInt
        public typealias Index = Int

        @usableFromInline let _w0, _w1, _w2, _w3: UInt

        @usableFromInline
        init(_ v: Int256) {
            self._w0 = UInt(truncatingIfNeeded: v._low)
            self._w1 = UInt(truncatingIfNeeded: v._low >> 64)
            self._w2 = UInt(truncatingIfNeeded: v._high)
            self._w3 = UInt(truncatingIfNeeded: v._high >> 64)
        }

        @inlinable public var startIndex: Int {
            0
        }

        @inlinable public var endIndex: Int {
            4
        }

        @inlinable
        public subscript(position: Int) -> UInt {
            switch position {
            case 0: return _w0
            case 1: return _w1
            case 2: return _w2
            default: return _w3
            }
        }
    }

    // MARK: - Numeric

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Numeric {
        public typealias Magnitude = Self

        @inlinable public var magnitude: Self {
            self
        }

        @inlinable
        public static func * (lhs: Self, rhs: Self) -> Self {
            let result = lhs.multipliedReportingOverflow(by: rhs)
            precondition(!result.overflow, "arithmetic overflow: '\(lhs)' * '\(rhs)' as 'UInt256'")
            return result.partialValue
        }

        @inlinable public static func *= (lhs: inout Self, rhs: Self) {
            lhs = lhs * rhs
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Numeric {
        public typealias Magnitude = UInt256

        @inlinable
        public var magnitude: UInt256 {
            if _high >= 0 {
                return UInt256(_low: _low, _high: Swift.UInt128(bitPattern: _high))
            }
            let u = UInt256(_low: _low, _high: Swift.UInt128(bitPattern: _high))
            return ~u &+ 1
        }

        @inlinable
        public static func * (lhs: Self, rhs: Self) -> Self {
            let result = lhs.multipliedReportingOverflow(by: rhs)
            precondition(!result.overflow, "arithmetic overflow: '\(lhs)' * '\(rhs)' as 'Int256'")
            return result.partialValue
        }

        @inlinable public static func *= (lhs: inout Self, rhs: Self) {
            lhs = lhs * rhs
        }
    }

    // MARK: - AdditiveArithmetic

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: AdditiveArithmetic {
        @inlinable public static var zero: Self {
            Self()
        }

        @inlinable
        public static func + (lhs: Self, rhs: Self) -> Self {
            let result = lhs.addingReportingOverflow(rhs)
            precondition(!result.overflow, "arithmetic overflow: '+' as 'UInt256'")
            return result.partialValue
        }

        @inlinable public static func += (lhs: inout Self, rhs: Self) {
            lhs = lhs + rhs
        }

        @inlinable
        public static func - (lhs: Self, rhs: Self) -> Self {
            let result = lhs.subtractingReportingOverflow(rhs)
            precondition(!result.overflow, "arithmetic overflow: '-' as 'UInt256'")
            return result.partialValue
        }

        @inlinable public static func -= (lhs: inout Self, rhs: Self) {
            lhs = lhs - rhs
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: AdditiveArithmetic {
        @inlinable public static var zero: Self {
            Self()
        }

        @inlinable
        public static func + (lhs: Self, rhs: Self) -> Self {
            let result = lhs.addingReportingOverflow(rhs)
            precondition(!result.overflow, "arithmetic overflow: '+' as 'Int256'")
            return result.partialValue
        }

        @inlinable public static func += (lhs: inout Self, rhs: Self) {
            lhs = lhs + rhs
        }

        @inlinable
        public static func - (lhs: Self, rhs: Self) -> Self {
            let result = lhs.subtractingReportingOverflow(rhs)
            precondition(!result.overflow, "arithmetic overflow: '-' as 'Int256'")
            return result.partialValue
        }

        @inlinable public static func -= (lhs: inout Self, rhs: Self) {
            lhs = lhs - rhs
        }
    }

#endif
