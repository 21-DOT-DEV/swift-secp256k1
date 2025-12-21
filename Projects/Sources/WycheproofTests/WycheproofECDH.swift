//
//  WycheproofECDH.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// Wycheproof ECDH test file container
struct WycheproofECDH: Codable {
    let algorithm: String
    let numberOfTests: Int
    let notes: [String: WycheproofNote]?
    let testGroups: [ECDHTestGroup]
}

/// Note describing a flag/bug type
struct WycheproofNote: Codable {
    let bugType: String
    let description: String
    let effect: String?
    let cves: [String]?
}

/// ECDH test group
struct ECDHTestGroup: Codable {
    let type: String
    let curve: String
    let encoding: String?
    let tests: [ECDHTestVector]
}

/// Individual ECDH test vector
struct ECDHTestVector: Codable {
    /// Test case ID
    let tcId: Int

    /// Description of the test case
    let comment: String

    /// Flags indicating test characteristics (e.g., "Normal", "InvalidCurveAttack")
    let flags: [String]

    /// Public key (ASN.1 DER encoded, hex)
    let `public`: String

    /// Private key (hex)
    let `private`: String

    /// Expected shared secret (hex)
    let shared: String

    /// Expected result: "valid", "invalid", or "acceptable"
    let result: WycheproofResult
}

/// Wycheproof result type
enum WycheproofResult: String, Codable {
    case valid
    case invalid
    case acceptable
}
