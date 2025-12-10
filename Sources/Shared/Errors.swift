//
//  Errors.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

/// Errors thrown for secp256k1
public enum secp256k1Error: Error {
    /// A key is being deserialized with an incorrect key size.
    case incorrectKeySize

    /// The number of bytes passed for a given argument is incorrect.
    case incorrectParameterSize

    /// An unexpected error at a lower-level occurred.
    case underlyingCryptoError
}
