//
//  Errors.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// Errors thrown for secp256k1
/// - incorrectKeySize: A key is being deserialized with an incorrect key size.
/// - incorrectParameterSize: The number of bytes passed for a given argument is incorrect.
/// - underlyingCryptoError: An unexpected error at a lower-level occurred.
public enum secp256k1Error: Error {
    case incorrectKeySize
    case incorrectParameterSize
    case underlyingCryptoError
}
