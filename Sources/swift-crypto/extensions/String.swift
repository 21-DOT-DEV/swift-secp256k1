//
//  String.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2020 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

public extension String {
    /// Public initializer backed by the `BytesUtil.swift` DataProtocol extension property `hexString`
    /// - Parameter byteArray: byte array to initialize
    init<T: DataProtocol>(byteArray: T) {
        self.init()
        self = byteArray.hexString
    }

    /// Public convenience function backed by the `BytesUtil.swift` Array extension initializer
    /// - Throws: `ByteHexEncodingErrors` for invalid string or hex value
    /// - Returns: initialized byte array
    func byteArray() throws -> [UInt8] {
        // The `BytesUtil.swift` Array extension expects lowercase strings
        try Array(hexString: self.lowercased())
    }
}
