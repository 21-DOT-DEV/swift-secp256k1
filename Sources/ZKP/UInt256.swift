//
//  UInt256.swift
//  GigaBitcoin/secp256k1.swift
//
//  Modifications Copyright (c) 2024 GigaBitcoin LLC
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
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// RUN: %target-run-simple-swift(-parse-as-library)
// REQUIRES: executable_test
// REQUIRES: reflection
// UNSUPPORTED: freestanding
// END.
//
//===----------------------------------------------------------------------===//

import Foundation

/// A larger fixed-width integer, stored as a SIMD vector of words.
///
/// FIXME: Not implemented yet.
/// - ``FixedWidthInteger.multipliedFullWidth(by:)``
/// - ``FixedWidthInteger.dividingFullWidth(_:)``

public protocol SIMDWordsInteger: Codable,
    CustomDebugStringConvertible,
    CustomReflectable,
    FixedWidthInteger,
    Sendable
    where
    Magnitude: SIMDWordsInteger,
    Magnitude.Magnitude == Magnitude,
    Magnitude.Stride == Stride,
    Magnitude.Vector == Vector,
    Magnitude.Words == Words,
    Stride: SIMDWordsInteger,
    Stride.Magnitude == Magnitude,
    Stride.Stride == Stride,
    Stride.Vector == Vector,
    Stride.Words == Words {
    associatedtype Vector: Sendable & SIMD<UInt>

    var vector: Vector { get set }

    init(_ vector: Vector)
}

public extension SIMDWordsInteger where Self == Stride {
    /// Creates a new instance with the same memory representation as the given
    /// value.
    ///
    /// - Parameter source: A value of an associated type.

    @inlinable
    init(bitPattern source: Magnitude) {
        self.init(source.vector)
    }
}

public extension SIMDWordsInteger where Self == Magnitude {
    /// Creates a new instance with the same memory representation as the given
    /// value.
    ///
    /// - Parameter source: A value of an associated type.

    @inlinable
    init(bitPattern source: Stride) {
        self.init(source.vector)
    }
}

public extension SIMDWordsInteger {
    /// Creates a new instance from the given integer, if it can be represented
    /// exactly.
    ///
    /// - Parameter source: An immutable arbitrary-precision signed integer.
    @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
    init?(exactly source: StaticBigInt) {
        if source.signum() == 0 {
            self = .zero
        } else {
            if Self.isSigned {
                guard source.bitWidth <= Self.bitWidth else { return nil }
            } else {
                guard source.bitWidth <= Self.bitWidth + 1 else { return nil }
                guard source.signum() >= 0 else { return nil }
            }
            self.init(truncatingIfNeeded: source)
        }
    }

    /// Creates a new instance from the *bit pattern* of the given integer, by
    /// truncating or sign extending its binary representation to fit this type.
    ///
    /// - Parameter source: An immutable arbitrary-precision signed integer.
    @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
    init(truncatingIfNeeded source: StaticBigInt) {
        var vector = Vector.zero
        for index in vector.indices {
            vector[index] = source[index]
        }
        self.init(vector)
    }
}

extension SIMDWordsInteger {
    @inlinable
    var _doubleWidth: (high: Self, low: Magnitude) {
        (high: _isNegative ? ~Self.zero : Self.zero, low: Magnitude(vector))
    }

    @inlinable
    var _isNegative: Bool {
        Self.isSigned && Int(bitPattern: vector[Vector.scalarCount - 1]) < 0
    }

    @inlinable
    var _isNonnegative: Bool {
        !_isNegative
    }

    @inlinable
    var _isNonzero: Bool {
        self != .zero
    }

    @inlinable
    var _isPowerOfTwo: Bool {
        _isNonnegative && nonzeroBitCount == 1
    }

    @inlinable
    var _isZero: Bool {
        self == .zero
    }
}

//===----------------------------------------------------------------------===//

