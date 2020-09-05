//
//  Data.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2020 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

public extension DataProtocol {
    /// Public property backed by the `BytesUtil.swift` DataProtocol extension property `hexString`
    var hex: String {
        return hexString
    }
}
