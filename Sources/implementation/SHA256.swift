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
import secp256k1_bindings

public struct SHA256 {
    /// Computes a digest of the data.
    /// - Parameter data: The data to be hashed
    /// - Returns: The computed digest
    public static func hash<D: DataProtocol>(data: D) -> SHA256Digest {
        let stringData = Array(data)
        var output = [UInt8](repeating: 0, count: 32)

        secp256k1_swift_sha256(&output, stringData, stringData.count)

        let first = output[0..<8].withUnsafeBytes { $0.load(as: UInt64.self) }
        let second = output[8..<16].withUnsafeBytes { $0.load(as: UInt64.self) }
        let third = output[16..<24].withUnsafeBytes { $0.load(as: UInt64.self) }
        let forth = output[24..<32].withUnsafeBytes { $0.load(as: UInt64.self) }

        return SHA256Digest(bytes: (first, second, third, forth))
    }
}