// MARK: - AdditiveArithmetic APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    @inlinable
    static var zero: Self {
        Self(Vector.zero)
    }

    static func + (_ lhs: Self, _ rhs: Self) -> Self {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow else {
            preconditionFailure(
                "arithmetic overflow: '\(lhs)' + '\(rhs)' as '\(Self.self)'"
            )
        }
        return result.partialValue
    }

    static func - (_ lhs: Self, _ rhs: Self) -> Self {
        let result = lhs.subtractingReportingOverflow(rhs)
        guard !result.overflow else {
            preconditionFailure(
                "arithmetic overflow: '\(lhs)' - '\(rhs)' as '\(Self.self)'"
            )
        }
        return result.partialValue
    }
}

//===----------------------------------------------------------------------===//

// MARK: - BinaryInteger APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    init(truncatingIfNeeded source: some BinaryInteger) {
        var vector = Vector(repeating: (source < .zero) ? ~0 : 0)
        for (index, word) in zip(vector.indices, source.words) {
            vector[index] = word
        }
        self.init(vector)
    }

    @inlinable
    var _lowWord: UInt {
        vector[0]
    }

    var trailingZeroBitCount: Int {
        guard _isNonzero else { return Self.bitWidth }
        var result = 0
        for word in words {
            result += word.trailingZeroBitCount
            guard word == 0 else { break }
        }
        return result
    }

    @inlinable
    var words: SIMDWrapper<Vector> {
        SIMDWrapper<Vector>(wrappedValue: vector)
    }

    @inlinable
    func quotientAndRemainder(
        dividingBy rhs: Self
    ) -> (quotient: Self, remainder: Self) {
        rhs.dividingFullWidth(_doubleWidth)
    }

    @inlinable
    func signum() -> Self {
        _isNegative ? -1 : _isZero ? .zero : +1
    }

    static func / (_ lhs: Self, _ rhs: Self) -> Self {
        let result = lhs.dividedReportingOverflow(by: rhs)
        guard !result.overflow else {
            preconditionFailure(
                "arithmetic overflow: '\(lhs)' / '\(rhs)' as '\(Self.self)'"
            )
        }
        return result.partialValue
    }

    @inlinable
    static func /= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs / rhs
    }

    static func % (_ lhs: Self, _ rhs: Self) -> Self {
        let result = lhs.remainderReportingOverflow(dividingBy: rhs)
        guard !result.overflow else {
            preconditionFailure(
                "arithmetic overflow: '\(lhs)' % '\(rhs)' as '\(Self.self)'"
            )
        }
        return result.partialValue
    }

    @inlinable
    static func %= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs % rhs
    }

    @inlinable
    static prefix func ~ (_ rhs: Self) -> Self {
        Self(~rhs.vector)
    }

    @inlinable
    static func & (_ lhs: Self, _ rhs: Self) -> Self {
        Self(lhs.vector & rhs.vector)
    }

    @inlinable
    static func &= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs & rhs
    }

    @inlinable
    static func | (_ lhs: Self, _ rhs: Self) -> Self {
        Self(lhs.vector | rhs.vector)
    }

    @inlinable
    static func |= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs | rhs
    }

    @inlinable
    static func ^ (_ lhs: Self, _ rhs: Self) -> Self {
        Self(lhs.vector ^ rhs.vector)
    }

    @inlinable
    static func ^= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs ^ rhs
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Codable APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let source = try container.decode(String.self)
        guard let target = Self(source, radix: 10) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "'\(source)' as '\(Self.self)'"
            )
        }
        self = target
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(self, radix: 10))
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Comparable APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    static func < (_ lhs: Self, _ rhs: Self) -> Bool {
        if isSigned {
            guard rhs._isNonzero else { return lhs._isNegative }
            guard lhs._isNonzero else { return rhs._isNonnegative }
            guard lhs._isNegative == rhs._isNegative else { return lhs._isNegative }
        } else {
            guard rhs._isNonzero else { return false }
            guard lhs._isNonzero else { return true }
        }
        return lhs.words.reversed().lexicographicallyPrecedes(rhs.words.reversed())
    }
}

//===----------------------------------------------------------------------===//

// MARK: - CustomDebugStringConvertible APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    var debugDescription: String {
        var result = _isNegative ? "-0x" : "+0x"
        result.reserveCapacity(result.count + (Self.bitWidth / 4))
        for word in magnitude.words.reversed() {
            result += String(repeating: "0", count: word.leadingZeroBitCount / 4)
            if word != 0 {
                result += String(word, radix: 16, uppercase: true)
            }
        }
        return result
    }
}

