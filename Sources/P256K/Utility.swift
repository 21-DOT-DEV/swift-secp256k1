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

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

public extension ContiguousBytes {
    /// The raw bytes of this value as a `[UInt8]` array, equivalent to
    /// `withUnsafeBytes { Array($0) }`.
    ///
    /// Convenience accessor used throughout swift-secp256k1 to marshal arbitrary
    /// `ContiguousBytes` conformers (`Data`, `[UInt8]`, `SecureBytes`, etc.) into a byte
    /// array for passing to upstream C functions that expect `const unsigned char *`.
    /// The copy is unavoidable when the upstream API requires a guaranteed-contiguous
    /// buffer with a known length.
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
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

/// Internal-visibility extraction of the opaque byte buffer inside
/// `secp256k1_ecdsa_signature`.
extension secp256k1_ecdsa_signature {
    /// A `Data` copy of the opaque 64-byte `data` array inside the upstream
    /// `secp256k1_ecdsa_signature` struct.
    ///
    /// Used only for in-memory comparisons / hashing within the Swift wrapper. The bytes
    /// are **not** a stable serialization format across libsecp256k1 versions; external
    /// transmission uses the compact (64-byte) or DER serializations produced by
    /// `secp256k1_ecdsa_signature_serialize_compact` and
    /// `secp256k1_ecdsa_signature_serialize_der`.
    var dataValue: Data {
        var mutableSig = self
        return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
    }
}

#if Xcode || ENABLE_MODULE_RECOVERY
    /// Internal-visibility extraction of the opaque byte buffer inside
    /// `secp256k1_ecdsa_recoverable_signature`.
    extension secp256k1_ecdsa_recoverable_signature {
        /// A `Data` copy of the opaque 65-byte `data` array inside the upstream
        /// `secp256k1_ecdsa_recoverable_signature` struct.
        ///
        /// Used only for in-memory comparisons within the Swift wrapper. Wire-format
        /// persistence should use
        /// `secp256k1_ecdsa_recoverable_signature_serialize_compact`, which produces a
        /// 64-byte compact signature plus a separate recovery-ID byte.
        var dataValue: Data {
            var mutableSig = self
            return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
        }
    }
#endif

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
