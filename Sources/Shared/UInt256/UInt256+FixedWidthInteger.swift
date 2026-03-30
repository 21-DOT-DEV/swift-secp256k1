//
//  UInt256+FixedWidthInteger.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if Xcode || ENABLE_UINT256

    // MARK: - FixedWidthInteger

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: FixedWidthInteger, UnsignedInteger {
        public typealias Stride = Int256

        @inlinable public static var bitWidth: Int {
            256
        }

        @inlinable public static var max: Self {
            Self(_low: ~0, _high: ~0)
        }

        @inlinable public static var min: Self {
            Self()
        }

        @inlinable
        public init(_truncatingBits word: UInt) {
            _low = Swift.UInt128(word)
            _high = 0
        }

        @inlinable
        public var byteSwapped: Self {
            Self(_low: _high.byteSwapped, _high: _low.byteSwapped)
        }

        @inlinable
        public var leadingZeroBitCount: Int {
            _high == 0 ? 128 + _low.leadingZeroBitCount : _high.leadingZeroBitCount
        }

        @inlinable
        public var nonzeroBitCount: Int {
            _low.nonzeroBitCount + _high.nonzeroBitCount
        }

        @inlinable
        public func addingReportingOverflow(_ rhs: Self) -> (partialValue: Self, overflow: Bool) {
            let (lo, c1) = _low.addingReportingOverflow(rhs._low)
            let carry: Swift.UInt128 = c1 ? 1 : 0
            let (hi1, c2) = _high.addingReportingOverflow(rhs._high)
            let (hi2, c3) = hi1.addingReportingOverflow(carry)
            return (Self(_low: lo, _high: hi2), c2 || c3)
        }

        @inlinable
        public func subtractingReportingOverflow(_ rhs: Self) -> (partialValue: Self, overflow: Bool) {
            let (lo, b1) = _low.subtractingReportingOverflow(rhs._low)
            let borrow: Swift.UInt128 = b1 ? 1 : 0
            let (hi1, b2) = _high.subtractingReportingOverflow(rhs._high)
            let (hi2, b3) = hi1.subtractingReportingOverflow(borrow)
            return (Self(_low: lo, _high: hi2), b2 || b3)
        }

        public func multipliedReportingOverflow(by rhs: Self) -> (partialValue: Self, overflow: Bool) {
            let (high, low) = multipliedFullWidth(by: rhs)
            return (low, high != .zero)
        }

        public func multipliedFullWidth(by rhs: Self) -> (high: Self, low: Self) {
            let aL = _low, aH = _high
            let bL = rhs._low, bH = rhs._high
            let (llH, llL) = aL.multipliedFullWidth(by: bL)
            let (lhH, lhL) = aL.multipliedFullWidth(by: bH)
            let (hlH, hlL) = aH.multipliedFullWidth(by: bL)
            let (hhH, hhL) = aH.multipliedFullWidth(by: bH)
            let (mid1, mc1) = llH.addingReportingOverflow(lhL)
            let (mid2, mc2) = mid1.addingReportingOverflow(hlL)
            let midCarry: Swift.UInt128 = (mc1 ? 1 : 0) + (mc2 ? 1 : 0)
            let (hi1, hc1) = lhH.addingReportingOverflow(hlH)
            let (hi2, hc2) = hi1.addingReportingOverflow(hhL)
            let (hi3, hc3) = hi2.addingReportingOverflow(midCarry)
            let hiCarry: Swift.UInt128 = (hc1 ? 1 : 0) + (hc2 ? 1 : 0) + (hc3 ? 1 : 0)
            let (top, topOF) = hhH.addingReportingOverflow(hiCarry)
            assert(!topOF, "multipliedFullWidth overflow — impossible for (2^256-1)^2")
            return (
                high: Self(_low: hi3, _high: top),
                low: Self(_low: llL, _high: mid2)
            )
        }

        public func dividedReportingOverflow(by rhs: Self) -> (partialValue: Self, overflow: Bool) {
            guard rhs != .zero else { return (self, true) }
            return (rhs.dividingFullWidth((high: .zero, low: self)).quotient, false)
        }

        public func remainderReportingOverflow(dividingBy rhs: Self) -> (partialValue: Self, overflow: Bool) {
            guard rhs != .zero else { return (self, true) }
            return (rhs.dividingFullWidth((high: .zero, low: self)).remainder, false)
        }

        public func dividingFullWidth(_ dividend: (high: Self, low: Self)) -> (quotient: Self, remainder: Self) {
            precondition(self != .zero, "Division by zero")
            precondition(dividend.high < self, "Quotient overflow")

            // Fast path: divisor fits in one UInt128 limb
            if _high == 0 {
                let d = _low
                // Precondition guarantees dividend.high < d (128-bit), so top limb = 0
                let (q1, r1) = d.dividingFullWidth((high: dividend.high._low, low: dividend.low._high))
                let (q0, r0) = d.dividingFullWidth((high: r1, low: dividend.low._low))
                return (Self(_low: q0, _high: q1), Self(_low: r0, _high: 0))
            }

            // General path: binary long division over 256 bits of dividend.low
            var q = Self.zero
            var r = dividend.high
            for i in stride(from: 255, through: 0, by: -1) {
                let bit: Self = (dividend.low >> i) & 1
                let topBit = r._high >> 127 // non-zero if shifting r left would overflow 256 bits
                r = (r << 1) | bit
                if topBit != 0 || r >= self {
                    r &-= self
                    q |= (Self(1) << i)
                }
            }
            return (q, r)
        }

        @inlinable
        public static func &<< (lhs: Self, rhs: Self) -> Self {
            let s = Int(rhs._low) & 255
            guard s != 0 else { return lhs }
            if s < 128 {
                return Self(_low: lhs._low &<< s, _high: (lhs._high &<< s) | (lhs._low &>> (128 - s)))
            }
            if s == 128 { return Self(_low: 0, _high: lhs._low) }
            return Self(_low: 0, _high: lhs._low &<< (s - 128))
        }

        @inlinable public static func &<<= (lhs: inout Self, rhs: Self) {
            lhs = lhs &<< rhs
        }

        @inlinable
        public static func &>> (lhs: Self, rhs: Self) -> Self {
            let s = Int(rhs._low) & 255
            guard s != 0 else { return lhs }
            if s < 128 {
                return Self(_low: (lhs._low &>> s) | (lhs._high &<< (128 - s)), _high: lhs._high &>> s)
            }
            if s == 128 { return Self(_low: lhs._high, _high: 0) }
            return Self(_low: lhs._high &>> (s - 128), _high: 0)
        }

        @inlinable public static func &>>= (lhs: inout Self, rhs: Self) {
            lhs = lhs &>> rhs
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: FixedWidthInteger, SignedInteger {
        public typealias Stride = Self

        @inlinable public static var bitWidth: Int {
            256
        }

        @inlinable public static var max: Self {
            Self(_low: ~0, _high: Swift.Int128.max)
        }

        @inlinable public static var min: Self {
            Self(_low: 0, _high: Swift.Int128.min)
        }

        @inlinable
        public init(_truncatingBits word: UInt) {
            _low = Swift.UInt128(word)
            _high = 0
        }

        @inlinable
        public var byteSwapped: Self {
            Self(_low: Swift.UInt128(bitPattern: _high.byteSwapped), _high: Swift.Int128(bitPattern: _low.byteSwapped))
        }

        @inlinable
        public var leadingZeroBitCount: Int {
            let hi = Swift.UInt128(bitPattern: _high)
            return hi == 0 ? 128 + _low.leadingZeroBitCount : hi.leadingZeroBitCount
        }

        @inlinable
        public var nonzeroBitCount: Int {
            _low.nonzeroBitCount + Swift.UInt128(bitPattern: _high).nonzeroBitCount
        }

        @inlinable
        public func addingReportingOverflow(_ rhs: Self) -> (partialValue: Self, overflow: Bool) {
            let (lo, c1) = _low.addingReportingOverflow(rhs._low)
            let carry: Swift.Int128 = c1 ? 1 : 0
            let (hi1, _) = _high.addingReportingOverflow(rhs._high)
            let (hi2, _) = hi1.addingReportingOverflow(carry)
            let overflow = (_high < 0) == (rhs._high < 0) && (_high < 0) != (hi2 < 0)
            return (Self(_low: lo, _high: hi2), overflow)
        }

        @inlinable
        public func subtractingReportingOverflow(_ rhs: Self) -> (partialValue: Self, overflow: Bool) {
            let (lo, b1) = _low.subtractingReportingOverflow(rhs._low)
            let borrow: Swift.Int128 = b1 ? 1 : 0
            let (hi1, _) = _high.subtractingReportingOverflow(rhs._high)
            let (hi2, _) = hi1.subtractingReportingOverflow(borrow)
            let overflow = (_high < 0) != (rhs._high < 0) && (_high < 0) != (hi2 < 0)
            return (Self(_low: lo, _high: hi2), overflow)
        }

        public func multipliedReportingOverflow(by rhs: Self) -> (partialValue: Self, overflow: Bool) {
            let (high, low) = multipliedFullWidth(by: rhs)
            let signExt: Self = low._high >= (Swift.UInt128(1) << 127) ? -1 : 0
            return (Int256(bitPattern: low), high != signExt)
        }

        public func multipliedFullWidth(by rhs: Self) -> (high: Self, low: Self.Magnitude) {
            let lhsNeg = _high < 0, rhsNeg = rhs._high < 0
            let (highU, lowU) = magnitude.multipliedFullWidth(by: rhs.magnitude)
            var hi = highU, lo = lowU
            if lhsNeg != rhsNeg {
                let (negLo, c) = (~lo).addingReportingOverflow(1 as UInt256)
                let negHi = c ? ~hi &+ 1 : ~hi
                hi = negHi
                lo = negLo
            }
            return (high: Int256(bitPattern: hi), low: lo)
        }

        public func dividedReportingOverflow(by rhs: Self) -> (partialValue: Self, overflow: Bool) {
            guard rhs != .zero else { return (self, true) }
            if self == .min, rhs == (-1 as Self) { return (self, true) }
            return (dividingFullWidth((high: _high < 0 ? -1 : 0, low: magnitude)).quotient, false)
        }

        public func remainderReportingOverflow(dividingBy rhs: Self) -> (partialValue: Self, overflow: Bool) {
            guard rhs != .zero else { return (self, true) }
            if self == .min, rhs == (-1 as Self) { return (.zero, true) }
            return (dividingFullWidth((high: _high < 0 ? -1 : 0, low: magnitude)).remainder, false)
        }

        public func dividingFullWidth(_ dividend: (high: Self, low: Self.Magnitude)) -> (quotient: Self, remainder: Self) {
            precondition(self != .zero, "Division by zero")
            let negSelf = _high < 0
            let negDividend = dividend.high._high < 0
            let absSelf = magnitude
            // Convert signed 512-bit dividend to unsigned magnitude
            // dividend = high * 2^256 + low (high is signed)
            let signedHigh = UInt256(bitPattern: dividend.high)
            let unsignedHigh: UInt256
            let unsignedLow: UInt256
            if negDividend {
                // Negate the 512-bit value: ~(high:low) + 1
                let (negLow, carry) = (~dividend.low).addingReportingOverflow(1)
                unsignedLow = negLow
                unsignedHigh = carry ? (~signedHigh &+ 1) : ~signedHigh
            } else {
                unsignedHigh = signedHigh
                unsignedLow = dividend.low
            }
            let (q, r) = absSelf.dividingFullWidth((high: unsignedHigh, low: unsignedLow))
            let negResult = negSelf != negDividend
            let quotient = negResult ? Int256(bitPattern: ~q &+ 1) : Int256(bitPattern: q)
            let remainder = negDividend ? Int256(bitPattern: ~r &+ 1) : Int256(bitPattern: r)
            return (quotient, remainder)
        }

        @inlinable
        public static func &<< (lhs: Self, rhs: Self) -> Self {
            let s = Int(rhs._low) & 255
            guard s != 0 else { return lhs }
            let lo = lhs._low, hi = lhs._high
            let uHi = Swift.UInt128(bitPattern: hi)
            if s < 128 {
                return Self(_low: lo &<< s, _high: Swift.Int128(bitPattern: (uHi &<< s) | (lo &>> (128 - s))))
            }
            if s == 128 { return Self(_low: 0, _high: Swift.Int128(bitPattern: lo)) }
            return Self(_low: 0, _high: Swift.Int128(bitPattern: lo &<< (s - 128)))
        }

        @inlinable public static func &<<= (lhs: inout Self, rhs: Self) {
            lhs = lhs &<< rhs
        }

        @inlinable
        public static func &>> (lhs: Self, rhs: Self) -> Self {
            let s = Int(rhs._low) & 255
            guard s != 0 else { return lhs }
            let lo = lhs._low, hi = lhs._high
            let uHi = Swift.UInt128(bitPattern: hi)
            let signFill = hi < 0 ? Swift.UInt128.max : 0
            if s < 128 {
                return Self(_low: (lo &>> s) | (uHi &<< (128 - s)), _high: hi &>> s)
            }
            if s == 128 { return Self(_low: uHi, _high: Swift.Int128(bitPattern: signFill)) }
            return Self(_low: uHi &>> (s - 128) | (signFill &<< (128 - (s - 128))), _high: Swift.Int128(bitPattern: signFill))
        }

        @inlinable public static func &>>= (lhs: inout Self, rhs: Self) {
            lhs = lhs &>> rhs
        }
    }

    // MARK: - Strideable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Strideable {
        @inlinable
        public func advanced(by n: Int256) -> UInt256 {
            n._high < 0 ? self - n.magnitude : self + n.magnitude
        }

        @inlinable
        public func distance(to other: UInt256) -> Int256 {
            self > other ? -Int256(bitPattern: self - other) : Int256(bitPattern: other - self)
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Strideable {
        @inlinable
        public func advanced(by n: Int256) -> Int256 {
            self + n
        }

        @inlinable
        public func distance(to other: Int256) -> Int256 {
            other - self
        }
    }

#endif
