//
//  MuSig+Nonces.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

public import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

#if Xcode || ENABLE_MODULE_MUSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// The byte length of a serialized aggregated nonce.
        static let aggregatedNonceByteCount = 66

        /// Represents an aggregated nonce for MuSig operations.
        ///
        /// This struct is used in the MuSig multi-signature scheme to handle nonce aggregation.
        struct Nonce: ContiguousBytes, Sequence {
            /// The aggregated nonce data.
            let aggregatedNonce: Data

            /// Creates an aggregated nonce from a 66-byte serialized representation.
            ///
            /// This initializer parses a serialized aggregated nonce using the BIP-327 format.
            ///
            /// - Parameter dataRepresentation: A 66-byte serialized aggregated nonce.
            /// - Throws: An error if the data is invalid or parsing fails.
            public init<D: ContiguousBytes>(dataRepresentation: D) throws {
                let context = P256K.Context.rawRepresentation
                var aggnonce = secp256k1_musig_aggnonce()

                let bytes: [UInt8] = dataRepresentation.withUnsafeBytes { Array($0) }

                guard bytes.count == P256K.MuSig.aggregatedNonceByteCount,
                      secp256k1_musig_aggnonce_parse(context, &aggnonce, bytes).boolValue
                else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.aggregatedNonce = Swift.withUnsafeBytes(of: aggnonce) { Data($0) }
            }

            /// Creates an aggregated nonce from multiple public nonces.
            ///
            /// - Parameter pubnonces: An array of public nonces to aggregate.
            /// - Throws: An error if nonce aggregation fails.
            public init(aggregating pubnonces: [P256K.Schnorr.Nonce]) throws {
                let context = P256K.Context.rawRepresentation
                var aggNonce = secp256k1_musig_aggnonce()

                guard PointerArrayUtility.withUnsafePointerArray(
                    pubnonces.map {
                        var pubnonce = secp256k1_musig_pubnonce()
                        $0.pubnonce.copyToUnsafeMutableBytes(of: &pubnonce.data)
                        return pubnonce
                    }, { pointers in
                        secp256k1_musig_nonce_agg(context, &aggNonce, pointers, pointers.count).boolValue
                    }
                ) else {
                    throw secp256k1Error.underlyingCryptoError
                }

                self.aggregatedNonce = Data(Swift.withUnsafeBytes(of: aggNonce) { Data($0) })
            }

            /// Provides access to the raw bytes of the aggregated nonce.
            ///
            /// - Parameter body: A closure that takes an `UnsafeRawBufferPointer` and returns a value.
            /// - Returns: The value returned by the closure.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try aggregatedNonce.withUnsafeBytes(body)
            }

            /// Returns an iterator over the bytes of the aggregated nonce.
            ///
            /// - Returns: An iterator for the aggregated nonce data.
            public func makeIterator() -> Data.Iterator {
                aggregatedNonce.makeIterator()
            }

            /// A 66-byte data representation of the aggregated nonce in BIP-327 wire format.
            public var dataRepresentation: Data {
                let context = P256K.Context.rawRepresentation
                var aggnonce = secp256k1_musig_aggnonce()
                var output = [UInt8](repeating: 0, count: P256K.MuSig.aggregatedNonceByteCount)

                aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

                _ = secp256k1_musig_aggnonce_serialize(context, &output, &aggnonce)

                return Data(output)
            }

            /// Generates a nonce pair (secret and public) for MuSig signing.
            ///
            /// This function implements the nonce generation process as described in BIP-327.
            /// It is crucial to use a unique `sessionID` for each signing session to prevent nonce reuse.
            ///
            /// - Parameters:
            ///   - secretKey: The signer's secret key (optional).
            ///   - publicKey: The signer's public key.
            ///   - msg32: The 32-byte message to be signed.
            ///   - extraInput32: Optional 32-byte extra input to customize the nonce (can be nil).
            /// - Returns: A `NonceResult` containing the generated public and secret nonces.
            /// - Throws: An error if nonce generation fails.
            public static func generate(
                secretKey: P256K.Schnorr.PrivateKey?,
                publicKey: P256K.Schnorr.PublicKey,
                msg32: [UInt8],
                extraInput32: [UInt8]? = nil
            ) throws -> NonceResult {
                try generate(
                    sessionID: Array(SecureBytes(count: 133)),
                    secretKey: secretKey,
                    publicKey: publicKey,
                    msg32: msg32,
                    extraInput32: extraInput32
                )
            }

            /// Generates a nonce pair (secret and public) for MuSig signing.
            ///
            /// This function implements the nonce generation process as described in BIP-327.
            /// It is crucial to use a unique `sessionID` for each signing session to prevent nonce reuse.
            ///
            /// - Parameters:
            ///   - sessionID: A 32-byte unique session identifier.
            ///   - secretKey: The signer's secret key (optional).
            ///   - publicKey: The signer's public key.
            ///   - msg32: The 32-byte message to be signed.
            ///   - extraInput32: Optional 32-byte extra input to customize the nonce (can be nil).
            /// - Returns: A `NonceResult` containing the generated public and secret nonces.
            /// - Throws: An error if nonce generation fails.
            public static func generate(
                sessionID: [UInt8],
                secretKey: P256K.Schnorr.PrivateKey?,
                publicKey: P256K.Schnorr.PublicKey,
                msg32: [UInt8],
                extraInput32: [UInt8]?
            ) throws -> NonceResult {
                let context = P256K.Context.rawRepresentation
                var secnonce = secp256k1_musig_secnonce()
                var pubnonce = secp256k1_musig_pubnonce()
                var pubkey = publicKey.baseKey.rawRepresentation

                #if canImport(zkp_bindings)
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
                #else
                    var mutableSessionID = sessionID

                    guard secp256k1_musig_nonce_gen(
                        context,
                        &secnonce,
                        &pubnonce,
                        &mutableSessionID,
                        Array(secretKey!.dataRepresentation),
                        &pubkey,
                        msg32,
                        nil,
                        extraInput32
                    ).boolValue else {
                        throw secp256k1Error.underlyingCryptoError
                    }
                #endif

                return NonceResult(
                    pubnonce: P256K.Schnorr.Nonce(pubnonce: Swift.withUnsafeBytes(of: pubnonce) { Data($0) }),
                    secnonce: P256K.Schnorr.SecureNonce(Swift.withUnsafeBytes(of: secnonce) { Data($0) })
                )
            }
        }

        /// Represents the result of nonce generation, containing both public and secret nonces.
        @frozen struct NonceResult: ~Copyable {
            /// The public nonce.
            public let pubnonce: P256K.Schnorr.Nonce
            /// The secret nonce.
            public let secnonce: P256K.Schnorr.SecureNonce
        }
    }

#endif
