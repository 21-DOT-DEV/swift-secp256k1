//
//  Nonces.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2024 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

public extension secp256k1.MuSig {
    /// Represents an aggregated nonce for MuSig operations.
    struct Nonce: ContiguousBytes, Sequence {
        let aggregatedNonce: Data

        /// Creates an aggregated nonce from multiple public nonces.
        ///
        /// - Parameter pubnonces: An array of public nonces to aggregate.
        /// - Throws: An error if nonce aggregation fails.
        public init(aggregating pubnonces: [Data]) throws {
            let context = secp256k1.Context.rawRepresentation
            var aggNonce = secp256k1_musig_aggnonce()

            guard PointerArrayUtility.withUnsafePointerArray(
                pubnonces.map {
                    var pubnonce = secp256k1_musig_pubnonce()
                    $0.copyToUnsafeMutableBytes(of: &pubnonce.data)
                    return pubnonce
                }, { pointers in
                    secp256k1_musig_nonce_agg(context, &aggNonce, pointers, pointers.count).boolValue
                }) else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.aggregatedNonce = Data(Swift.withUnsafeBytes(of: aggNonce) { Data($0) })
        }

        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            return try aggregatedNonce.withUnsafeBytes(body)
        }

        public func makeIterator() -> Data.Iterator {
            return aggregatedNonce.makeIterator()
        }
    }
}

public extension secp256k1.Schnorr {
    /// A value used once during a cryptographic operation and then discarded.
    ///
    /// Don't reuse the same nonce for multiple calls to signing APIs. It's critical
    /// that nonces are unique per call to signing APIs in order to protect the
    /// integrity of the signature.
    struct Nonce: ContiguousBytes, Sequence {
        let secnonce: Data
        let pubnonce: Data

        /// Creates a new random nonce using secp256k1_musig_nonce_gen.
        ///
        /// - Parameters:
        ///   - secretKey: The signer's 32-byte secret key.
        ///   - publicKey: The signer's Schnorr public key.
        ///   - msg32: The 32-byte message hash to be signed.
        ///   - extraInput32: Optional 32-byte extra input to customize the nonce.
        /// - Throws: An error if nonce generation fails.
        public init(
            secretKey: secp256k1.Schnorr.PrivateKey?,
            publicKey: secp256k1.Schnorr.PublicKey,
            msg32: [UInt8],
            extraInput32: [UInt8]? = nil
        ) throws {
            let sessionID = SecureBytes(count: secp256k1.ByteLength.privateKey)

            try self.init(
                sessionID: Array(sessionID),
                secretKey: secretKey,
                publicKey: publicKey,
                msg32: msg32,
                extraInput32: extraInput32
            )
        }

        /// Creates a new random nonce using secp256k1_musig_nonce_gen.
        ///
        /// - Parameters:
        ///   - sessionID: A unique 32-byte session ID.
        ///   - secretKey: The signer's 32-byte secret key.
        ///   - publicKey: The signer's Schnorr public key.
        ///   - msg32: The 32-byte message hash to be signed.
        ///   - extraInput32: Optional 32-byte extra input to customize the nonce.
        /// - Throws: An error if nonce generation fails.
        public init(
            sessionID: [UInt8],
            secretKey: secp256k1.Schnorr.PrivateKey?,
            publicKey: secp256k1.Schnorr.PublicKey,
            msg32: [UInt8],
            extraInput32: [UInt8]? = nil
        ) throws {
            let context = secp256k1.Context.rawRepresentation
            var secnonce = secp256k1_musig_secnonce()
            var pubnonce = secp256k1_musig_pubnonce()
            var pubkey = publicKey.rawRepresentation

            guard secp256k1_musig_nonce_gen(
                context,
                &secnonce,
                &pubnonce,
                sessionID,
                Array(secretKey!.dataRepresentation),
                &pubkey,
                msg32,
                nil,
                extraInput32
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.secnonce = Data(Swift.withUnsafeBytes(of: secnonce) { Data($0) })
            self.pubnonce = Data(Swift.withUnsafeBytes(of: pubnonce) { Data($0) })
        }

        /// Calls the given closure with a pointer to the underlying bytes of the public nonce.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            return try pubnonce.withUnsafeBytes(body)
        }

        /// Returns an iterator over the elements of the public nonce.
        public func makeIterator() -> Data.Iterator {
            return pubnonce.makeIterator()
        }
    }
}
