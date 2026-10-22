//
//  Utility.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public import Foundation
import libsecp256k1

/// A `ContiguousBytes` type that permits copying its byte material out of its
/// storage, opting into the ``Swift/ContiguousBytes/byteArray`` convenience
/// accessor.
///
/// The marker is the compile-time gate on ``Swift/ContiguousBytes/byteArray``:
/// the accessor is declared only for `Self: CopyableBytes`, so reading it on a
/// non-conforming type fails to build. `SecureBytes` deliberately does not conform — it holds
/// secret material (private keys, secret nonces, shared secrets) in storage
/// that `memset_s`-zeroes on deallocation, and materializing a fresh `[UInt8]`
/// copy would outlive the `withUnsafeBytes` scope and be freed without
/// zeroing. Secret material reaches libsecp256k1 through borrowed
/// `withUnsafeBytes` / `withUnsafeMutableBytes` pointers instead, and C
/// outputs land directly in `SecureBytes` storage via
/// `init(unsafeUninitializedCapacity:initializingWith:)`.
///
/// Conformances ship for the standard byte containers (`Foundation.Data`,
/// `Swift.Array`, `Swift.ArraySlice`) and for the library types whose public
/// API already exposes their byte material — digests, signatures, and public
/// nonces — plus ``SharedSecret``, whose `withUnsafeBytes` is the documented
/// extraction path (``HashDigest``, ``P256K/Signing/ECDSASignature``,
/// ``P256K/Recovery/ECDSASignature``, ``P256K/Schnorr/SchnorrSignature``,
/// ``P256K/Schnorr/Nonce``, ``P256K/MuSig/Nonce``,
/// ``P256K/MuSig/AggregateSignature``, ``P256K/Schnorr/PartialSignature``).
/// Callers may conform their own `ContiguousBytes` types.
public protocol CopyableBytes {}

extension Data: CopyableBytes {}
extension Array: CopyableBytes where Element == UInt8 {}
extension ArraySlice: CopyableBytes where Element == UInt8 {}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension SharedSecret: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension HashDigest: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Signing.ECDSASignature: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Recovery.ECDSASignature: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Schnorr.SchnorrSignature: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Schnorr.Nonce: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.MuSig.Nonce: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.MuSig.AggregateSignature: CopyableBytes {}
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K.Schnorr.PartialSignature: CopyableBytes {}

public extension ContiguousBytes where Self: CopyableBytes {
    /// The raw bytes of this value as a `[UInt8]` array, equivalent to
    /// `withUnsafeBytes { Array($0) }`.
    ///
    /// Convenience accessor used throughout swift-secp256k1 to marshal
    /// `CopyableBytes` conformers (`Data`, `[UInt8]`, digests, public key
    /// material, etc.) into a byte array for passing to upstream C functions
    /// that expect `const unsigned char *`.
    @inlinable var byteArray: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }

    /// Deprecated alias for ``byteArray`` — Foundation's `Data.bytes`
    /// (`RawSpan`) shadows this member on `Data` under newer SDKs, so the old
    /// name could not resolve reliably across conformers.
    @available(*, deprecated, renamed: "byteArray")
    @inlinable var bytes: [UInt8] {
        byteArray
    }
}

