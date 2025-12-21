//
//  WycheproofECDSA.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// Wycheproof ECDSA Bitcoin test file container
struct WycheproofECDSABitcoin: Codable {
    let algorithm: String
    let numberOfTests: Int
    let notes: [String: WycheproofNote]?
    let testGroups: [ECDSABitcoinTestGroup]
}

/// ECDSA Bitcoin public key
struct ECDSAPublicKey: Codable {
    let type: String
    let curve: String
    let keySize: Int
    let uncompressed: String
    let wx: String
    let wy: String
}

/// ECDSA Bitcoin test group
struct ECDSABitcoinTestGroup: Codable {
    let type: String
    let publicKey: ECDSAPublicKey
    let publicKeyDer: String?
    let publicKeyPem: String?
    let sha: String
    let tests: [ECDSABitcoinTestVector]
}

/// Individual ECDSA Bitcoin test vector
struct ECDSABitcoinTestVector: Codable {
    /// Test case ID
    let tcId: Int

    /// Description of the test case
    let comment: String

    /// Flags indicating test characteristics
    let flags: [String]

    /// Message to verify (hex)
    let msg: String

    /// DER-encoded signature (hex)
    let sig: String

    /// Expected result: "valid" or "invalid"
    let result: WycheproofResult
}
