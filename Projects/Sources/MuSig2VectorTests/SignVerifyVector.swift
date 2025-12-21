//
//  SignVerifyVector.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// BIP-0327 Sign/Verify test vectors container
struct SignVerifyVectors: Codable {
    /// Secret key for the signer (hex)
    let sk: String
    /// Array of public keys in compressed hex format
    let pubkeys: [String]
    /// Array of secret nonces (hex)
    let secnonces: [String]
    /// Array of public nonces (hex)
    let pnonces: [String]
    /// Array of aggregated nonces (hex)
    let aggnonces: [String]
    /// Array of messages (hex)
    let msgs: [String]
    /// Valid test cases that should succeed
    let valid_test_cases: [SignVerifyValidCase]
    /// Sign error test cases
    let sign_error_test_cases: [SignVerifyErrorCase]
    /// Verify fail test cases (verification returns false)
    let verify_fail_test_cases: [VerifyFailCase]
    /// Verify error test cases (verification throws)
    let verify_error_test_cases: [VerifyErrorCase]
}

/// A valid sign/verify test case
struct SignVerifyValidCase: Codable {
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Index into the aggnonces array
    let aggnonce_index: Int
    /// Index into the msgs array
    let msg_index: Int
    /// Index of the signer
    let signer_index: Int
    /// Expected partial signature in hex
    let expected: String
    /// Optional comment
    let comment: String?
}

/// A sign error test case
struct SignVerifyErrorCase: Codable {
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Index into the aggnonces array
    let aggnonce_index: Int
    /// Index into the msgs array
    let msg_index: Int
    /// Index into the secnonces array
    let secnonce_index: Int?
    /// Index of the signer
    let signer_index: Int?
    /// Expected error
    let error: SignVerifyError
    /// Optional comment
    let comment: String?
}

/// A verify fail test case (verification returns false)
struct VerifyFailCase: Codable {
    /// Partial signature (hex)
    let sig: String
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Index into the msgs array
    let msg_index: Int
    /// Index of the signer
    let signer_index: Int
    /// Optional comment
    let comment: String?
}

/// A verify error test case (verification throws)
struct VerifyErrorCase: Codable {
    /// Partial signature (hex)
    let sig: String
    /// Indices into the pubkeys array
    let key_indices: [Int]
    /// Indices into the pnonces array
    let nonce_indices: [Int]
    /// Index into the msgs array
    let msg_index: Int
    /// Index of the signer
    let signer_index: Int
    /// Expected error
    let error: SignVerifyError
    /// Optional comment
    let comment: String?
}

/// Error details for sign/verify operations
struct SignVerifyError: Codable {
    /// Error type
    let type: String
    /// Signer index (for invalid_contribution)
    let signer: Int?
    /// Contribution type
    let contrib: String?
    /// Error message (for value errors)
    let message: String?
}
