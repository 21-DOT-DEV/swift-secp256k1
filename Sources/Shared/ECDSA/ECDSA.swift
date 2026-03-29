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

typealias NISTECDSASignature = DERSignature & DataSignature

protocol DataSignature {
    init<D: DataProtocol>(dataRepresentation: D) throws
    var dataRepresentation: Data { get }
}

protocol DERSignature {
    init<D: DataProtocol>(derRepresentation: D) throws
    var derRepresentation: Data { get }
}

protocol CompactSignature {
    init<D: DataProtocol>(compactRepresentation: D) throws
    var compactRepresentation: Data { get }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// secp256k1 ECDSA signing namespace providing ``PrivateKey`` for RFC 6979 deterministic signing and ``PublicKey`` for signature verification; all produced signatures are lower-S normalized.
    ///
    /// ECDSA (Elliptic Curve Digital Signature Algorithm) is the signature scheme used in Bitcoin
    /// transactions and compatible with a wide range of cryptographic infrastructure. Use
    /// ``Signing/PrivateKey`` to sign and ``Signing/PublicKey`` to verify. Both accept `Digest`
    /// inputs for pre-hashed messages and `DataProtocol` inputs that are hashed with SHA-256
    /// internally before the operation.
    enum Signing: Sendable {}
}
