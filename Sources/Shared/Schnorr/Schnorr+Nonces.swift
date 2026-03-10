//
//  Schnorr+Nonces.swift
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

#if Xcode || ENABLE_MODULE_MUSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// The byte length of a serialized public nonce.
        static let publicNonceByteCount = 66

        /// Represents a secure nonce used for MuSig operations.
        ///
        /// This struct is used to handle secure nonces in the MuSig signing process.
        /// It's crucial not to reuse nonces across different signing sessions to maintain security.
        struct SecureNonce: ~Copyable {
            let data: Data

            init(_ data: Data) {
                self.data = data
            }
        }

        /// Represents a public nonce used for MuSig operations.
        struct Nonce: ContiguousBytes, Sequence {
            /// The public nonce data.
            let pubnonce: Data

            /// Creates a public nonce from internal 132-byte representation.
            ///
            /// This initializer is used internally by nonce generation.
            ///
            /// - Parameter pubnonce: The internal public nonce data.
            init(pubnonce: Data) {
                self.pubnonce = pubnonce
            }

            /// Creates a public nonce from a 66-byte serialized representation.
            ///
            /// This initializer parses a serialized public nonce using the BIP-327 format.
            ///
            /// - Parameter dataRepresentation: A 66-byte serialized public nonce.
            /// - Throws: An error if the data is invalid or parsing fails.
            public init<D: ContiguousBytes>(dataRepresentation: D) throws {
                let context = P256K.Context.rawRepresentation
                var nonce = secp256k1_musig_pubnonce()

                let bytes: [UInt8] = dataRepresentation.withUnsafeBytes { Array($0) }

                guard bytes.count == P256K.Schnorr.publicNonceByteCount,
                      secp256k1_musig_pubnonce_parse(context, &nonce, bytes).boolValue
                else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.pubnonce = Swift.withUnsafeBytes(of: nonce) { Data($0) }
            }

            /// Provides access to the raw bytes of the public nonce.
            ///
            /// - Parameter body: A closure that takes an `UnsafeRawBufferPointer` and returns a value.
            /// - Returns: The value returned by the closure.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try pubnonce.withUnsafeBytes(body)
            }

            /// Returns an iterator over the bytes of the public nonce.
            ///
            /// - Returns: An iterator for the public nonce data.
            public func makeIterator() -> Data.Iterator {
                pubnonce.makeIterator()
            }

            /// A 66-byte data representation of the public nonce in BIP-327 wire format.
            public var dataRepresentation: Data {
                let context = P256K.Context.rawRepresentation
                var nonce = secp256k1_musig_pubnonce()
                var output = [UInt8](repeating: 0, count: P256K.Schnorr.publicNonceByteCount)

                pubnonce.copyToUnsafeMutableBytes(of: &nonce.data)

                _ = secp256k1_musig_pubnonce_serialize(context, &output, &nonce)

                return Data(output)
            }
        }
    }

#endif
