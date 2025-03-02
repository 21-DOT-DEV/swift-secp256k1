//
//  DH.swift
//  GigaBitcoin/secp256k1.swift
//
//  Modifications Copyright (c) 2022 GigaBitcoin LLC
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

import Foundation

/// A protocol representing a Diffie-Hellman Key Agreement Key.
protocol DiffieHellmanKeyAgreement {
    /// The public key share type to perform the DH Key Agreement.
    associatedtype P
    /// The public key associated with this instance.
    var publicKey: P { get }

    /// Performs a Diffie-Hellman Key Agreement.
    ///
    /// - Parameter publicKeyShare: The public key share of the other party.
    /// - Returns: The resulting shared secret as a `SharedSecret` instance.
    /// - Throws: An error if the key agreement fails.
    func sharedSecretFromKeyAgreement(with publicKeyShare: P) throws -> SharedSecret
}

/// A Key Agreement Result.
///
/// A `SharedSecret` has to go through a Key Derivation Function before being able to use by a symmetric key operation.
public struct SharedSecret: ContiguousBytes {
    var ss: SecureBytes

    // An enum that represents the format of the shared secret
    let format: P256K.Format

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try ss.withUnsafeBytes(body)
    }
}

extension SharedSecret: Hashable {
    public func hash(into hasher: inout Hasher) {
        ss.withUnsafeBytes { hasher.combine(bytes: $0) }
    }
}

/// Extension providing constant-time comparison and custom string representation for `SharedSecret`.
extension SharedSecret: CustomStringConvertible, Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        safeCompare(lhs, rhs)
    }

    public static func == <D: DataProtocol>(lhs: Self, rhs: D) -> Bool {
        if rhs.regions.count != 1 {
            let rhsContiguous = Data(rhs)
            return safeCompare(lhs, rhsContiguous)
        } else {
            return safeCompare(lhs, rhs.regions.first!)
        }
    }

    /// A string representation of the `SharedSecret` object.
    public var description: String {
        "\(Self.self): \(ss.hexString)"
    }
}
