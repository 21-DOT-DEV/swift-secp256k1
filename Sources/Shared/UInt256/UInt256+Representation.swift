//
//  UInt256+Representation.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if Xcode || ENABLE_UINT256

    public import Foundation

    // MARK: - Equatable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Equatable {
        @inlinable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs._high == rhs._high && lhs._low == rhs._low
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Equatable {
        @inlinable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs._high == rhs._high && lhs._low == rhs._low
        }
    }

    // MARK: - Comparable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Comparable {
        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs._high != rhs._high ? lhs._high < rhs._high : lhs._low < rhs._low
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Comparable {
        @inlinable
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs._high != rhs._high ? lhs._high < rhs._high : lhs._low < rhs._low
        }
    }

    // MARK: - Hashable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Hashable {
        @inlinable
        public func hash(into hasher: inout Hasher) {
            hasher.combine(_low)
            hasher.combine(_high)
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Hashable {
        @inlinable
        public func hash(into hasher: inout Hasher) {
            hasher.combine(_low)
            hasher.combine(_high)
        }
    }

    // MARK: - CustomStringConvertible / CustomDebugStringConvertible / CustomReflectable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        public var description: String {
            if self == .zero { return "0" }
            var digits = ContiguousArray<UInt8>()
            var value = self
            while value != .zero {
                let (q, r) = (10 as Self).dividingFullWidth((high: .zero, low: value))
                digits.append(UInt8(truncatingIfNeeded: r._low) &+ 48) // '0'
                value = q
            }
            return String(bytes: digits.reversed(), encoding: .ascii)!
        }

        public var debugDescription: String {
            description
        }

        public var customMirror: Mirror {
            Mirror(self, unlabeledChildren: EmptyCollection<Void>())
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        public var description: String {
            _high < 0 ? "-" + magnitude.description : UInt256(bitPattern: self).description
        }

        public var debugDescription: String {
            description
        }

        public var customMirror: Mirror {
            Mirror(self, unlabeledChildren: EmptyCollection<Void>())
        }
    }

    // MARK: - ExpressibleByIntegerLiteral (via StaticBigInt)

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: ExpressibleByIntegerLiteral {
        public typealias IntegerLiteralType = StaticBigInt

        public init(integerLiteral source: StaticBigInt) {
            precondition(
                source.signum() >= 0 && source.bitWidth <= Self.bitWidth + 1,
                "integer overflow: '\(source)' as 'UInt256'"
            )
            _low = Swift.UInt128(source[0]) | (Swift.UInt128(source[1]) << 64)
            _high = Swift.UInt128(source[2]) | (Swift.UInt128(source[3]) << 64)
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: ExpressibleByIntegerLiteral {
        public typealias IntegerLiteralType = StaticBigInt

        public init(integerLiteral source: StaticBigInt) {
            precondition(
                source.bitWidth <= Self.bitWidth,
                "integer overflow: '\(source)' as 'Int256'"
            )
            let fill: Swift.UInt128 = source.signum() < 0 ? ~0 : 0
            _low = Swift.UInt128(source[0]) | (Swift.UInt128(source[1]) << 64)
            let w2 = Swift.UInt128(source[2]) | (Swift.UInt128(source[3]) << 64)
            _high = Swift.Int128(bitPattern: source.bitWidth < Self.bitWidth ? w2 : fill)
        }
    }

    // MARK: - Codable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: Codable {
        public init(from decoder: any Decoder) throws {
            let c = try decoder.singleValueContainer()
            let data = try c.decode(Data.self)
            guard let v = UInt256(rawValue: data) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: c.codingPath,
                    debugDescription: "UInt256 requires exactly 32 bytes, got \(data.count)"
                ))
            }
            self = v
        }

        public func encode(to encoder: any Encoder) throws {
            var c = encoder.singleValueContainer()
            try c.encode(rawValue)
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension Int256: Codable {
        public init(from decoder: any Decoder) throws {
            let u = try UInt256(from: decoder)
            self = Int256(bitPattern: u)
        }

        public func encode(to encoder: any Encoder) throws {
            try UInt256(bitPattern: self).encode(to: encoder)
        }
    }

    // MARK: - RawRepresentable

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    extension UInt256: RawRepresentable {
        public typealias RawValue = Data

        public init?(rawValue data: Data) {
            guard data.count == 32 else { return nil }
            var high: Swift.UInt128 = 0
            var low: Swift.UInt128 = 0
            withUnsafeMutableBytes(of: &high) { ptr in
                data.prefix(16).withUnsafeBytes { ptr.copyMemory(from: $0) }
            }
            withUnsafeMutableBytes(of: &low) { ptr in
                data.suffix(16).withUnsafeBytes { ptr.copyMemory(from: $0) }
            }
            _high = Swift.UInt128(bigEndian: high)
            _low = Swift.UInt128(bigEndian: low)
        }

        public var rawValue: Data {
            var data = Data(count: 32)
            var highBE = _high.bigEndian
            var lowBE = _low.bigEndian
            withUnsafeBytes(of: &highBE) { src in data.replaceSubrange(0..<16, with: src) }
            withUnsafeBytes(of: &lowBE) { src in data.replaceSubrange(16..<32, with: src) }
            return data
        }
    }

#endif
