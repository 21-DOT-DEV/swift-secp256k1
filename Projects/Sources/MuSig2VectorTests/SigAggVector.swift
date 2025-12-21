//
//  SigAggVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Signature Aggregation test vectors container
struct SigAggVectors: Codable {
    /// Array of public keys in compressed hex format
    let pubkeys: [String]
    /// Array of public nonces (hex)
    let pnonces: [String]
    /// Array of tweaks (hex)
    let tweaks: [String]
    /// Array of partial signatures (hex)
    let psigs: [String]
    /// Message to sign (hex)
    let msg: String
    /// Valid test cases
    let valid_test_cases: [SigAggValidCase]
    /// Error test cases
    let error_test_cases: [SigAggErrorCase]
}

/// A valid signature aggregation test case
struct SigAggValidCase: Codable {
    /// Aggregated nonce (hex)
    let aggnonce: String
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the tweaks array
    let tweak_indices: [Int]
    /// Whether each tweak is x-only
    let is_xonly: [Bool]
    /// Indices into the psigs array
    let psig_indices: [Int]
    /// Expected aggregated signature (hex)
    let expected: String
}

/// An error signature aggregation test case
struct SigAggErrorCase: Codable {
    /// Aggregated nonce (hex)
    let aggnonce: String
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the tweaks array
    let tweak_indices: [Int]
    /// Whether each tweak is x-only
    let is_xonly: [Bool]
    /// Indices into the psigs array
    let psig_indices: [Int]
    /// Expected error
    let error: SigAggError
    /// Optional comment
    let comment: String?
}

/// Error details for signature aggregation
struct SigAggError: Codable {
    /// Error type
    let type: String
    /// Signer index
    let signer: Int?
    /// Contribution type
    let contrib: String?
}
