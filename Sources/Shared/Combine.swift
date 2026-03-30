//
//  Combine.swift
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

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing.PublicKey {
    /// Creates a new ``PublicKey`` by adding this key together with `pubkeys` via `secp256k1_ec_pubkey_combine`, equivalent to point addition on the secp256k1 curve.
    ///
    /// Point addition is the basis for unhardened BIP-32 child public key derivation and for
    /// constructing multisig output keys without revealing individual private keys. The result
    /// equals `G × (sk₀ + sk₁ + … + skₙ)` if each input key was derived from its corresponding
    /// private key, making it useful for verifying that a set of keys sums to a known aggregate.
    ///
    /// - Parameter pubkeys: Additional ``PublicKey`` values to combine with this key; must contain at least one key.
    /// - Parameter format: The serialization format of the returned ``PublicKey``; defaults to `.compressed`.
    /// - Returns: A new ``PublicKey`` equal to the elliptic-curve sum of all input keys.
    /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `secp256k1_ec_pubkey_combine` fails (e.g., all keys cancel to the point at infinity).
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

        return Self(baseKey: PublicKeyImplementation(validatedBytes: combinedBytes, format: format))
    }
}
