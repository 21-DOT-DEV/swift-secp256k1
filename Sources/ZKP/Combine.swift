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

#if canImport(libsecp256k1_zkp)
    @_implementationOnly import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    @_implementationOnly import libsecp256k1
#endif

public extension P256K.Signing.PublicKey {
    /// Create a new `PublicKey` by combining the current public key with an array of public keys.
    /// - Parameters:
    ///   - pubkeys: the array of public key objects to be combined with
    ///   - format: the format of the combined `PublicKey` object
    /// - Returns: combined `PublicKey` object
    func combine(_ pubkeys: [Self], format: P256K.Format = .compressed) throws -> Self {
        let context = P256K.Context.rawRepresentation
        let allPubKeys = [self] + pubkeys
        var pubKeyLen = format.length
        var combinedKey = secp256k1_pubkey()
        var combinedBytes = [UInt8](repeating: 0, count: pubKeyLen)

        guard PointerArrayUtility
            .withUnsafePointerArray(allPubKeys.map { $0.baseKey.rawRepresentation }, { pointers in
                secp256k1_ec_pubkey_combine(context, &combinedKey, pointers, pointers.count).boolValue
            }), secp256k1_ec_pubkey_serialize(context, &combinedBytes, &pubKeyLen, &combinedKey, format.rawValue).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try Self(dataRepresentation: combinedBytes, format: format)
    }
}
