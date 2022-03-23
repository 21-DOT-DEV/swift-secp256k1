//
//  Data.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

public extension Data {
    @inlinable var bytes: [UInt8] {
        self.withUnsafeBytes({ keyBytesPtr in Array(keyBytesPtr) })
    }

    func copyToUnsafeMutableBytes<T>(of value: inout T) {
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            ptr.copyBytes(from: self.prefix(ptr.count))
        }
    }
}

extension ContiguousBytes {
    @inlinable var bytes: [UInt8] {
        self.withUnsafeBytes({ keyBytesPtr in Array(keyBytesPtr) })
    }
}
