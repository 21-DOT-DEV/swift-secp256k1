//
//  MuSig+Aggregate.swift
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

    // MARK: - secp256k1 + MuSig

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// Aggregates multiple Schnorr public keys into a single Schnorr public key using the MuSig algorithm.
        ///
        /// This function implements the key aggregation process as described in BIP-327.
        ///
        /// - Parameter pubkeys: An array of Schnorr public keys to aggregate.
        /// - Returns: The aggregated Schnorr public key.
        /// - Throws: An error if aggregation fails.
        static func aggregate(_ pubkeys: [P256K.Schnorr.PublicKey]) throws -> P256K.MuSig.PublicKey {
            let context = P256K.Context.rawRepresentation
            let format = P256K.Format.compressed
            var pubKeyLen = format.length
            var aggPubkey = secp256k1_pubkey()
            var cache = secp256k1_musig_keyagg_cache()
            var pubBytes = [UInt8](repeating: 0, count: pubKeyLen)

            guard PointerArrayUtility
                .withUnsafePointerArray(pubkeys.map { $0.baseKey.rawRepresentation }, { pointers in
                    secp256k1_ec_pubkey_sort(context, &pointers, pointers.count).boolValue &&
                        secp256k1_musig_pubkey_agg(context, nil, &cache, pointers, pointers.count).boolValue
                }), secp256k1_musig_pubkey_get(context, &aggPubkey, &cache).boolValue,
                secp256k1_ec_pubkey_serialize(
                    context,
                    &pubBytes,
                    &pubKeyLen,
                    &aggPubkey,
                    format.rawValue
                ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return P256K.MuSig.PublicKey(
                baseKey: PublicKeyImplementation(
                    validatedBytes: pubBytes,
                    format: format,
                    cache: Swift.withUnsafeBytes(of: cache.data) { [UInt8]($0) }
                )
            )
        }
    }

    /// A Schnorr (Schnorr Digital Signature Scheme) Signature
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        struct AggregateSignature: ContiguousBytes, DataSignature {
            /// Returns the raw signature in a fixed 64-byte format.
            public var dataRepresentation: Data

            /// Initializes SchnorrSignature from the raw representation.
            /// - Parameters:
            ///     - dataRepresentation: A raw representation of the key as a collection of contiguous bytes.
            /// - Throws: If there is a failure with the rawRepresentation count
            public init<D: DataProtocol>(dataRepresentation: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
            }

            /// Initializes AggregateSignature from the raw representation.
            /// - Parameters:
            ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature`.
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature, "Invalid aggregate signature size")
                self.dataRepresentation = dataRepresentation
            }

            /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
            /// - Parameters:
            ///     - body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
            /// - Throws: If there is a failure with underlying `withUnsafeBytes`
            /// - Returns: The signature as returned from the body closure.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// Aggregates partial signatures into a complete signature.
        ///
        /// - Parameter partialSignatures: An array of partial signatures to aggregate.
        /// - Returns: The aggregated Schnorr signature.
        /// - Throws: If there is a failure aggregating the signatures.
        static func aggregateSignatures(
            _ partialSignatures: [P256K.Schnorr.PartialSignature]
        ) throws -> P256K.MuSig.AggregateSignature {
            let context = P256K.Context.rawRepresentation
            var signature = [UInt8](repeating: 0, count: P256K.ByteLength.signature)
            var session = secp256k1_musig_session()

            partialSignatures.first?.session.copyToUnsafeMutableBytes(of: &session.data)

            guard PointerArrayUtility.withUnsafePointerArray(
                partialSignatures.map {
                    var partialSig = secp256k1_musig_partial_sig()
                    _ = secp256k1_musig_partial_sig_parse(context, &partialSig, Array($0.dataRepresentation))
                    return partialSig
                }, { pointers in
                    secp256k1_musig_partial_sig_agg(context, &signature, &session, pointers, pointers.count).boolValue
                }
            ) else {
                throw secp256k1Error.underlyingCryptoError
            }

            return P256K.MuSig.AggregateSignature(Data(signature))
        }
    }

    // MARK: - PartialSignature

    /// A Schnorr (Schnorr Digital Signature Scheme) Signature
    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        struct PartialSignature: ContiguousBytes {
            /// Returns the raw signature in a fixed 64-byte format.
            public var dataRepresentation: Data
            ///  Returns the MuSig Session  in a fixed 133-byte format.
            public var session: Data

            /// Creates a partial signature from raw data.
            ///
            /// - Parameters:
            ///   - dataRepresentation: The raw partial signature data.
            ///   - session: The MuSig session data.
            /// - Throws: An error if the data is invalid.
            public init<D: DataProtocol>(dataRepresentation: D, session: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
                self.session = Data(session)
            }

            /// Initializes PartialSignature from the raw representation.
            /// - Parameters:
            ///     - rawRepresentation: A raw representation of the key as a collection of contiguous bytes.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.partialSignature`.
            init(_ dataRepresentation: Data, session: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.partialSignature, "Invalid partial signature size")
                self.dataRepresentation = dataRepresentation
                self.session = session
            }

            /// Provides access to the raw bytes of the partial signature.
            ///
            /// - Parameter body: A closure that takes an `UnsafeRawBufferPointer` and returns a value.
            /// - Returns: The value returned by the closure.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

#endif
