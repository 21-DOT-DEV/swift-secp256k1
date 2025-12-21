//
//  KeyAggVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Key Aggregation test vectors container
struct KeyAggVectors: Codable {
    /// Array of public keys in compressed hex format
    let pubkeys: [String]
    /// Array of tweaks in hex format
    let tweaks: [String]
    /// Valid test cases that should succeed
    let valid_test_cases: [KeyAggValidCase]
    /// Error test cases that should fail
    let error_test_cases: [KeyAggErrorCase]
}

/// A valid key aggregation test case
struct KeyAggValidCase: Codable {
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Expected aggregated x-only public key in hex
    let expected: String
}

/// An error key aggregation test case
struct KeyAggErrorCase: Codable {
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the tweaks array (may be empty)
    let tweak_indices: [Int]
    /// Whether each tweak is x-only (may be empty)
    let is_xonly: [Bool]
    /// Expected error details
    let error: KeyAggError
    /// Optional comment describing the test case
    let comment: String?
}

/// Error details for a failed key aggregation
struct KeyAggError: Codable {
    /// Error type (e.g., "invalid_contribution", "value")
    let type: String
    /// Signer index that caused the error (for invalid_contribution)
    let signer: Int?
    /// Contribution type that was invalid (e.g., "pubkey")
    let contrib: String?
    /// Error message (for value errors)
    let message: String?
}
