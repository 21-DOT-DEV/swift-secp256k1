//
//  Utility.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    @_implementationOnly import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    @_implementationOnly import libsecp256k1
#endif

/// An extension for ContiguousBytes providing a convenience property.
public extension ContiguousBytes {
    /// A property that returns an array of UInt8 bytes.
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }
}

/// An extension for Data providing convenience properties and functions.
public extension Data {
    /// A property that returns an array of UInt8 bytes.
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }

    /// Copies data to unsafe mutable bytes of a given value.
    /// - Parameter value: The inout value to copy the data to.
    func copyToUnsafeMutableBytes<T>(of value: inout T) {
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            ptr.copyBytes(from: self.prefix(ptr.count))
        }
    }

    /// A computed property that returns the data with a compact size prefix.
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

/// An extension for secp256k1_ecdsa_recoverable_signature providing a convenience property.
extension secp256k1_ecdsa_recoverable_signature {
    /// A property that returns the Data representation of the `secp256k1_ecdsa_recoverable_signature` object.
    var dataValue: Data {
        var mutableSig = self
        return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
    }
}

/// An extension for String providing convenience initializers and properties for working with bytes.
public extension String {
    /// Initializes a String from a byte array using the `hexString` property from the `BytesUtil.swift` DataProtocol extension.
    /// - Parameter bytes: A byte array to initialize the String.
    init<T: DataProtocol>(bytes: T) {
        self.init()
        self = bytes.hexString
    }

    /// A convenience property that returns a byte array from a hexadecimal string.
    /// Backed by the `BytesUtil.swift` Array extension initializer.
    /// - Throws: `ByteHexEncodingErrors` for invalid string or hex value.
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
