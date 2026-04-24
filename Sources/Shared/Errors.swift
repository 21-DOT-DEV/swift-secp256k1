//
//  Errors.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

/// Errors thrown by swift-secp256k1 operations: covers key-size mismatches, byte-count errors
/// for individual parameters, and failures propagated from the upstream libsecp256k1 C library
/// (see [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h)).
///
/// ## Topics
///
/// ### Size Validation
/// - ``incorrectKeySize``
/// - ``incorrectParameterSize``
///
/// ### Upstream Failures
/// - ``underlyingCryptoError``
public enum secp256k1Error: Error {
    /// A key was deserialized with the wrong byte count.
    ///
    /// Thrown when a serialized secp256k1 key's length does not match the expected
    /// ``P256K/Format``: 32 bytes for a private key, 33 bytes for ``P256K/Format/compressed``
    /// or x-only public keys, or 65 bytes for ``P256K/Format/uncompressed`` public keys.
    /// The validation happens **before** any upstream C call, so this case surfaces
    /// ill-formed inputs at the Swift layer.
    case incorrectKeySize

    /// A function argument had the wrong number of bytes.
    ///
    /// Thrown when a non-key parameter fails its fixed-length check — most commonly a
    /// 32-byte message digest, tweak scalar, nonce seed, or auxiliary randomness buffer.
    /// Distinct from ``incorrectKeySize`` so consumers can differentiate key-validation
    /// failures from argument-validation failures.
    case incorrectParameterSize

    /// A libsecp256k1 C function returned `0`, indicating the cryptographic operation
    /// failed.
    ///
    /// The upstream C API convention is that all boolean-returning functions return `1`
    /// on success and `0` on failure. This case wraps every such failure uniformly without
    /// attempting to recover the specific reason (the upstream API is deliberately opaque
    /// about failure modes to avoid leaking secret-dependent information through the
    /// error channel). Common triggers: invalid private key scalar (zero or ≥ curve
    /// order), invalid signature encoding, off-curve public-key points, invalid Taproot
    /// tweak, or a fatal internal-consistency check.
    case underlyingCryptoError
}
