//
//  TweakVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Tweak test vectors container
struct TweakVectors: Codable {
    /// Secret key for the signer (hex)
    let sk: String
    /// Array of public keys in compressed hex format
    let pubkeys: [String]
    /// Secret nonce (hex)
    let secnonce: String
    /// Array of public nonces (hex)
    let pnonces: [String]
    /// Aggregated nonce (hex)
    let aggnonce: String
    /// Array of tweaks in hex format
    let tweaks: [String]
    /// Message to sign (hex)
    let msg: String
    /// Valid test cases that should succeed
    let valid_test_cases: [TweakValidCase]
    /// Error test cases that should fail
    let error_test_cases: [TweakErrorCase]
}

/// A valid tweak test case
struct TweakValidCase: Codable {
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Indices into the tweaks array
    let tweak_indices: [Int]
    /// Whether each tweak is x-only
    let is_xonly: [Bool]
    /// Index of the signer
    let signer_index: Int
    /// Expected partial signature in hex
    let expected: String
    /// Optional comment describing the test case
    let comment: String?
}

/// An error tweak test case
struct TweakErrorCase: Codable {
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Indices into the tweaks array
    let tweak_indices: [Int]
    /// Whether each tweak is x-only
    let is_xonly: [Bool]
    /// Index of the signer
    let signer_index: Int
    /// Expected error details
    let error: TweakError
    /// Optional comment describing the test case
    let comment: String?
}

/// Error details for a failed tweak operation
struct TweakError: Codable {
    /// Error type (e.g., "value")
    let type: String
    /// Error message
    let message: String?
}
