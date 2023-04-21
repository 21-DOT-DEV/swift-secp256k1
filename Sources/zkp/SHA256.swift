//
//  SHA256.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

/// The SHA256 hashing algorithm.
public enum SHA256 {
    /// Computes a digest of the data.
    /// - Parameter data: The data to be hashed.
    /// - Returns: The computed digest.
    public static func hash<D: DataProtocol>(data: D) -> SHA256Digest {
        let stringData = Array(data)
        var output = [UInt8](repeating: 0, count: 32)

        secp256k1_swift_sha256(&output, stringData, stringData.count)

        return .init(output)
    }

    /// Computes a tagged hash of the data.
    /// - Parameters:
    ///   - tag: The tag to be used in the hash computation.
    ///   - data: The data to be hashed.
    /// - Throws: An error if the tagged hash computation fails.
    /// - Returns: The computed digest.
    public static func taggedHash<D: DataProtocol>(tag: D, data: D) throws -> SHA256Digest {
        let tagBytes = Array(tag)
        let messageBytes = Array(data)
        var output = [UInt8](repeating: 0, count: 32)

        guard secp256k1_tagged_sha256(secp256k1.Context.raw, &output, tagBytes, tagBytes.count, messageBytes, messageBytes.count).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return .init(output)
    }
}
