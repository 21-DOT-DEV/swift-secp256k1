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

    /// A 256-bit unsigned integer backed by two `UInt128` limbs, conforming to
    /// `FixedWidthInteger`, `BinaryInteger`, and `UnsignedInteger`; used for 256-bit field
    /// arithmetic on the secp256k1 curve.
    ///
    /// ## Overview
    ///
    /// `UInt256` is the natural Swift representation for a secp256k1 private key scalar or
    /// field element: both fit in exactly 32 bytes, and both require integer arithmetic
    /// modulo the curve order `n` or field prime `p`. The implementation uses two
    /// `Swift.UInt128`
    /// limbs (low and high) rather than a byte array so that the compiler can emit native
    /// 128-bit operations on platforms that support them (ARM64 `add`/`adc` pairs on Apple
    /// Silicon; LLVM-synthesized 128-bit intrinsics on Intel).
    ///
    /// > Important: **This type is not a cryptographic scalar class.** It provides generic
    /// > integer arithmetic. Operations are not constant-time with respect to operand
    /// > values and must not be used to hold secret scalars in contexts where timing
    /// > leakage matters. For secret scalar arithmetic, use the upstream libsecp256k1 APIs
    /// > that operate on `secp256k1_scalar` / `secp256k1_fe` in constant time.
    ///
    /// The type is gated behind the `UInt256` trait (or `Xcode` build), requiring Swift 6.1
    /// with Swift's native `UInt128` type (macOS 15, iOS 18, etc.).
    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct UInt256 {
        /// The low 128 bits of the 256-bit value.
        ///
        /// Internal-visibility (`@usableFromInline`) so `@inlinable` arithmetic in
        /// sibling files can access the limbs directly without forcing a widening of the
        /// public API surface.
        @usableFromInline var _low: Swift.UInt128

        /// The high 128 bits of the 256-bit value.
        ///
        /// Internal-visibility (`@usableFromInline`) so `@inlinable` arithmetic can reach
        /// the limb directly. Combined with ``_low`` yields `value = _high * 2^128 + _low`.
        @usableFromInline var _high: Swift.UInt128

        /// Creates a `UInt256` with the value `0`.
        @inlinable public init() {
            self._low = 0
            self._high = 0
        }

        /// Creates a `UInt256` from raw low and high `UInt128` limbs.
        ///
        /// Internal-visibility constructor used by arithmetic helpers that compute the
        /// limbs directly; consumers build values via the public literal / integer
        /// initializers declared in `UInt256+FixedWidthInteger.swift`.
        ///
        /// - Parameter _low: The low 128 bits.
        /// - Parameter _high: The high 128 bits; the final value is `_high * 2^128 + _low`.
        @usableFromInline
        init(_low: Swift.UInt128, _high: Swift.UInt128) {
            self._low = _low
            self._high = _high
        }
    }

    /// A 256-bit signed integer backed by a `UInt128` low limb and an `Int128` high limb,
    /// conforming to `FixedWidthInteger`, `BinaryInteger`, and `SignedInteger`; the signed
    /// counterpart to ``UInt256``.
    ///
    /// ## Overview
    ///
    /// `Int256` is the two's-complement counterpart to ``UInt256`` used where signed
    /// arithmetic is needed (e.g. certain BIP-32 child-key derivation intermediate steps
    /// or Miller-Rabin witness computations). The high limb is `Swift.Int128` so the sign
    /// bit lives in its natural position (bit 255); the low limb remains `UInt128` to keep
    /// addition / subtraction carry logic uniform with the unsigned type.
    ///
    /// > Important: Same caveat as ``UInt256`` — operations are not constant-time and
    /// > must not be used for secret scalar arithmetic.
    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    @frozen
    public struct Int256 {
        /// The low 128 bits of the 256-bit value (always interpreted as unsigned).
        ///
        /// Internal-visibility limb used by `@inlinable` arithmetic. Kept `UInt128` even
        /// on the signed type so carry propagation from the low limb matches the unsigned
        /// case.
        @usableFromInline var _low: Swift.UInt128

        /// The high 128 bits of the 256-bit value, including the sign bit at position 255.
        ///
        /// Internal-visibility limb. Value is `_high * 2^128 + Int128(bitPattern: _low)`
        /// under two's-complement semantics.
        @usableFromInline var _high: Swift.Int128

        /// Creates an `Int256` with the value `0`.
        @inlinable public init() {
            self._low = 0
            self._high = 0
        }

        /// Creates an `Int256` from raw low (`UInt128`) and high (`Int128`) limbs.
        ///
        /// Internal-visibility constructor used by arithmetic helpers.
        ///
        /// - Parameter _low: The low 128 bits (unsigned).
        /// - Parameter _high: The high 128 bits (signed, containing the sign bit).
        @usableFromInline
        init(_low: Swift.UInt128, _high: Swift.Int128) {
            self._low = _low
            self._high = _high
        }
    }

    // MARK: - Bit-pattern conversions

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public extension UInt256 {
        /// Creates a `UInt256` with the same bit pattern as a signed ``Int256`` value.
        ///
        /// Preserves the raw 256 bits verbatim; negative `Int256` values become large
        /// unsigned values via two's-complement interpretation. Matches the Swift
        /// standard-library convention (e.g. `UInt64(bitPattern: Int64)`).
        ///
        /// - Parameter source: The signed value whose bits are reinterpreted.
        @inlinable
        init(bitPattern source: Int256) {
            self._low = source._low
            self._high = Swift.UInt128(bitPattern: source._high)
        }
    }

    @available(macOS 15.0, iOS 18.0, macCatalyst 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    public extension Int256 {
        /// Creates an `Int256` with the same bit pattern as an unsigned ``UInt256`` value.
        ///
        /// Preserves the raw 256 bits verbatim; unsigned values ≥ `2^255` become negative
        /// `Int256` values via two's-complement interpretation.
        ///
        /// - Parameter source: The unsigned value whose bits are reinterpreted.
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
