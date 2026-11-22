//
//  DH.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Modifications Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
//
//  NOTICE: THIS FILE HAS BEEN MODIFIED BY Timechain Software Initiative, Inc.
//  UNDER COMPLIANCE WITH THE APACHE 2.0 LICENSE FROM THE
//  ORIGINAL WORK OF THE COMPANY Apple Inc.
//
//  THE FOLLOWING IS THE COPYRIGHT OF THE ORIGINAL DOCUMENT:
//
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftCrypto open source project
//
// Copyright (c) 2019-2020 Apple Inc. and the SwiftCrypto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of SwiftCrypto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
#if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
    public import SwiftSystem
#else
    #if canImport(FoundationEssentials)
        public import FoundationEssentials
    #else
        public import Foundation
    #endif
#endif

/// A Diffie-Hellman Key Agreement Key
@preconcurrency
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
protocol DiffieHellmanKeyAgreement: Sendable {
    /// The public key share type to perform the DH Key Agreement
    associatedtype PublicKey: Sendable
    var publicKey: PublicKey { get }

    /// Performs a Diffie-Hellman Key Agreement.
    ///
    /// - Parameters:
    ///   - publicKeyShare: The public key share.
    /// - Returns: The resulting key agreement result.
    func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) -> SharedSecret
}

/// A key agreement result from which you can derive a symmetric cryptographic key.
///
/// Generate a shared secret by calling
/// ``P256K/KeyAgreement/PrivateKey/sharedSecretFromKeyAgreement(with:)``
/// on a private key with the public key from another party, then access the raw
/// serialized EC point via ``withUnsafeBytes(_:)``. The stored bytes are the
/// canonical 33-byte compressed SEC1 serialization of the shared point — or
/// the 65-byte encoding for secrets produced by the deprecated `format:`
/// variant's `.uncompressed` until its removal; read
/// ``uncompressedRepresentation`` when a protocol requires the 65-byte form.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public struct SharedSecret: ContiguousBytes, Sendable {
    /// The stored form ``withUnsafeBytes(_:)`` hands out: the 33-byte compressed
    /// SEC1 encoding for secrets produced by `sharedSecretFromKeyAgreement(with:)`
    /// (and the deprecated `format:` variant's `.compressed`), or the 65-byte
    /// encoding for its `.uncompressed` until that shim's removal.
    var ss: SecureBytes

    /// The 65-byte uncompressed SEC1 encoding of the shared point, captured inside
    /// `secp256k1_ecdh` while the point's coordinates are still constant-time
    /// live — carried by every constructible secret so
    /// ``uncompressedRepresentation`` is total.
    var uncompressed: SecureBytes

    /// Internal initializer — `secp256k1_ecdh`-produced secrets pass the capture;
    /// test fixtures must supply a 65-byte stand-in too.
    init(ss: SecureBytes, uncompressed: SecureBytes) {
        self.ss = ss
        self.uncompressed = uncompressed
    }

    /// The 65-byte uncompressed serialization of the shared point (`0x04`
    /// prefix + 32-byte X + 32-byte Y).
    ///
    /// Every ``P256K/KeyAgreement/PrivateKey/sharedSecretFromKeyAgreement(with:)``
    /// call captures the uncompressed encoding inside `secp256k1_ecdh`, while the
    /// coordinates upstream computes in constant time are still live — so this
    /// accessor copies captured bytes and never routes secret material back
    /// through `secp256k1_ec_pubkey_parse`'s variable-time decompression. The
    /// shared point itself has no format — serialization is a boundary choice,
    /// which is why the 65-byte form is an accessor rather than a derivation
    /// parameter. Secrets produced by the deprecated `format:` variant may store
    /// 65 bytes until its removal; ``withUnsafeBytes(_:)`` returns the stored
    /// form in both cases.
    ///
    /// > Important: The returned `Data` copies the secret bytes out of the
    /// > zeroizing `SecureBytes` storage — copies made through this accessor are
    /// > **not** zeroed and must be handled by the caller, like
    /// > ``P256K/KeyAgreement/PrivateKey/rawRepresentation``.
    public var uncompressedRepresentation: Data {
        Data(uncompressed)
    }

    // Invokes the given closure with a buffer pointer covering the raw bytes
    // of the shared secret.
    //
    // - Parameters:
    //   - body: A closure that takes a raw buffer pointer to the bytes of the
    // shared secret and returns the shared secret.
    //
    // - Returns: The shared secret, as returned from the body closure.
    #if hasFeature(Embedded)
        public func withUnsafeBytes<R, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
            try ss.withUnsafeBytes(body)
        }
    #else
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try ss.withUnsafeBytes(body)
        }
    #endif
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension SharedSecret: Hashable {
    public func hash(into hasher: inout Hasher) {
        ss.withUnsafeBytes { hasher.combine(bytes: $0) }
    }
}

/// We want to implement constant-time comparison for shared secrets.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension SharedSecret: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        safeCompare(lhs, rhs)
    }

    /// Determines whether a shared secret is equivalent to a collection of
    /// contiguous bytes.
    ///
    /// - Parameters:
    ///   - lhs: The shared secret to compare.
    ///   - rhs: A collection of contiguous bytes to compare.
    ///
    /// - Returns: A Boolean value that's `true` if the shared secret and the
    /// collection of binary data are equivalent.
    public static func == <D: DataProtocol>(lhs: Self, rhs: D) -> Bool {
        if rhs.regions.count == 1, let region = rhs.regions.first {
            return safeCompare(lhs, region)
        }

        return safeCompare(lhs, Data(rhs))
    }
}

#if !hasFeature(Embedded)
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension SharedSecret: CustomStringConvertible {
        /// A redacted form reporting only the stored byte count (33 for
        /// ``P256K/Format/compressed``, 65 for ``P256K/Format/uncompressed``).
        ///
        /// The shared secret's bytes are never rendered — printing, interpolating,
        /// or logging this value cannot disclose the agreed key. Reach the bytes
        /// explicitly through ``withUnsafeBytes(_:)``.
        public var description: String {
            "\(Self.self) representation contains \(ss.count) bytes."
        }
    }
#endif