/// Typed-pointer borrows for the upstream C boundary.
///
/// Upstream libsecp256k1 parameters are `ARG_NONNULL`, which Swift imports as
/// non-optional pointers — while `withUnsafeBytes` yields a buffer whose
/// `baseAddress` is optional, forcing a `guard let` + `bindMemory` dance at
/// every call site. These helpers unwrap once, so `body` receives a pointer
/// that passes straight into `secp256k1_*` calls. The pointer *borrows* the
/// storage — no copy is made — so unlike ``Swift/ContiguousBytes/byteArray``
/// the helpers are equally safe on `SecureBytes` secret material; the pointer
/// is valid only inside `body` and must not escape it.
///
/// Guards report through ``P256K/invariantFailure`` rather than `precondition`
/// — the conditions are unreachable at every call site, and `-Ounchecked`
/// builds compile `precondition` out entirely.
extension ContiguousBytes {
    /// Borrows the contiguous storage as an `UnsafePointer<UInt8>` for the
    /// duration of `body`.
    ///
    /// - Parameter body: A closure receiving a non-optional pointer to the
    ///   first byte.
    /// - Returns: The value produced by `body`.
    /// - Note: An empty buffer has no base address to lend — an unreachable
    ///   internal invariant reported through ``P256K/invariantFailure``. Every
    ///   call site binds fixed-size (≥32-byte) buffers.
    @usableFromInline
    func withUnsafeBytePointer<Result>(
        _ body: (UnsafePointer<UInt8>) throws -> Result
    ) rethrows -> Result {
        try withUnsafeBytes { buffer in
            guard let pointer = buffer.bindMemory(to: UInt8.self).baseAddress else {
                P256K.invariantFailure("Cannot borrow a pointer to empty ContiguousBytes storage")
            }
            return try body(pointer)
        }
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension SecureBytes {
    /// `withUnsafeBytePointer` for the mutable storage: upstream writes — or
    /// zeroes — the `SecureBytes` backing in place.
    ///
    /// - Parameter body: A closure receiving a non-optional mutable pointer to
    ///   the first byte.
    /// - Returns: The value produced by `body`.
    /// - Note: The storage must be non-empty — an unreachable internal
    ///   invariant reported through ``P256K/invariantFailure``.
    @usableFromInline
    mutating func withUnsafeMutableBytePointer<Result>(
        _ body: (UnsafeMutablePointer<UInt8>) throws -> Result
    ) rethrows -> Result {
        try withUnsafeMutableBytes(boundTo: UInt8.self, body)
    }

    /// Binds the `SecureBytes` storage as a typed C-struct pointer for the
    /// duration of `body`, letting upstream write opaque structs
    /// (`secp256k1_musig_secnonce`) directly into zeroizing storage.
    ///
    /// `bindMemory` rebinds the backing's element type: reading the storage
    /// back through the `Collection` (`UInt8`) conformance is formally reading
    /// rebound memory until the buffer is unbound — safe for the POD
    /// byte-array structs bound here (alignment 1, opaque `unsigned char`
    /// fields), and no caller reads the bytes after binding.
    ///
    /// - Parameters:
    ///   - type: The POD struct type to bind the storage as.
    ///   - body: A closure receiving a non-optional pointer bound to `type`.
    /// - Returns: The value produced by `body`.
    /// - Note: An empty buffer, a shortfall of `MemoryLayout<T>.size` bytes, or
    ///   misaligned storage is an unreachable internal invariant reported
    ///   through ``P256K/invariantFailure``.
    @usableFromInline
    mutating func withUnsafeMutableBytes<T, Result>(
        boundTo type: T.Type,
        _ body: (UnsafeMutablePointer<T>) throws -> Result
    ) rethrows -> Result {
        try withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                P256K.invariantFailure("Cannot borrow a pointer to empty SecureBytes storage")
            }
            guard buffer.count >= MemoryLayout<T>.size,
                  UInt(bitPattern: baseAddress) % UInt(MemoryLayout<T>.alignment) == 0
            else {
                P256K.invariantFailure(
                    "Cannot bind \(T.self) (\(MemoryLayout<T>.size) bytes, alignment \(MemoryLayout<T>.alignment)) into SecureBytes storage of \(buffer.count) bytes"
                )
            }
            guard let pointer = buffer.bindMemory(to: type).baseAddress else {
                P256K.invariantFailure("Cannot bind \(T.self) into SecureBytes storage")
            }
            return try body(pointer)
        }
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension Sequence where Element == UInt8 {
    /// Normalizes a byte sequence to the fixed 32-byte `msg32` value upstream
    /// libsecp256k1 message parameters read.
    ///
    /// Follows the SEC1 §4.1.3 / FIPS 186-5 digest-to-integer reduction for a
    /// 256-bit group order: inputs longer than 32 bytes contribute their
    /// leftmost 32 bytes; shorter inputs contribute their integer value,
    /// equivalent to left-padding with zeros. This matches the reduction applied
    /// by Go `crypto/ecdsa` (`hashToInt`), OpenSSL (`bits2int`), and CryptoKit's
    /// `signature(for:)` APIs.
    var msg32Bytes: [UInt8] {
        let bytes = Array(self)
        switch bytes.count {
        case P256K.ByteLength.dimension:
            return bytes

        case ..<P256K.ByteLength.dimension:
            return [UInt8](repeating: 0, count: P256K.ByteLength.dimension - bytes.count) + bytes

        default:
            return Array(bytes.prefix(P256K.ByteLength.dimension))
        }
    }
}

public extension Data {
    /// Copies up to `MemoryLayout<T>.size` bytes from this `Data` into the raw memory of
    /// `value`, used to populate opaque C structs such as `secp256k1_pubkey` and
    /// `secp256k1_musig_aggnonce`.
    ///
    /// Swift-side helper for round-tripping opaque upstream structs through wire formats.
    /// The upstream C structs are declared as `unsigned char data[N]` arrays, so copying
    /// their raw bytes into a freshly-zeroed `T` via this helper is safe when the Swift
    /// `Data` was produced by a matching upstream `*_serialize` call on the same version
    /// of libsecp256k1.
    ///
    /// > Important: These struct layouts are **not stable across libsecp256k1 versions**.
    /// > Cross-process persistence should use the upstream `*_serialize` / `*_parse`
    /// > functions exposed by the wrapper types, not the raw struct bytes.
    ///
    /// - Parameter value: The inout value whose raw bytes are overwritten; only the
    ///   leading `min(self.count, MemoryLayout<T>.size)` bytes are written.
    func copyToUnsafeMutableBytes<T>(of value: inout T) {
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            ptr.copyBytes(from: self.prefix(ptr.count))
        }
    }

    /// The data prefixed with a Bitcoin-style compact-size integer encoding the byte count.
    ///
    /// Compact-size (aka `CompactSize` / `VarInt`) is the variable-length integer encoding
    /// Bitcoin Core uses for serialized wire formats
    /// ([`src/serialize.h`](https://github.com/bitcoin/bitcoin/blob/master/src/serialize.h)).
    /// The encoding is **not** the same as the Protobuf `varint` or SQLite `varint` — it
    /// uses a fixed prefix byte to indicate width:
    ///
    /// - 1 byte for lengths `0–252` (the length byte itself)
    /// - 3 bytes (`0xfd` + little-endian `UInt16`) for `253–65535`
    /// - 5 bytes (`0xfe` + little-endian `UInt32`) for `65536–4_294_967_295`
    /// - 9 bytes (`0xff` + little-endian `UInt64`) for the full 64-bit range
    var compactSizePrefix: Data {
        let size = UInt64(count)
        var prefix = Data()

        switch size {
        case 0..<253:
            prefix.append(UInt8(size))

        case 253...UInt64(UInt16.max):
            prefix.append(253)
            prefix.append(UInt8(size & 0xFF))
            prefix.append(UInt8(size >> 8))

        case (UInt64(UInt16.max) + 1)...UInt64(UInt32.max):
            prefix.append(254)
            prefix.append(contentsOf: Swift.withUnsafeBytes(of: UInt32(size)) { Array($0) })

        default:
            prefix.append(255)
            prefix.append(contentsOf: Swift.withUnsafeBytes(of: size) { Array($0) })
        }

        return prefix + self
    }
}

/// Convenience coercion for the `Int32` return type used throughout libsecp256k1.
extension Int32 {
    /// A `Bool` representation of the `Int32` value: `true` for any non-zero value,
    /// `false` for `0`.
    ///
    /// Used to translate upstream libsecp256k1 return values (which follow the standard
    /// C convention of `1` for success, `0` for failure) into Swift-native `Bool` for
    /// `guard` / `if` predicates at call sites.
    var boolValue: Bool {
        Bool(truncating: NSNumber(value: self))
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension String {
    /// Creates a lowercase hex-encoded string from `bytes`, backed by the `hexString`
    /// property on `DataProtocol`.
    ///
    /// Each input byte becomes exactly two lowercase hexadecimal characters; no prefix
    /// (e.g. `0x`) and no separators are added. Useful for displaying fingerprints, key
    /// fingerprints, and Bitcoin txids / block hashes.
    ///
    /// - Parameter bytes: The bytes to encode as a hexadecimal string.
    init<T: DataProtocol>(bytes: T) {
        self.init()
        self = bytes.hexString
    }

    /// The bytes decoded from this hex string, lowercased before decoding.
    ///
    /// Expects a string of even length containing only `[0-9a-fA-F]`. The lowercasing
    /// step is defensive — the underlying decoder is case-sensitive on its lowercase
    /// path — and means the input is rejected even if it contains ambiguous characters
    /// like non-ASCII digits.
    ///
    /// - Throws: `ByteHexEncodingErrors.invalidHexString` if the string contains non-hex
    ///   characters; `ByteHexEncodingErrors.invalidHexValue` if the string has an odd
    ///   length.
    var bytes: [UInt8] {
        get throws {
            // The `BytesUtil.swift` Array extension expects lowercase strings.
            try Array(hexString: lowercased())
        }
    }
}

/// Byte-level validators for the opaque `secp256k1_musig_*` state blobs that
/// public APIs accept for session/cache persistence.
///
/// Upstream checks each struct's leading 4-byte magic inside `ARG_CHECK` in the
/// `*_load` helpers (`src/modules/musig/session_impl.h`,
/// `src/modules/musig/keyagg_impl.h`), which invokes the default
/// illegal-argument callback — `abort()` — on mismatch. Every blob copied into
/// one of these structs is therefore validated at the Swift boundary first so a
/// malformed or truncated blob surfaces a thrown error instead of terminating
/// the process. The magic values are pinned to the vendored libsecp256k1
/// version (`vendir.yml`); if upstream ever changes them the vendir bump's
/// `libsecp256k1Tests` run surfaces the drift.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
enum MuSigOpaqueState {
    /// `sizeof(secp256k1_musig_keyagg_cache)` — 197 bytes
    /// (`secp256k1/include/secp256k1_musig.h`).
    static let keyAggregationCacheByteCount = 197

    /// `sizeof(secp256k1_musig_session)` — 133 bytes.
    static let sessionByteCount = 133

    /// Leading 4 bytes written by `secp256k1_musig_keyagg_cache_save` and checked
    /// by `keyagg_cache_load` (`src/modules/musig/keyagg_impl.h`).
    static let keyAggregationCacheMagic: [UInt8] = [0xF4, 0xAD, 0xBB, 0xDF]

    /// Leading 4 bytes checked by `secp256k1_musig_session_load`
    /// (`src/modules/musig/session_impl.h`).
    static let sessionMagic: [UInt8] = [0x9D, 0xED, 0xE9, 0x17]

    /// `true` when `bytes` is a complete `secp256k1_musig_keyagg_cache` blob
    /// carrying the upstream magic prefix — safe to pass to a `*_load` path.
    static func isValidKeyAggregationCache(_ bytes: some Collection<UInt8>) -> Bool {
        bytes.count == keyAggregationCacheByteCount && bytes.prefix(4).elementsEqual(keyAggregationCacheMagic)
    }

    /// `true` when `bytes` is a complete `secp256k1_musig_session` blob carrying
    /// the upstream magic prefix.
    static func isValidSession(_ bytes: some Collection<UInt8>) -> Bool {
        bytes.count == sessionByteCount && bytes.prefix(4).elementsEqual(sessionMagic)
    }
}

/// Internal-visibility helper for the common pattern of passing an array of
/// pointer-to-`T` values to a C variadic / array-of-pointers parameter.
///
/// Used where upstream libsecp256k1 functions take `const T * const *` (e.g.
/// `secp256k1_ec_pubkey_combine` accepts `const secp256k1_pubkey * const * ins`). The
/// helper allocates, writes, hands the pointer array to the caller's closure, and
/// deallocates after the closure returns.
enum PointerArrayUtility {
    /// Executes `body` with an array of `UnsafePointer<T>?` wrapping each element of
    /// `collection`, allocating fresh storage per element and deallocating after the
    /// closure returns.
    ///
    /// The `inout` parameter to `body` is a live pointer array safe to pass directly
    /// into an upstream C function that accepts `const T * const *`. The pointers are
    /// stable for the duration of the closure; **do not** let them escape the closure
    /// scope — the `defer` block deallocates them on return.
    ///
    /// - Parameters:
    ///   - collection: An array of `T` objects to be converted to `UnsafePointer<T>?`.
    ///   - body: A closure that receives an array of `UnsafePointer<T>?` and returns a
    ///     result of type `Result`.
    /// - Returns: The value produced by `body`.
    static func withUnsafePointerArray<T, Result>(
        _ collection: [T],
        _ body: (inout [UnsafePointer<T>?]) -> Result
    ) -> Result {
        var pointers: [UnsafePointer<T>?] = collection.map { item in
            let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
            pointer.initialize(to: item)
            return UnsafePointer(pointer)
        }

        defer {
            pointers.forEach { $0?.deallocate() }
        }

        return body(&pointers)
    }
}
