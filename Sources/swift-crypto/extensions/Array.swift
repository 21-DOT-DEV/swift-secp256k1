//
//  Array.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2020 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public extension Array where Element == UInt8 {
    /// Public initializer backed by the `BytesUtil.swift` Array extension
    /// - Parameter hex: hexadecimal string to initialize
    /// - Throws: `ByteHexEncodingErrors` for invalid string or hex value
    init(hex: String) throws {
        self.init()
        // The `BytesUtil.swift` Array extension expects lowercase strings
        self = try Array(hexString: hex.lowercased())
    }
}
