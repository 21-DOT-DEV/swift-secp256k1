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

extension Data {
    var bytes: [UInt8] {
        self.withUnsafeBytes({ keyBytesPtr in Array(keyBytesPtr) })
    }
}
