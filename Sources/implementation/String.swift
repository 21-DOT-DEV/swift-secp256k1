//
//  String.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

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
