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
/// on a private key with the public key from another party, then access the
/// shared point's serialization via ``withUnsafeBytes(_:)`` — the 33-byte
/// compressed SEC1 form, or the 65-byte canonical encoding for secrets
/// produced by the deprecated `format:` variant's `.uncompressed` until its
/// removal. Read ``uncompressedRepresentation`` when a protocol requires the
/// 65-byte form.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public struct SharedSecret: ContiguousBytes, Sendable {
    /// The shared point record captured inside `secp256k1_ecdh`: the 33-byte
    /// compressed SEC1 serialization (`0x02`/`0x03` tag + X coordinate)
    /// followed by the 32-byte Y coordinate.
    ///
    /// Interior encoding, not a canonical SEC1 octet string — the 65-byte
    /// record leads with the *compressed* tag so ``withUnsafeBytes(_:)``'s
    /// `.compressed` view is the record's prefix rather than a derivation
    /// requiring fresh storage; the uncompressed views rewrite byte 0 to
    /// `0x04` inside the copies they already make.
    var point: SecureBytes

    /// Which serialization ``withUnsafeBytes(_:)`` exposes: `.compressed`
    /// (the record's 33-byte prefix) for secrets produced by
    /// `sharedSecretFromKeyAgreement(with:)` and the deprecated variant's
    /// `.compressed`; `.uncompressed` (the canonical `0x04‖x‖y` rebuild) only
    /// under the deprecated `format:` variant's `.uncompressed` — the tag
    /// retires with that shim at 1.0.
    var exposedForm: P256K.Format

    /// Internal initializer — `point` is the interior record described above
    /// (compressed tag + X + Y, 65 bytes), produced at capture time by
    /// `deriveSharedSecret`; test fixtures supply the same `tag‖x‖y` shape.
    init(point: SecureBytes, exposedForm: P256K.Format) {
        precondition(point.count == P256K.Format.uncompressed.length)
        self.point = point
        self.exposedForm = exposedForm
    }

    /// The 65-byte uncompressed serialization of the shared point (`0x04`
    /// prefix + 32-byte X + 32-byte Y).
    ///
    /// Every ``P256K/KeyAgreement/PrivateKey/sharedSecretFromKeyAgreement(with:)``
    /// call captures the point inside `secp256k1_ecdh`, while the
    /// coordinates upstream computes in constant time are still live — so this
    /// accessor copies the stored record and retags it `0x04`, never routing
    /// secret material back through `secp256k1_ec_pubkey_parse`'s variable-time
    /// decompression. The shared point itself has no format — serialization is
    /// a boundary choice, which is why the 65-byte form is an accessor rather
    /// than a derivation parameter.
    ///
    /// > Important: The returned `Data` copies the secret bytes out of the
    /// > zeroizing `SecureBytes` storage — copies made through this accessor are
    /// > **not** zeroed and must be handled by the caller, like
    /// > ``P256K/KeyAgreement/PrivateKey/rawRepresentation``.
    public var uncompressedRepresentation: Data {
        var uncompressed = Data(point)
        uncompressed[0] = 0x04
        return uncompressed
    }

    /// The canonical 65-byte `0x04‖x‖y` encoding rebuilt from the stored
    /// record — the `.uncompressed` exposed view's per-access materialization.
    private var uncompressedView: SecureBytes {
        var view = SecureBytes(bytes: point)
        view.withUnsafeMutableBytePointer { $0.pointee = 0x04 }
        return view
    }

    // Forwards a buffer covering the serialization `exposedForm` selects:
    // the record's 33-byte prefix for `.compressed` — a borrow, no copy —
    // or the canonical `0x04‖x‖y` rebuild for `.uncompressed`, materialized
    // into a per-access `SecureBytes` temp. Only deprecated-shim secrets
    // expose `.uncompressed`, so the allocation never touches the canonical
    // path — and secret material stays in `SecureBytes` storage either way.
    #if hasFeature(Embedded)
        func withExposedBytes<Result, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> Result) throws(E) -> Result {
            switch exposedForm {
            case .compressed:
                return try point.withUnsafeBytes { (record: UnsafeRawBufferPointer) throws(E) -> Result in
                    try body(UnsafeRawBufferPointer(start: record.baseAddress, count: P256K.Format.compressed.length))
                }

            case .uncompressed:
                return try uncompressedView.withUnsafeBytes(body)
            }
        }
    #else
        func withExposedBytes<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
            switch exposedForm {
            case .compressed:
                return try point.withUnsafeBytes { record in
                    try body(UnsafeRawBufferPointer(start: record.baseAddress, count: P256K.Format.compressed.length))
                }

            case .uncompressed:
                return try uncompressedView.withUnsafeBytes(body)
            }
        }
    #endif

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
            try withExposedBytes(body)
        }
    #else
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try withExposedBytes(body)
        }
    #endif
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension SharedSecret: Hashable {
    public func hash(into hasher: inout Hasher) {
        point.withUnsafeBytes { hasher.combine(bytes: $0) }
    }
}

/// We want to implement constant-time comparison for shared secrets.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension SharedSecret: Equatable {
    /// Shared secrets compare on the agreed point itself — the stored
    /// `tag‖x‖y` record — not the serialization ``withUnsafeBytes(_:)``
    /// exposes, so a canonical secret and one produced by the deprecated
    /// `format:` variant's `.uncompressed` compare equal when the two
    /// parties agreed on the same point. `SecureBytes`'s `safeCompare` keeps
    /// the record comparison constant-time, and every record is 65 bytes, so
    /// no length-mismatch early exit applies.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.point == rhs.point
    }

    /// Determines whether a shared secret's exposed serialization —
    /// the bytes ``withUnsafeBytes(_:)`` emits — is equivalent to a
    /// collection of contiguous bytes.
    ///
    /// - Parameters:
    ///   - lhs: The shared secret to compare.
    ///   - rhs: A collection of contiguous bytes to compare.
    ///
    /// - Returns: A Boolean value that's `true` if the shared secret's
    /// exposed serialization and the collection of binary data are
    /// equivalent.
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
        /// A redacted form reporting only the exposed view's byte count (33
        /// for ``P256K/Format/compressed``, 65 for
        /// ``P256K/Format/uncompressed``).
        ///
        /// The shared secret's bytes are never rendered — printing, interpolating,
        /// or logging this value cannot disclose the agreed key. Reach the bytes
        /// explicitly through ``withUnsafeBytes(_:)``.
        public var description: String {
            "\(Self.self) representation contains \(exposedForm.length) bytes."
        }
    }
#endif
