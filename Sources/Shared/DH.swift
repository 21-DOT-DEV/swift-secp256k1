//
//  DH.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Modifications Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
//
//  NOTICE: THIS FILE HAS BEEN MODIFIED BY GigaBitcoin LLC
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
#if CRYPTO_IN_SWIFTPM && !CRYPTO_IN_SWIFTPM_FORCE_BUILD_API
    @_exported import CryptoKit
#else

    #if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
        import SwiftSystem
    #else
        #if canImport(FoundationEssentials)
            import FoundationEssentials
        #else
            import Foundation
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
        func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) throws -> SharedSecret
    }

    /// A key agreement result from which you can derive a symmetric cryptographic
    /// key.
    ///
    /// Generate a shared secret by calling your private key's
    /// `sharedSecretFromKeyAgreement(publicKeyShare:)` method with the public key
    /// from another party.
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public struct SharedSecret: ContiguousBytes, Sendable {
        var ss: SecureBytes

        // secp256k1: An enum that represents the format of the shared secret
        let format: P256K.Format

        /// Invokes the given closure with a buffer pointer covering the raw bytes
        /// of the shared secret.
        ///
        /// - Parameters:
        ///   - body: A closure that takes a raw buffer pointer to the bytes of the
        /// shared secret and returns the shared secret.
        ///
        /// - Returns: The shared secret, as returned from the body closure.
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

    // We want to implement constant-time comparison for shared secrets.
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
            if rhs.regions.count != 1 {
                let rhsContiguous = Data(rhs)
                return safeCompare(lhs, rhsContiguous)
            } else {
                return safeCompare(lhs, rhs.regions.first!)
            }
        }
    }

    #if !hasFeature(Embedded)
        @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
        extension SharedSecret: CustomStringConvertible {
            public var description: String {
                "\(Self.self): \(ss.hexString)"
            }
        }
    #endif

#endif // Linux or !SwiftPM
