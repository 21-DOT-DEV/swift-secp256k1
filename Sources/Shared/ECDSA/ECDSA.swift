//
//  ECDSA.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// Composition constraint matching swift-crypto's NIST-curve ECDSA signature shape: any
/// type that exposes both a compact `dataRepresentation` and a DER `derRepresentation`.
typealias NISTECDSASignature = DERSignature & DataSignature

/// Internal-visibility protocol used by signature types to surface a fixed-width
/// serialization (64 bytes for ECDSA compact).
protocol DataSignature {
    init<D: DataProtocol>(dataRepresentation: D) throws
    var dataRepresentation: Data { get }
}

/// Internal-visibility protocol used by signature types to surface the ASN.1 DER
/// serialization defined by SEC1 § 4.1. DER-encoded ECDSA signatures are variable-length
/// (roughly 70–72 bytes in practice).
protocol DERSignature {
    init<D: DataProtocol>(derRepresentation: D) throws
    var derRepresentation: Data { get }
}

/// Internal-visibility protocol used by signature types to surface a Bitcoin-style
/// compact serialization (64 bytes for ECDSA, 65 bytes for recoverable ECDSA).
protocol CompactSignature {
    init<D: DataProtocol>(compactRepresentation: D) throws
    var compactRepresentation: Data { get }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// secp256k1 ECDSA signing namespace providing ``PrivateKey`` for RFC 6979 deterministic
    /// signing and ``PublicKey`` for signature verification; all produced signatures are
    /// lower-S normalized.
    ///
    /// ## Overview
    ///
    /// ECDSA (Elliptic Curve Digital Signature Algorithm) is the legacy signature scheme used
    /// in Bitcoin transactions (pre-Taproot) and throughout the wider cryptographic
    /// ecosystem. Use ``Signing/PrivateKey`` to sign and ``Signing/PublicKey`` to verify. Both
    /// accept `Digest` inputs for pre-hashed messages and `DataProtocol` inputs that are
    /// hashed with SHA-256 internally before the operation.
    ///
    /// Signatures are produced via `secp256k1_ecdsa_sign` with
    /// [RFC 6979](https://datatracker.ietf.org/doc/html/rfc6979) deterministic nonce
    /// generation and verified via `secp256k1_ecdsa_verify` (both declared in
    /// [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h)).
    /// Taproot-era signing uses ``P256K/Schnorr`` instead.
    ///
    /// ### Lower-S Normalization
    ///
    /// ECDSA signatures have a mathematical symmetry: `(r, s)` and `(r, -s mod n)` both
    /// verify against the same message/key pair. Bitcoin's
    /// [BIP-146](https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki) requires
    /// transactions to use the "low-S" form (where `s < n/2`) to prevent signature
    /// malleability. All signatures produced by this library are automatically normalized
    /// to lower-S; `secp256k1_ecdsa_verify` likewise only accepts lower-S signatures.
    ///
    /// ## Topics
    ///
    /// ### Key Types
    /// - ``PrivateKey``
    /// - ``PublicKey``
    /// - ``XonlyKey``
    ///
    /// ### Signature Types
    /// - ``ECDSASignature``
    enum Signing: Sendable {}
}
