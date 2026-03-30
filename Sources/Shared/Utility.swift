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
    /// The raw bytes of this value as a `[UInt8]` array, equivalent to `withUnsafeBytes { Array($0) }`.
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }
}

public extension Data {
    /// Copies up to `MemoryLayout<T>.size` bytes from this `Data` into the raw memory of `value`, used to populate opaque C structs such as `secp256k1_pubkey` and `secp256k1_musig_aggnonce`.
    ///
    /// - Parameter value: The inout value whose raw bytes are overwritten; only the leading `min(self.count, MemoryLayout<T>.size)` bytes are written.
    func copyToUnsafeMutableBytes<T>(of value: inout T) {
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            ptr.copyBytes(from: self.prefix(ptr.count))
        }
    }

    /// The data prefixed with a Bitcoin-style compact-size integer encoding the byte count: 1 byte for lengths 0–252, 3 bytes (`0xfd` + LE16) for 253–65535, 5 bytes (`0xfe` + LE32) for larger, and 9 bytes (`0xff` + LE64) for the full 64-bit range.
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

/// An extension for Int32 providing a convenience property.
extension Int32 {
    /// A property that returns a Bool representation of the Int32 value.
    var boolValue: Bool {
        Bool(truncating: NSNumber(value: self))
    }
}

/// An extension for secp256k1_ecdsa_signature providing a convenience property.
extension secp256k1_ecdsa_signature {
    /// A property that returns the Data representation of the `secp256k1_ecdsa_signature` object.
    var dataValue: Data {
        var mutableSig = self
        return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
    }
}

#if Xcode || ENABLE_MODULE_RECOVERY
    /// An extension for secp256k1_ecdsa_recoverable_signature providing a convenience property.
    extension secp256k1_ecdsa_recoverable_signature {
        /// A property that returns the Data representation of the `secp256k1_ecdsa_recoverable_signature` object.
        var dataValue: Data {
            var mutableSig = self
            return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
        }
    }
#endif

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension String {
    /// Creates a lowercase hex-encoded string from `bytes`, backed by the `hexString` property on `DataProtocol`.
    ///
    /// - Parameter bytes: The bytes to encode as a hexadecimal string.
    init<T: DataProtocol>(bytes: T) {
        self.init()
        self = bytes.hexString
    }

    /// The bytes decoded from this hex string, lowercased before decoding.
    ///
    /// - Throws: `ByteHexEncodingErrors.invalidHexString` if the string contains non-hex characters; `ByteHexEncodingErrors.invalidHexValue` if the string has an odd length.
    var bytes: [UInt8] {
        get throws {
            // The `BytesUtil.swift` Array extension expects lowercase strings.
            try Array(hexString: lowercased())
        }
    }
}

/// A utility class or struct to contain the static function
enum PointerArrayUtility {
    /// Executes a closure with an array of `UnsafePointer<T>?`.
    ///
    /// This method automatically manages memory allocation and deallocation
    /// for each pointer.
    ///
    /// - Parameters:
    ///   - collection: An array of `T` objects to be converted to `UnsafePointer<T>?`.
    ///   - body: A closure that receives an array of `UnsafePointer<T>?` and returns a result of type `Result`.
    /// - Returns: The result of the closure of type `Result`.
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
