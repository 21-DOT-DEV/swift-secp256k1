//
//  Errors.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
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
