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
        /// Aggregates N secp256k1 public keys into a single MuSig2 aggregate public key via `secp256k1_musig_pubkey_agg`, sorting keys first with `secp256k1_ec_pubkey_sort` so the result is order-independent.
        ///
        /// The returned ``PublicKey`` includes the 197-byte `secp256k1_musig_keyagg_cache` needed
        /// for signing sessions and Taproot tweaking. Different orderings of the same multiset of
        /// public keys produce the same aggregate because keys are sorted before aggregation.
        ///
        /// - Parameter pubkeys: All signers' ``P256K/Schnorr/PublicKey`` values; must contain at least one key.
        /// - Returns: An aggregate ``PublicKey`` with an embedded key aggregation cache.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if sorting or aggregation fails.
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

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// 64-byte BIP-340 Schnorr signature produced by ``aggregateSignatures(_:)`` from all signers' ``P256K/Schnorr/PartialSignature`` values; verifiable against the MuSig2 aggregate public key.
        ///
        /// The aggregate signature is a standard BIP-340 Schnorr signature and verifies with
        /// `secp256k1_schnorrsig_verify` against the ``XonlyKey`` from ``aggregate(_:)``.
        /// Note: `secp256k1_musig_partial_sig_agg` returning `1` does **not** guarantee the
        /// resulting signature is valid — always verify with ``XonlyKey/isValidSignature(_:for:)``.
        struct AggregateSignature: ContiguousBytes, DataSignature {
            /// The 64-byte BIP-340 Schnorr signature (`R.x || s` in big-endian).
            public var dataRepresentation: Data

            /// Creates an ``AggregateSignature`` from a 64-byte raw representation.
            ///
            /// - Parameter dataRepresentation: Exactly 64 bytes in BIP-340 Schnorr signature format.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count is not 64.
            public init<D: DataProtocol>(dataRepresentation: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.signature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
            }

            /// Creates an ``AggregateSignature`` from a pre-validated 64-byte data value.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.signature` (64).
            init(_ dataRepresentation: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.signature, "Invalid aggregate signature size")
                self.dataRepresentation = dataRepresentation
            }

            /// Calls `body` with an unsafe pointer to the aggregate signature's 64 raw bytes.
            ///
            /// - Parameter body: A closure receiving a raw buffer pointer over the signature data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// Combines all signers' partial signatures into a final 64-byte ``AggregateSignature`` via `secp256k1_musig_partial_sig_agg`.
        ///
        /// A return value of `1` from the underlying C function does **not** guarantee the result
        /// verifies — always call ``XonlyKey/isValidSignature(_:for:)`` on the output to confirm
        /// the aggregate signature is valid against the aggregate public key.
        ///
        /// - Parameter partialSignatures: All signers' ``P256K/Schnorr/PartialSignature`` values; must include every participant's partial signature.
        /// - Returns: A 64-byte ``AggregateSignature`` that may be verified with `secp256k1_schnorrsig_verify`.
        /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `secp256k1_musig_partial_sig_agg` fails.
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

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// 36-byte MuSig2 partial signature produced by one signer via ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``; combined with all others by ``P256K/MuSig/aggregateSignatures(_:)``.
        ///
        /// Each signer produces one ``PartialSignature`` per signing session. The partial signature
        /// does **not** verify as a standalone signature; it only becomes valid after all partial
        /// signatures are aggregated into a ``P256K/MuSig/AggregateSignature``.
        struct PartialSignature: ContiguousBytes {
            /// The raw 36-byte `secp256k1_musig_partial_sig` data.
            public var dataRepresentation: Data
            /// The 133-byte `secp256k1_musig_session` state required for aggregation and verification.
            public var session: Data

            /// Creates a ``PartialSignature`` from raw partial signature bytes and session data.
            ///
            /// - Parameter dataRepresentation: The serialized partial signature data (36 bytes from `secp256k1_musig_partial_sig_serialize`).
            /// - Parameter session: The 133-byte `secp256k1_musig_session` state.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if the byte count does not match the expected partial signature length.
            public init<D: DataProtocol>(dataRepresentation: D, session: D) throws {
                guard dataRepresentation.count == P256K.ByteLength.partialSignature else {
                    throw secp256k1Error.incorrectParameterSize
                }

                self.dataRepresentation = Data(dataRepresentation)
                self.session = Data(session)
            }

            /// Creates a ``PartialSignature`` from pre-validated partial signature and session data.
            /// - Precondition: `dataRepresentation.count` must equal `P256K.ByteLength.partialSignature` (36).
            init(_ dataRepresentation: Data, session: Data) {
                precondition(dataRepresentation.count == P256K.ByteLength.partialSignature, "Invalid partial signature size")
                self.dataRepresentation = dataRepresentation
                self.session = session
            }

            /// Calls `body` with an unsafe pointer to the partial signature's raw bytes.
            ///
            /// - Parameter body: A closure receiving a raw buffer pointer over the signature data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }
        }
    }

#endif
