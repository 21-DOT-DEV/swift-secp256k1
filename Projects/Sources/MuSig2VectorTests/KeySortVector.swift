//
//  KeySortVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Key Sort test vectors container
struct KeySortVectors: Codable {
    /// Array of public keys in compressed hex format
    let pubkeys: [String]
    /// Expected canonically sorted public keys in compressed hex format
    let sorted_pubkeys: [String]
}
