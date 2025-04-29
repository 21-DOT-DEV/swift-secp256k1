//
//  UInt256Tests.swift
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

#if canImport(ZKP)
    @testable import ZKP
#else
    @testable import P256K
#endif

import XCTest

//===----------------------------------------------------------------------===//

// MARK: - SIMDWordsInteger Tests

//===----------------------------------------------------------------------===//

#if canImport(Foundation)
    import class Foundation.JSONDecoder
    import class Foundation.JSONEncoder
#endif

#if canImport(StdlibUnittest)
    import StdlibUnittest

    typealias Base = Any
#else
    import XCTest

    typealias Base = XCTestCase
#endif

// @main
final class SIMDWordsIntegerTests: Base {
    static func main() {
        #if canImport(StdlibUnittest)
            let testCase = SIMDWordsIntegerTests()
            let testSuite = TestSuite("SIMDWordsIntegerTests")
            testSuite.test("Addition", testCase.testAddition)
            testSuite.test("BitCounting", testCase.testBitCounting)
            testSuite.test("BitShifting", testCase.testBitShifting)
            testSuite.test("BitTwiddling", testCase.testBitTwiddling)
            testSuite.test("ByteSwapping", testCase.testByteSwapping)
            testSuite.test("Multiplication", testCase.testMultiplication)
            testSuite.test("Reflection", testCase.testReflection)
            testSuite.test("Semantics", testCase.testSemantics)
            testSuite.test("Subtraction", testCase.testSubtraction)
            testSuite.test("TypeProperties", testCase.testTypeProperties)
            testSuite.test("Words", testCase.testWords)
            runAllTests()
        #endif
    }
}

#if canImport(Foundation) && canImport(StdlibUnittest)
    func checkCodable(_ instances: some Sequence<some Codable & Equatable>) {
        do {
            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            let expected = Array(instances)
            let actual = try decoder.decode(
                type(of: expected),
                from: encoder.encode(expected)
            )
            expectEqual(expected, actual)
        } catch {
            expectUnreachableCatch(error)
        }
    }
#endif

#if !canImport(StdlibUnittest)
    func expectEqual<T: Equatable>(
        _ expected: T,
        _ actual: T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(expected, actual, message(), file: file, line: line)
    }
#endif

#if !canImport(StdlibUnittest)
    func expectEqual<T: Equatable, U: Equatable>(
        _ expected: (T, U),
        _ actual: (T, U),
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(expected.0, actual.0, message(), file: file, line: line)
        XCTAssertEqual(expected.1, actual.1, message(), file: file, line: line)
    }
#endif

//===----------------------------------------------------------------------===//

