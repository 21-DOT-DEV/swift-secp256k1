//
//  Errors.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

/// Errors thrown by swift-secp256k1 operations: covers key-size mismatches, byte-count errors for individual parameters, and failures propagated from the libsecp256k1 C library.
public enum secp256k1Error: Error {
    /// A key was deserialized with the wrong byte count (e.g., 33 bytes for compressed or 65 bytes for uncompressed secp256k1 keys).
    case incorrectKeySize

    /// A function argument had the wrong number of bytes (e.g., a 32-byte hash, nonce, or tweak scalar was expected but not provided).
    case incorrectParameterSize

    /// A libsecp256k1 C function returned `0`, indicating the cryptographic operation failed (invalid key, invalid signature, or arithmetic failure).
    case underlyingCryptoError
}
