//
//  NonceAggVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Nonce Aggregation test vectors container
struct NonceAggVectors: Codable {
    /// Array of public nonces in hex format (66 bytes each)
    let pnonces: [String]
    /// Valid test cases that should succeed
    let valid_test_cases: [NonceAggValidCase]
    /// Error test cases that should fail
    let error_test_cases: [NonceAggErrorCase]
}

/// A valid nonce aggregation test case
struct NonceAggValidCase: Codable {
    /// Indices into the pnonces array
    let pnonce_indices: [Int]
    /// Expected aggregated nonce in hex
    let expected: String
    /// Optional comment describing the test case
    let comment: String?
}

/// An error nonce aggregation test case
struct NonceAggErrorCase: Codable {
    /// Indices into the pnonces array
    let pnonce_indices: [Int]
    /// Expected error details
    let error: NonceAggError
    /// Optional comment describing the test case
    let comment: String?
}

/// Error details for a failed nonce aggregation
struct NonceAggError: Codable {
    /// Error type (e.g., "invalid_contribution")
    let type: String
    /// Signer index that caused the error
    let signer: Int?
    /// Contribution type that was invalid (e.g., "pubnonce")
    let contrib: String?
}
