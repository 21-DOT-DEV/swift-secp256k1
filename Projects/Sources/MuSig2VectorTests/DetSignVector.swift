//
//  DetSignVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Deterministic Sign test vectors container
struct DetSignVectors: Codable {
    /// Secret key (hex)
    let sk: String
    /// Array of public keys in compressed hex format
    let pubkeys: [String]
    /// Array of messages (hex)
    let msgs: [String]
    /// Valid test cases
    let valid_test_cases: [DetSignValidCase]
    /// Error test cases
    let error_test_cases: [DetSignErrorCase]
}

/// A valid deterministic sign test case
struct DetSignValidCase: Codable {
    /// Random input (optional, hex)
    let rand: String?
    /// Aggregated other nonce (hex)
    let aggothernonce: String
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Array of tweaks (hex)
    let tweaks: [String]
    /// Whether each tweak is x-only
    let is_xonly: [Bool]
    /// Index into the msgs array
    let msg_index: Int
    /// Index of the signer
    let signer_index: Int
    /// Expected output [pubnonce, psig]
    let expected: [String]
    /// Optional comment
    let comment: String?
}

/// An error deterministic sign test case
struct DetSignErrorCase: Codable {
    /// Random input (hex)
    let rand: String?
    /// Aggregated other nonce (hex)
    let aggothernonce: String
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Array of tweaks (hex)
    let tweaks: [String]
    /// Whether each tweak is x-only
    let is_xonly: [Bool]
    /// Index into the msgs array
    let msg_index: Int
    /// Index of the signer
    let signer_index: Int
    /// Expected error
    let error: DetSignError
    /// Optional comment
    let comment: String?
}

/// Error details for deterministic sign
struct DetSignError: Codable {
    /// Error type
    let type: String
    /// Signer index
    let signer: Int?
    /// Contribution type
    let contrib: String?
}
