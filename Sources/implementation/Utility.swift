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
import secp256k1_bindings

public extension ContiguousBytes {
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }
}

public extension Data {
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }

    func copyToUnsafeMutableBytes<T>(of value: inout T) {
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            ptr.copyBytes(from: self.prefix(ptr.count))
        }
    }
}

extension Int32 {
    var boolValue: Bool {
        Bool(truncating: NSNumber(value: self))
    }
}

public extension secp256k1_ecdsa_signature {
    var dataValue: Data {
        var mutableSig = self
        return Data(bytes: &mutableSig.data, count: MemoryLayout.size(ofValue: data))
    }
}

public extension String {
    /// Public initializer backed by the `BytesUtil.swift` DataProtocol extension property `hexString`
    /// - Parameter bytes: byte array to initialize
    init<T: DataProtocol>(bytes: T) {
        self.init()
        self = bytes.hexString
    }

    /// Public convenience property backed by the `BytesUtil.swift` Array extension initializer
    /// - Throws: `ByteHexEncodingErrors` for invalid string or hex value
    var bytes: [UInt8] {
        get throws {
            // The `BytesUtil.swift` Array extension expects lowercase strings
            try Array(hexString: lowercased())
        }
    }
}
