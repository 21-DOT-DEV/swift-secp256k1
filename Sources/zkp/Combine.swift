//
//  Combine.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2023 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

public extension secp256k1.Signing.PublicKey {
    /// Create a new `PublicKey` by combining the current public key with an array of public keys.
    /// - Parameters:
    ///   - pubkeys: the array of public key objects to be combined with
    ///   - format: the format of the combined `PublicKey` object
    /// - Returns: combined `PublicKey` object
    func combine(_ pubkeys: [Self], format: secp256k1.Format = .compressed) throws -> Self {
        let context = secp256k1.Context.rawRepresentation
        let allPubKeys = [self] + pubkeys
        var pubKeyLen = format.length
        var combinedKey = secp256k1_pubkey()
        var combinedBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard withUnsafePointersToPubKeys(allPubKeys.map { $0.rawRepresentation }, { ptrsToCombine in
            secp256k1_ec_pubkey_combine(context, &combinedKey, ptrsToCombine, ptrsToCombine.count).boolValue
        }), secp256k1_ec_pubkey_serialize(context, &combinedBytes, &pubKeyLen, &combinedKey, format.rawValue).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(dataRepresentation: combinedBytes, format: format)
    }
}

extension secp256k1.Signing.PublicKey {
    /// Executes a closure with an array of `UnsafePointer<secp256k1_pubkey>?` for pointer operations on an array of `secp256k1_pubkey`.
    /// - Parameters:
    ///   - pubKeys: An array of `secp256k1_pubkey` to be converted to `UnsafePointer<secp256k1_pubkey>?`.
    ///   - body: A closure that takes an array of `UnsafePointer<secp256k1_pubkey>?` and returns a result of type `Result`.
    /// - Returns: The result of the closure of type `Result`.
    func withUnsafePointersToPubKeys<Result>(
        _ pubKeys: [secp256k1_pubkey],
        _ body: ([UnsafePointer<secp256k1_pubkey>?]) -> Result
    ) -> Result {
        let pointers = pubKeys.map { pubKey -> UnsafePointer<secp256k1_pubkey>? in
            let mutablePubKey = UnsafeMutablePointer<secp256k1_pubkey>.allocate(capacity: 1)
            mutablePubKey.initialize(to: pubKey)
            return UnsafePointer(mutablePubKey)
        }

        defer {
            for ptr in pointers {
                ptr?.deallocate()
            }
        }

        return body(pointers)
    }
}