//===----------------------------------------------------------------------===//

// MARK: - CustomReflectable APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    var customMirror: Mirror {
        Mirror(self, unlabeledChildren: EmptyCollection<Void>())
    }
}

//===----------------------------------------------------------------------===//

// MARK: - CustomStringConvertible APIs

//===----------------------------------------------------------------------===//

#if true // FIXME: Requires `quotientAndRemainder(dividingBy: 10)`.

    public extension SIMDWordsInteger {
        var description: String {
            debugDescription
        }
    }
#endif

//===----------------------------------------------------------------------===//

// MARK: - ExpressibleByIntegerLiteral APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
    init(integerLiteral source: StaticBigInt) {
        self = Self(exactly: source) ?? {
            preconditionFailure("integer overflow: '\(source)' as '\(Self.self)'")
        }()
    }
}

//===----------------------------------------------------------------------===//

// MARK: - FixedWidthInteger APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    // FIXME: <https://bugs.swift.org/browse/SR-7648>

    init(_truncatingBits source: UInt) {
        var vector = Vector.zero
        vector[0] = source
        self.init(vector)
    }

    @inlinable
    static var bitWidth: Int {
        Vector.scalarCount * Vector.Scalar.bitWidth
    }

    var byteSwapped: Self {
        Self(Vector(words.reversed().lazy.map { $0.byteSwapped }))
    }

    var leadingZeroBitCount: Int {
        guard _isNonzero else { return Self.bitWidth }
        var result = 0
        for word in words.reversed() {
            result += word.leadingZeroBitCount
            guard word == 0 else { break }
        }
        return result
    }

    @inlinable
    var nonzeroBitCount: Int {
        _isNonzero ? Int(vector.nonzeroBitCount.wrappedSum()) : 0
    }

    func addingReportingOverflow(
        _ rhs: Self
    ) -> (partialValue: Self, overflow: Bool) {
        guard rhs._isNonzero else { return (partialValue: self, overflow: false) }
        guard _isNonzero else { return (partialValue: rhs, overflow: false) }
        @SIMDWrapper var lhs = vector
        @SIMDWrapper var rhs = rhs.vector
        var flag = (false, false)
        let indices: Range<Int> = lhs.indices.dropLast(Self.isSigned ? 1 : 0)
        for index in indices {
            let carry: UInt = (flag.0 || flag.1) ? 1 : 0
            (lhs[index], flag.0) = lhs[index].addingReportingOverflow(carry)
            (lhs[index], flag.1) = lhs[index].addingReportingOverflow(rhs[index])
        }
        if Self.isSigned {
            let carry: Int = (flag.0 || flag.1) ? 1 : 0
            ($lhs._last, flag.0) = $lhs._last.addingReportingOverflow(carry)
            ($lhs._last, flag.1) = $lhs._last.addingReportingOverflow($rhs._last)
        }
        return (partialValue: Self(lhs), overflow: flag.0 != flag.1)
    }

    func subtractingReportingOverflow(
        _ rhs: Self
    ) -> (partialValue: Self, overflow: Bool) {
        guard rhs._isNonzero else { return (partialValue: self, overflow: false) }
        guard self != rhs else { return (partialValue: .zero, overflow: false) }
        @SIMDWrapper var lhs = vector
        @SIMDWrapper var rhs = rhs.vector
        var flag = (false, false)
        let indices: Range<Int> = lhs.indices.dropLast(Self.isSigned ? 1 : 0)
        for index in indices {
            let borrow: UInt = (flag.0 || flag.1) ? 1 : 0
            (lhs[index], flag.0) = lhs[index].subtractingReportingOverflow(borrow)
            (lhs[index], flag.1) = lhs[index].subtractingReportingOverflow(rhs[index])
        }
        if Self.isSigned {
            let borrow: Int = (flag.0 || flag.1) ? 1 : 0
            ($lhs._last, flag.0) = $lhs._last.subtractingReportingOverflow(borrow)
            ($lhs._last, flag.1) = $lhs._last.subtractingReportingOverflow($rhs._last)
        }
        return (partialValue: Self(lhs), overflow: flag.0 != flag.1)
    }

    func multipliedReportingOverflow(
        by rhs: Self
    ) -> (partialValue: Self, overflow: Bool) {
        let (high, low) = multipliedFullWidth(by: rhs)
        let partialValue = Self(low.vector)
        let overflow: Bool
        if high._isZero {
            overflow = partialValue._isNegative
        } else if Self.isSigned, high == ~.zero {
            overflow = partialValue._isNonnegative
        } else {
            overflow = true
        }
        return (partialValue: partialValue, overflow: overflow)
    }

    func dividedReportingOverflow(
        by rhs: Self
    ) -> (partialValue: Self, overflow: Bool) {
        if rhs._isZero {
            return (partialValue: self, overflow: true)
        }
        if Self.isSigned, self == .min, rhs == (-1 as Self) {
            return (partialValue: self, overflow: true)
        }
        let partialValue = rhs.dividingFullWidth(_doubleWidth).quotient
        return (partialValue: partialValue, overflow: false)
    }

    func remainderReportingOverflow(
        dividingBy rhs: Self
    ) -> (partialValue: Self, overflow: Bool) {
        if rhs._isZero {
            return (partialValue: self, overflow: true)
        }
        if Self.isSigned, self == .min, rhs == (-1 as Self) {
            return (partialValue: .zero, overflow: true)
        }
        let partialValue = rhs.dividingFullWidth(_doubleWidth).remainder
        return (partialValue: partialValue, overflow: false)
    }

    func multipliedFullWidth(
        by rhs: Self
    ) -> (high: Self, low: Magnitude) {
        guard _isNonzero, rhs._isNonzero else { return (high: .zero, low: .zero) }
        guard self != (1 as Self) else { return rhs._doubleWidth }
        guard rhs != (1 as Self) else { return _doubleWidth }
        if _isPowerOfTwo || rhs._isPowerOfTwo {
            let (lhs, rhs) = _isPowerOfTwo ? (rhs, self) : (self, rhs)
            let bitShift = rhs.trailingZeroBitCount
            var doubleWidth = (high: lhs, low: Magnitude(lhs.vector))
            doubleWidth.high &>>= (Self.bitWidth - bitShift)
            doubleWidth.low &<<= bitShift
            return doubleWidth
        }
        fatalError(#function) // FIXME: Not implemented yet.
    }

//    func dividingFullWidth(
//        _ lhs: (high: Self, low: Magnitude)
//    ) -> (quotient: Self, remainder: Self) {
//        fatalError(#function) // FIXME: Not implemented yet.
//    }

    static func &<< (_ lhs: Self, _ rhs: Self) -> Self {
        let (quotient, remainder): (Int, Int)
        do {
            assert(Self.bitWidth.nonzeroBitCount == 1)
            let rhs = Int(truncatingIfNeeded: rhs) & (Self.bitWidth &- 1)
            guard rhs != 0 else { return lhs }
            quotient = rhs >> UInt.bitWidth.trailingZeroBitCount
            remainder = rhs & (UInt.bitWidth &- 1)
        }
        @SIMDWrapper var resultX = lhs.vector
        @SIMDWrapper var resultY = (remainder == 0) ? Vector.zero : lhs.vector
        resultX &<<= UInt(remainder)
        resultY &>>= UInt(UInt.bitWidth - remainder)
        $resultX._shiftWords(by: quotient)
        $resultY._shiftWords(by: quotient + 1)
        return Self(resultX ^ resultY)
    }

    @inlinable
    static func &<<= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs &<< rhs
    }

    static func &>> (_ lhs: Self, _ rhs: Self) -> Self {
        let (quotient, remainder): (Int, Int)
        do {
            assert(Self.bitWidth.nonzeroBitCount == 1)
            let rhs = Int(truncatingIfNeeded: rhs) & (Self.bitWidth &- 1)
            guard rhs != 0 else { return lhs }
            quotient = rhs >> UInt.bitWidth.trailingZeroBitCount
            remainder = rhs & (UInt.bitWidth &- 1)
        }
        @SIMDWrapper var resultX = lhs.vector
        @SIMDWrapper var resultY = (remainder == 0) ? Vector.zero : lhs.vector
        resultX &>>= UInt(remainder)
        resultY &<<= UInt(UInt.bitWidth - remainder)
        if lhs._isNegative {
            $resultX._last = lhs.words._last &>> remainder
        }
        $resultX._shiftWords(by: -quotient, newValue: lhs._isNegative ? ~0 : 0)
        $resultY._shiftWords(by: -quotient - 1)
        return Self(resultX ^ resultY)
    }

    @inlinable
    static func &>>= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs &>> rhs
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Hashable APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger {
    @inlinable
    func hash(into hasher: inout Hasher) {
        hasher.combine(vector)
    }

    @inlinable
    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.vector == rhs.vector
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Numeric APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger where Self == Stride {
    @inlinable
    var magnitude: Magnitude {
        Magnitude(bitPattern: _isNegative ? ~self &+ (1 as Self) : self)
    }
}

public extension SIMDWordsInteger {
    static func * (_ lhs: Self, _ rhs: Self) -> Self {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        guard !result.overflow else {
            preconditionFailure(
                "arithmetic overflow: '\(lhs)' * '\(rhs)' as '\(Self.self)'"
            )
        }
        return result.partialValue
    }

    @inlinable
    static func *= (_ lhs: inout Self, _ rhs: Self) {
        lhs = lhs * rhs
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Strideable APIs

//===----------------------------------------------------------------------===//

public extension SIMDWordsInteger where Self == Stride {
    @inlinable
    func advanced(by n: Stride) -> Self {
        self + n
    }

    @inlinable
    func distance(to other: Self) -> Stride {
        other - self
    }
}

public extension SIMDWordsInteger where Self == Magnitude {
    @inlinable
    func advanced(by n: Stride) -> Self {
        n._isNegative ? self - n.magnitude : self + n.magnitude
    }

    @inlinable
    func distance(to other: Self) -> Stride {
        (self > other) ? -Stride(self - other) : Stride(other - self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - SIMDWrapper Type

//===----------------------------------------------------------------------===//

/// A mutable random-access collection, stored as a SIMD vector.

@frozen
@propertyWrapper
public struct SIMDWrapper<Vector: SIMD> {
    public var wrappedValue: Vector

    @inlinable
    public init(wrappedValue: Vector) {
        self.wrappedValue = wrappedValue
    }

    @inlinable
    public var projectedValue: Self {
        get {
            self
        }
        set {
            self = newValue
        }
    }
}

extension SIMDWrapper: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let wrappedValue = try container.decode(Vector.self)
        self.init(wrappedValue: wrappedValue)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension SIMDWrapper: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }

    @inlinable
    public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension SIMDWrapper: MutableCollection, RandomAccessCollection {
    public typealias Element = Vector.Scalar

    public typealias Index = Int

    public typealias Indices = Range<Int>

    @inlinable
    public var indices: Indices {
        wrappedValue.indices
    }

    @inlinable
    public var startIndex: Index {
        indices.lowerBound
    }

    @inlinable
    public var endIndex: Index {
        indices.upperBound
    }

    @inlinable
    public subscript(_ index: Index) -> Element {
        get {
            wrappedValue[index]
        }
        set {
            wrappedValue[index] = newValue
        }
    }
}

extension SIMDWrapper: Sendable where Vector: Sendable {}

private extension SIMDWrapper where Element == UInt {
    var _last: Int {
        get {
            Int(bitPattern: wrappedValue[index(before: endIndex)])
        }
        set {
            wrappedValue[index(before: endIndex)] = UInt(bitPattern: newValue)
        }
    }

    mutating func _shiftWords(by distance: Int, newValue: UInt = 0) {
        let absolute = abs(distance)
        switch distance.signum() {
        case +1:
            self[indices.dropFirst(absolute)] = dropLast(absolute)
            for index in indices.prefix(absolute) {
                self[index] = newValue
            }

        case -1:
            self[indices.dropLast(absolute)] = dropFirst(absolute)
            for index in indices.suffix(absolute) {
                self[index] = newValue
            }

        default:
            return
        }
    }
}

//===----------------------------------------------------------------------===//

// MARK: - 128-bit Integer Types

//===----------------------------------------------------------------------===//

/// A 128-bit signed integer, stored as a SIMD vector of words.

@frozen @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
public struct Int128: SIMDWordsInteger, SignedInteger {
    public typealias Magnitude = UInt128

    public typealias Stride = Self

    #if arch(i386) || arch(arm) || arch(arm64_32) || arch(wasm32) || arch(powerpc)

        public typealias Vector = SIMD4<UInt>
    #elseif arch(x86_64) || arch(arm64) || arch(powerpc64) || arch(powerpc64le) || arch(s390x)

        public typealias Vector = SIMD2<UInt>
    #endif

    public var vector: Vector

    @inlinable
    public init(_ vector: Vector) {
        self.vector = vector
    }
}

/// A 128-bit unsigned integer, stored as a SIMD vector of words.

@frozen @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
public struct UInt128: SIMDWordsInteger, UnsignedInteger {
    public typealias Magnitude = Self

    @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
    public typealias Stride = Int128

    #if arch(i386) || arch(arm) || arch(arm64_32) || arch(wasm32) || arch(powerpc)

        public typealias Vector = SIMD4<UInt>
    #elseif arch(x86_64) || arch(arm64) || arch(powerpc64) || arch(powerpc64le) || arch(s390x)

        public typealias Vector = SIMD2<UInt>
    #endif

    public var vector: Vector

    @inlinable
    public init(_ vector: Vector) {
        self.vector = vector
    }
}

//===----------------------------------------------------------------------===//

// MARK: - 256-bit Integer Types

//===----------------------------------------------------------------------===//

/// A 256-bit signed integer, stored as a SIMD vector of words.

@frozen @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
public struct Int256: SIMDWordsInteger, SignedInteger {
    public typealias Magnitude = UInt256

    public typealias Stride = Self

    #if arch(i386) || arch(arm) || arch(arm64_32) || arch(wasm32) || arch(powerpc)

        public typealias Vector = SIMD8<UInt>
    #elseif arch(x86_64) || arch(arm64) || arch(powerpc64) || arch(powerpc64le) || arch(s390x)

        public typealias Vector = SIMD4<UInt>
    #endif

    public var vector: Vector

    @inlinable
    public init(_ vector: Vector) {
        self.vector = vector
    }
}

/// A 256-bit unsigned integer, stored as a SIMD vector of words.

@frozen @available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
public struct UInt256: SIMDWordsInteger, UnsignedInteger {
    public typealias Magnitude = Self

    public typealias Stride = Int256

    #if arch(i386) || arch(arm) || arch(arm64_32) || arch(wasm32) || arch(powerpc)

        public typealias Vector = SIMD8<UInt>
    #elseif arch(x86_64) || arch(arm64) || arch(powerpc64) || arch(powerpc64le) || arch(s390x)

        public typealias Vector = SIMD4<UInt>
    #endif

    public var vector: Vector

    @inlinable
    public init(_ vector: Vector) {
        self.vector = vector
    }
}

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension UInt256.Vector: Sequence {
    public func makeIterator() -> Iterator {
        Iterator(self)
    }

    public struct Iterator: IteratorProtocol {
        private let vector: UInt256.Vector
        private var index = 0

        init(_ vector: UInt256.Vector) {
            self.vector = vector
        }

        public mutating func next() -> UInt256? {
            guard index < vector.scalarCount else {
                return nil
            }

            let result = vector[index]
            index += 1

            return UInt256(result)
        }
    }
}

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension UInt256: RawRepresentable {
    public typealias RawValue = Data

    public init(rawValue data: Data) {
        let value = data.withUnsafeBytes {
            $0.load(as: UInt256.self)
        }
        self = value.bigEndian
    }

    public var rawValue: Data {
        let hexData = words.reduce(Data(capacity: Self.bitWidth / 8)) { accumulator, word in
            withUnsafeBytes(of: word.bigEndian) { Data($0) } + accumulator
        }

        return hexData
    }
}