// MARK: - Addition Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testAddition<T: FixedWidthInteger>(_: T.Type) {
        expectEqual(T.zero, T.zero + T.zero)
        expectEqual(T.min, T.zero + T.min)
        expectEqual(T.min, T.min + T.zero)
        expectEqual(T.max, T.zero + T.max)
        expectEqual(T.max, T.max + T.zero)
        expectEqual(~T.zero, T.min + T.max)
        expectEqual(~T.zero, T.max + T.min)
        expectEqual(T.min, T.max &+ T(1))
        expectEqual(T.min, T(1) &+ T.max)
        if T.isSigned {
            expectEqual(T.max, T.min &+ T(-1))
            expectEqual(T.max, T(-1) &+ T.min)
        }
        if T.bitWidth >= 64 {
            if T.isSigned {
                expectEqual(-2 as T, (-1 as T) + (-1 as T))
                expectEqual(+0 as T, (-1 as T) + (+1 as T))
                expectEqual(+0 as T, (+1 as T) + (-1 as T))
                expectEqual(
                    -0x8000_0000_0000_0000 as T,
                    -0x0123_4567_89AB_CDEF as T +
                        -0x7EDC_BA98_7654_3211 as T
                )
                expectEqual(
                    -0x8000_0000_0000_0000 as T,
                    -0x7EDC_BA98_7654_3211 as T +
                        -0x0123_4567_89AB_CDEF as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF as T,
                    +0x0123_4567_89AB_CDEF as T +
                        +0x7EDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF as T,
                    +0x7EDC_BA98_7654_3210 as T +
                        +0x0123_4567_89AB_CDEF as T
                )
            } else {
                expectEqual(
                    +0xFFFF_FFFF_FFFF_FFFF as T,
                    +0x0123_4567_89AB_CDEF as T +
                        +0xFEDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0xFFFF_FFFF_FFFF_FFFF as T,
                    +0xFEDC_BA98_7654_3210 as T +
                        +0x0123_4567_89AB_CDEF as T
                )
            }
        }
        if T.bitWidth >= 128 {
            if T.isSigned {
                expectEqual(
                    -0x8000_0000_0000_0000_0000_0000_0000_0000 as T,
                    -0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T +
                        -0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3211 as T
                )
                expectEqual(
                    -0x8000_0000_0000_0000_0000_0000_0000_0000 as T,
                    -0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3211 as T +
                        -0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                    +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T +
                        +0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                    +0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T +
                        +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T
                )
            } else {
                expectEqual(
                    +0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                    +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T +
                        +0xFEDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                    +0xFEDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T +
                        +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T
                )
            }
        }
    }

    func testAddition() {
        testAddition(Int64.self)
        testAddition(UInt64.self)
        testAddition(Int128.self)
        testAddition(UInt128.self)
        testAddition(Int256.self)
        testAddition(UInt256.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - BitCounting Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testBitCounting<T: FixedWidthInteger>(_: T.Type) {
        typealias Element = (
            actual: T,
            expected: (
                leadingZeroBitCount: Int,
                nonzeroBitCount: Int,
                trailingZeroBitCount: Int
            )
        )
        lazy var negatives: [Element] = [
            (-0x8000_0000_0000_0000_0000_0000_0000_0000, (0, 1, 127)),
            (-0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, (0, 2, 0)),
            (-0x0000_0000_FEDC_BA98_7654_3210_0000_0000, (0, 61, 36)),
            (-0x0000_0000_0123_4567_89AB_CDEF_0000_0000, (0, 65, 32)),
            (-0x0000_0000_0000_0000_8000_0000_0000_0000, (0, 65, 63)),
            (-0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, (0, 66, 0)),
            (-0x0000_0000_0000_0000_0000_0000_0000_0002, (0, 127, 1)),
            (-0x0000_0000_0000_0000_0000_0000_0000_0001, (0, 128, 0))
        ]
        lazy var positives: [Element] = [
            (+0x0000_0000_0000_0000_0000_0000_0000_0000, (128, 0, 128)),
            (+0x0000_0000_0000_0000_0000_0000_0000_0001, (127, 1, 0)),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFE, (65, 62, 1)),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, (65, 63, 0)),
            (+0x0000_0000_0123_4567_89AB_CDEF_0000_0000, (39, 32, 32)),
            (+0x0000_0000_FEDC_BA98_7654_3210_0000_0000, (32, 32, 36)),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, (1, 126, 1)),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, (1, 127, 0))
        ]
        lazy var extras: [Element] = [
            (+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, (0, 127, 1)),
            (+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, (0, 128, 0))
        ]
        precondition(T.bitWidth == 128)
        let elements = T.isSigned ? negatives + positives : positives + extras
        for (actual, expected) in elements {
            expectEqual(expected.leadingZeroBitCount, actual.leadingZeroBitCount)
            expectEqual(expected.nonzeroBitCount, actual.nonzeroBitCount)
            expectEqual(expected.trailingZeroBitCount, actual.trailingZeroBitCount)
        }
    }

    func testBitCounting() {
        testBitCounting(Int128.self)
        testBitCounting(UInt128.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - BitShifting Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testBitShifting<T: FixedWidthInteger>(_: T.Type) {
        expectEqual(T.min, T.min &<< T.zero)
        expectEqual(T.min, T.min &>> T.zero)
        expectEqual(T.max, T.max &<< T.zero)
        expectEqual(T.max, T.max &>> T.zero)
        expectEqual(T.min, T.min &<< T.bitWidth)
        expectEqual(T.min, T.min &>> T.bitWidth)
        expectEqual(T.max, T.max &<< T.bitWidth)
        expectEqual(T.max, T.max &>> T.bitWidth)
        if T.bitWidth >= 64 {
            do {
                let expected: T = (T.bitWidth == 64)
                    ? +0x000_0000_789A_BCDE_F000_0000
                    : +0x012_3456_789A_BCDE_F000_0000
                var actual: T = +0x000_0000_0123_4567_89AB_CDEF
                actual <<= 28
                expectEqual(expected, actual)
            }
            do {
                let expected: T = +0x0000_0000_1234_5678
                var actual: T = +0x0123_4567_89AB_CDEF
                actual >>= 28
                expectEqual(expected, actual)
            }
            if T.isSigned {
                let expected: T = -0x0000_0000_1234_5679
                var actual: T = -0x0123_4567_89AB_CDEF
                actual >>= 28
                expectEqual(expected, actual)
            }
        }
        if T.bitWidth >= 128 {
            do {
                let expected: T = (T.bitWidth == 128)
                    ? +0x0000_0000_0000_0000_7766_5544_3322_1100_0000_0000_0000_0000
                    : +0x7FEE_DDCC_BBAA_9988_7766_5544_3322_1100_0000_0000_0000_0000
                var actual: T = +0x0000_0000_0000_0000_7FEE_DDCC_BBAA_9988_7766_5544_3322_1100
                actual <<= 64
                expectEqual(expected, actual)
            }
            do {
                let expected: T = (T.bitWidth == 128)
                    ? +0x0_0000_0000_0000_0000_7665_5443_3221_1000_0000_0000_0000_0000
                    : +0x7_FEED_DCCB_BAA9_9887_7665_5443_3221_1000_0000_0000_0000_0000
                var actual: T = +0x0_0000_0000_0000_0000_7FEE_DDCC_BBAA_9988_7766_5544_3322_1100
                actual <<= 68
                expectEqual(expected, actual)
            }
            do {
                let expected: T = +0x0000_0000_0000_0000_7FEE_DDCC_BBAA_9988
                var actual: T = +0x7FEE_DDCC_BBAA_9988_7766_5544_3322_1100
                actual >>= 64
                expectEqual(expected, actual)
            }
            do {
                let expected: T = +0x0000_0000_0000_0000_07FE_EDDC_CBBA_A998
                var actual: T = +0x7FEE_DDCC_BBAA_9988_7766_5544_3322_1100
                actual >>= 68
                expectEqual(expected, actual)
            }
            if T.isSigned {
                let expected: T = -0x0000_0000_0000_0000_07FE_EDDC_CBBA_A999
                var actual: T = -0x7FEE_DDCC_BBAA_9988_7766_5544_3322_1100
                actual >>= 68
                expectEqual(expected, actual)
            }
        }
    }

    func testBitShifting() {
        testBitShifting(Int64.self)
        testBitShifting(UInt64.self)
        testBitShifting(Int128.self)
        testBitShifting(UInt128.self)
        testBitShifting(Int256.self)
        testBitShifting(UInt256.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - BitTwiddling Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testBitTwiddling<T: FixedWidthInteger>(_: T.Type) {
        expectEqual(T.max, ~.min)
        expectEqual(T.min, ~.max)
        expectEqual(T.min, .min & .min)
        expectEqual(T.max, .max & .max)
        expectEqual(T.zero, .min & .max)
        expectEqual(T.zero, .max & .min)
        expectEqual(T.min, .min | .min)
        expectEqual(T.max, .max | .max)
        expectEqual(~T.zero, .min | .max)
        expectEqual(~T.zero, .max | .min)
        expectEqual(T.zero, .min ^ .min)
        expectEqual(T.zero, .max ^ .max)
        expectEqual(~T.zero, .min ^ .max)
        expectEqual(~T.zero, .max ^ .min)
    }

    func testBitTwiddling() {
        testBitTwiddling(Int64.self)
        testBitTwiddling(UInt64.self)
        testBitTwiddling(Int128.self)
        testBitTwiddling(UInt128.self)
        testBitTwiddling(Int256.self)
        testBitTwiddling(UInt256.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - ByteSwapping Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testByteSwapping<T: FixedWidthInteger>(_: T.Type) {
        typealias Element = (lhs: T, rhs: T)
        lazy var negatives: [Element] = [
            (-0x8000_0000_0000_0000_0000_0000_0000_0000, +0x0000_0000_0000_0000_0000_0000_0000_0080),
            (-0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, +0x0100_0000_0000_0000_0000_0000_0000_0080),
            (-0x0000_0000_FEDC_BA98_7654_3210_0000_0000, +0x0000_0000_F0CD_AB89_6745_2301_FFFF_FFFF),
            (-0x0000_0000_0123_4567_89AB_CDEF_0000_0000, +0x0000_0000_1132_5476_98BA_DCFE_FFFF_FFFF),
            (-0x0000_0000_0000_0000_8000_0000_0000_0000, +0x0000_0000_0000_0080_FFFF_FFFF_FFFF_FFFF),
            (-0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, +0x0100_0000_0000_0080_FFFF_FFFF_FFFF_FFFF),
            (-0x0000_0000_0000_0000_0000_0000_0000_0002, -0x0100_0000_0000_0000_0000_0000_0000_0001),
            (-0x0000_0000_0000_0000_0000_0000_0000_0001, -0x0000_0000_0000_0000_0000_0000_0000_0001),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFE, -0x0100_0000_0000_0081_0000_0000_0000_0000),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, -0x0000_0000_0000_0081_0000_0000_0000_0000),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, -0x0100_0000_0000_0000_0000_0000_0000_0081),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, -0x0000_0000_0000_0000_0000_0000_0000_0081)
        ]
        lazy var positives: [Element] = [
            (+0x0000_0000_0000_0000_0000_0000_0000_0000, +0x0000_0000_0000_0000_0000_0000_0000_0000),
            (+0x0000_0000_0000_0000_0000_0000_0000_0001, +0x0100_0000_0000_0000_0000_0000_0000_0000),
            (+0x0000_0000_0123_4567_89AB_CDEF_0000_0000, +0x0000_0000_EFCD_AB89_6745_2301_0000_0000),
            (+0x0000_0000_FEDC_BA98_7654_3210_0000_0000, +0x0000_0000_1032_5476_98BA_DCFE_0000_0000)
        ]
        lazy var extras: [Element] = [
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFE, +0xFEFF_FFFF_FFFF_FF7F_0000_0000_0000_0000),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, +0xFFFF_FFFF_FFFF_FF7F_0000_0000_0000_0000),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, +0xFEFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FF7F),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, +0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FF7F),
            (+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, +0xFEFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF),
            (+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, +0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF)
        ]
        precondition(T.bitWidth == 128)
        let elements = T.isSigned ? negatives + positives : positives + extras
        for (lhs, rhs) in elements {
            expectEqual(lhs, rhs.byteSwapped)
            expectEqual(rhs, lhs.byteSwapped)
            expectEqual(lhs, T(bigEndian: lhs.bigEndian))
            expectEqual(rhs, T(bigEndian: rhs.bigEndian))
            expectEqual(lhs, T(littleEndian: lhs.littleEndian))
            expectEqual(rhs, T(littleEndian: rhs.littleEndian))
        }
    }

    func testByteSwapping() {
        testByteSwapping(Int128.self)
        testByteSwapping(UInt128.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Multiplication Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testMultiplication<T: FixedWidthInteger>(_: T.Type) {
        let identity: T = 1
        do {
            expectEqual(T.zero, T.zero * T.zero)
            expectEqual(T.zero, T.zero * T.min)
            expectEqual(T.zero, T.min * T.zero)
            expectEqual(T.zero, T.zero * T.max)
            expectEqual(T.zero, T.max * T.zero)
            expectEqual(T.zero, T.zero * identity)
            expectEqual(T.zero, identity * T.zero)
        }
        do {
            expectEqual(identity, identity * identity)
            expectEqual(T.min, T.min * identity)
            expectEqual(T.min, identity * T.min)
            expectEqual(T.max, T.max * identity)
            expectEqual(T.max, identity * T.max)
        }
        if T.bitWidth >= 64 {
            if T.isSigned {
                expectEqual(
                    -0x48D1_59E2_6AF3_7BC0 as T,
                    -0x0123_4567_89AB_CDEF as T *
                        +0x0000_0000_0000_0040 as T
                )
                expectEqual(
                    -0x48D1_59E2_6AF3_7BC0 as T,
                    +0x0000_0000_0000_0040 as T *
                        -0x0123_4567_89AB_CDEF as T
                )
                expectEqual(
                    +0x48D1_59E2_6AF3_7BC0 as T,
                    +0x0123_4567_89AB_CDEF as T *
                        +0x0000_0000_0000_0040 as T
                )
                expectEqual(
                    +0x48D1_59E2_6AF3_7BC0 as T,
                    +0x0000_0000_0000_0040 as T *
                        +0x0123_4567_89AB_CDEF as T
                )
            } else {
                expectEqual(
                    +0x91A2_B3C4_D5E6_F780 as T,
                    +0x0123_4567_89AB_CDEF as T *
                        +0x0000_0000_0000_0080 as T
                )
                expectEqual(
                    +0x91A2_B3C4_D5E6_F780 as T,
                    +0x0000_0000_0000_0080 as T *
                        +0x0123_4567_89AB_CDEF as T
                )
            }
        }
        if T.bitWidth == 128 {
            if T.isSigned {
                expectEqual(
                    (
                        high: -0x2000_0000_0000_0000_0000_0000_0000_0000 as T,
                        low: +0x0000_0000_0000_0000_0000_0000_0000_0000 as T.Magnitude
                    ),
                    T.min.multipliedFullWidth(by: +0x4000_0000_0000_0000_0000_0000_0000_0000)
                )
                expectEqual(
                    (
                        high: +0x1FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                        low: +0xC000_0000_0000_0000_0000_0000_0000_0000 as T.Magnitude
                    ),
                    T.max.multipliedFullWidth(by: +0x4000_0000_0000_0000_0000_0000_0000_0000)
                )
            } else {
                expectEqual(
                    (
                        high: +0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                        low: +0x8000_0000_0000_0000_0000_0000_0000_0000 as T.Magnitude
                    ),
                    T.max.multipliedFullWidth(by: +0x8000_0000_0000_0000_0000_0000_0000_0000)
                )
            }
        }
    }

    func testMultiplication() {
        testMultiplication(Int64.self)
        testMultiplication(UInt64.self)
        testMultiplication(Int128.self)
        testMultiplication(UInt128.self)
        testMultiplication(Int256.self)
        testMultiplication(UInt256.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Reflection Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testReflection<T: FixedWidthInteger>(_: T.Type) {
        typealias Element = (actual: T, expected: String)
        lazy var negatives: [Element] = [
            (-0x8000_0000_0000_0000_0000_0000_0000_0000, "-0x80000000000000000000000000000000"),
            (-0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, "-0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            (-0x0000_0000_0123_4567_89AB_CDEF_0000_0000, "-0x000000000123456789ABCDEF00000000"),
            (-0x0000_0000_0000_0000_0000_0000_0000_0002, "-0x00000000000000000000000000000002"),
            (-0x0000_0000_0000_0000_0000_0000_0000_0001, "-0x00000000000000000000000000000001")
        ]
        lazy var positives: [Element] = [
            (+0x0000_0000_0000_0000_0000_0000_0000_0000, "+0x00000000000000000000000000000000"),
            (+0x0000_0000_0000_0000_0000_0000_0000_0001, "+0x00000000000000000000000000000001"),
            (+0x0000_0000_0123_4567_89AB_CDEF_0000_0000, "+0x000000000123456789ABCDEF00000000"),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, "+0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE"),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, "+0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
        ]
        lazy var extras: [Element] = [
            (+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, "+0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE"),
            (+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, "+0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")
        ]
        precondition(T.bitWidth == 128)
        let elements = T.isSigned ? negatives + positives : positives + extras
        for (actual, expected) in elements {
            let expectedOutput = "- \(expected)\n"
            var actualOutput = ""
            dump(actual, to: &actualOutput)
            expectEqual(expectedOutput, actualOutput)
            expectEqual(expected, String(reflecting: actual))
        }
    }

    func testReflection() {
        testReflection(Int128.self)
        testReflection(UInt128.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Semantics Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testSemantics<T: FixedWidthInteger>(_: T.Type) {
        typealias Element = (value: T, distance: T.Stride)
        lazy var negatives: [Element] = [
            (-0x8000_0000_0000_0000_0000_0000_0000_0000, 0x0000_0000_0000_0000_0000_0000_0000_0001),
            (-0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, 0x7FFF_FFFF_0123_4567_89AB_CDEF_FFFF_FFFF),
            (-0x0000_0000_FEDC_BA98_7654_3210_0000_0000, 0x0000_0000_FDB9_7530_ECA8_6421_0000_0000),
            (-0x0000_0000_0123_4567_89AB_CDEF_0000_0000, 0x0000_0000_0123_4567_09AB_CDEF_0000_0000),
            (-0x0000_0000_0000_0000_8000_0000_0000_0000, 0x0000_0000_0000_0000_0000_0000_0000_0001),
            (-0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, 0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFD),
            (-0x0000_0000_0000_0000_0000_0000_0000_0002, 0x0000_0000_0000_0000_0000_0000_0000_0001),
            (-0x0000_0000_0000_0000_0000_0000_0000_0001, 0x0000_0000_0000_0000_0000_0000_0000_0001)
        ]
        lazy var positives: [Element] = [
            (+0x0000_0000_0000_0000_0000_0000_0000_0000, 0x0000_0000_0000_0000_0000_0000_0000_0001),
            (+0x0000_0000_0000_0000_0000_0000_0000_0001, 0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFD),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFE, 0x0000_0000_0000_0000_0000_0000_0000_0001),
            (+0x0000_0000_0000_0000_7FFF_FFFF_FFFF_FFFF, 0x0000_0000_0123_4567_09AB_CDEF_0000_0001),
            (+0x0000_0000_0123_4567_89AB_CDEF_0000_0000, 0x0000_0000_FDB9_7530_ECA8_6421_0000_0000),
            (+0x0000_0000_FEDC_BA98_7654_3210_0000_0000, 0x7FFF_FFFF_0123_4567_89AB_CDEF_FFFF_FFFE),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFE, 0x0000_0000_0000_0000_0000_0000_0000_0001),
            (+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, 0x0000_0000_0000_0000_0000_0000_0000_0000)
        ]
        let elements = T.isSigned ? negatives + positives : positives
        do {
            let sortedValues: [T] = elements.map { $0.value }
            expectEqual(sortedValues, sortedValues.shuffled().sorted())
            #if canImport(Foundation) && canImport(StdlibUnittest)
                // FIXME: checkCodable(sortedValues)
            #endif
            #if canImport(StdlibUnittest)
                checkComparable(sortedValues) { $0 <=> $1 }
                checkHashable(sortedValues) { $0 == $1 }
                // FIXME: checkLosslessStringConvertible(sortedValues)
            #endif
        }
        for index in zip(
            elements.indices.dropLast(),
            elements.indices.dropFirst()
        ) {
            let value: (T, T)
            let distance: (T.Stride, T.Stride)
            (value.0, distance.0) = elements[index.0]
            (value.1, distance.1) = elements[index.1]
            expectEqual(value.0, value.0.advanced(by: .zero))
            expectEqual(value.1, value.1.advanced(by: .zero))
            expectEqual(value.1, value.0.advanced(by: +distance.0))
            expectEqual(value.0, value.1.advanced(by: -distance.0))
            expectEqual(+distance.0, value.0.distance(to: value.1))
            expectEqual(-distance.0, value.1.distance(to: value.0))
        }
        if T.isSigned {
            for (value, _) in negatives {
                expectEqual(-1, value.signum())
            }
        }
        do {
            for (value, _) in positives where value != .zero {
                expectEqual(+1, value.signum())
            }
            expectEqual(T.zero, T.zero.signum())
        }
    }

    func testSemantics() {
        testSemantics(Int128.self)
        testSemantics(UInt128.self)
        testSemantics(Int256.self)
        testSemantics(UInt256.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Subtraction Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testSubtraction<T: FixedWidthInteger>(_: T.Type) {
        expectEqual(T.zero, T.zero - T.zero)
        expectEqual(T.min, T.min - T.zero)
        expectEqual(T.max, T.max - T.zero)
        expectEqual(T.zero, T.min - T.min)
        expectEqual(T.zero, T.max - T.max)
        expectEqual(T.max, T.min &- T(1))
        if T.isSigned {
            expectEqual(T.min, T.max &- T(-1))
        }
        if T.bitWidth >= 64 {
            if T.isSigned {
                expectEqual(+0 as T, (-1 as T) - (-1 as T))
                expectEqual(-2 as T, (-1 as T) - (+1 as T))
                expectEqual(+2 as T, (+1 as T) - (-1 as T))
                expectEqual(
                    -0x8000_0000_0000_0000 as T,
                    -0x0123_4567_89AB_CDEF as T -
                        +0x7EDC_BA98_7654_3211 as T
                )
                expectEqual(
                    -0x8000_0000_0000_0000 as T,
                    -0x7EDC_BA98_7654_3211 as T -
                        +0x0123_4567_89AB_CDEF as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF as T,
                    +0x0123_4567_89AB_CDEF as T -
                        -0x7EDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF as T,
                    +0x7EDC_BA98_7654_3210 as T -
                        -0x0123_4567_89AB_CDEF as T
                )
            } else {
                expectEqual(
                    +0x0123_4567_89AB_CDEF as T,
                    +0xFFFF_FFFF_FFFF_FFFF as T -
                        +0xFEDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0xFEDC_BA98_7654_3210 as T,
                    +0xFFFF_FFFF_FFFF_FFFF as T -
                        +0x0123_4567_89AB_CDEF as T
                )
            }
        }
        if T.bitWidth >= 128 {
            if T.isSigned {
                expectEqual(
                    -0x8000_0000_0000_0000_0000_0000_0000_0000 as T,
                    -0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T -
                        +0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3211 as T
                )
                expectEqual(
                    -0x8000_0000_0000_0000_0000_0000_0000_0000 as T,
                    -0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3211 as T -
                        +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                    +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T -
                        -0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T,
                    +0x7EDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T -
                        -0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T
                )
            } else {
                expectEqual(
                    +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T,
                    +0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T -
                        +0xFEDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T
                )
                expectEqual(
                    +0xFEDC_BA98_7654_3210_FEDC_BA98_7654_3210 as T,
                    +0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF as T -
                        +0x0123_4567_89AB_CDEF_0123_4567_89AB_CDEF as T
                )
            }
        }
    }

    func testSubtraction() {
        testSubtraction(Int64.self)
        testSubtraction(UInt64.self)
        testSubtraction(Int128.self)
        testSubtraction(UInt128.self)
        testSubtraction(Int256.self)
        testSubtraction(UInt256.self)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - TypeProperties Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testTypeProperties() {
        expectEqual(128, Int128.bitWidth)
        expectEqual(128, UInt128.bitWidth)
        expectEqual(256, Int256.bitWidth)
        expectEqual(256, UInt256.bitWidth)
        expectEqual(true, Int128.isSigned)
        expectEqual(false, UInt128.isSigned)
        expectEqual(true, Int256.isSigned)
        expectEqual(false, UInt256.isSigned)
    }
}

//===----------------------------------------------------------------------===//

// MARK: - Words Tests

//===----------------------------------------------------------------------===//

@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
extension SIMDWordsIntegerTests {
    func testWords<T: FixedWidthInteger>(_: T.Type) {
        if T.isSigned {
            expectEqual(true, T.zero.words.allSatisfy { $0 == .min })
            expectEqual(true, (-1 as T).words.allSatisfy { $0 == .max })
            expectEqual(true, T.min.words.dropLast().allSatisfy { $0 == .min })
            expectEqual(true, T.max.words.dropLast().allSatisfy { $0 == .max })
            expectEqual(UInt(bitPattern: .min), T.min.words.last)
            expectEqual(UInt(bitPattern: .max), T.max.words.last)
        } else {
            expectEqual(true, T.min.words.allSatisfy { $0 == .min })
            expectEqual(true, T.max.words.allSatisfy { $0 == .max })
        }
    }

    func testWords() {
        testWords(Int64.self)
        testWords(UInt64.self)
        testWords(Int128.self)
        testWords(UInt128.self)
        testWords(Int256.self)
        testWords(UInt256.self)
        expectEqual(-0x8000_0000_0000_0000_0000_0000_0000_0000, Int128.min)
        expectEqual(+0x7FFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, Int128.max)
        expectEqual(+0x0000_0000_0000_0000_0000_0000_0000_0000, UInt128.min)
        expectEqual(+0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF, UInt128.max)
    }
}
