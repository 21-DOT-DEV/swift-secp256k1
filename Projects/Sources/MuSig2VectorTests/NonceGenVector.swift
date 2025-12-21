//
//  NonceGenVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Nonce Generation test vectors container
struct NonceGenVectors: Codable {
    /// Array of test cases
    let test_cases: [NonceGenTestCase]
}

/// A nonce generation test case
struct NonceGenTestCase: Codable {
    /// Random input (32 bytes hex)
    let rand_: String
    /// Secret key (optional, 32 bytes hex)
    let sk: String?
    /// Public key (33 bytes compressed hex)
    let pk: String
    /// Aggregated public key (optional, 32 bytes hex)
    let aggpk: String?
    /// Message to sign (optional, variable length hex)
    let msg: String?
    /// Extra input (optional, 32 bytes hex)
    let extra_in: String?
    /// Expected secret nonce output (97 bytes hex)
    let expected_secnonce: String
    /// Expected public nonce output (66 bytes hex)
    let expected_pubnonce: String
}
