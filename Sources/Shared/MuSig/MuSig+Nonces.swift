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
        /// The byte length of a serialized MuSig2 aggregated nonce: 66 bytes (two 33-byte compressed points in BIP-327 wire format).
        static let aggregatedNonceByteCount = 66

        /// 66-byte aggregated MuSig2 public nonce produced by `secp256k1_musig_nonce_agg` from all signers' individual public nonces, required before any partial signing can occur.
        ///
        /// The aggregated nonce is computed once from all signers' ``P256K/Schnorr/Nonce`` values
        /// and then shared with every signer before they call
        /// ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``.
        /// An untrusted aggregator may compute the aggregate nonce; if the result is wrong, the
        /// final signature will simply be invalid rather than leaking key material.
        struct Nonce: ContiguousBytes, Sequence {
            /// The raw 66-byte `secp256k1_musig_aggnonce` struct bytes.
            let aggregatedNonce: Data

            /// Creates a MuSig2 aggregated nonce from its 66-byte BIP-327 wire representation via `secp256k1_musig_aggnonce_parse`.
            ///
            /// - Parameter dataRepresentation: Exactly 66 bytes in BIP-327 aggregated nonce format.
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the byte count is not 66 or parsing fails.
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

            /// Creates a MuSig2 aggregated nonce by combining all signers' public nonces via `secp256k1_musig_nonce_agg`.
            ///
            /// This step may be performed by any party (including an untrusted aggregator). If the
            /// aggregate is computed incorrectly, the final signature will be invalid but no key
            /// material is leaked.
            ///
            /// - Parameter pubnonces: All signers' ``P256K/Schnorr/Nonce`` public nonces; must include every participant.
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `secp256k1_musig_nonce_agg` fails.
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

            /// Calls `body` with an unsafe pointer to the aggregated nonce's raw bytes.
            ///
            /// - Parameter body: A closure receiving an `UnsafeRawBufferPointer` over the nonce data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try aggregatedNonce.withUnsafeBytes(body)
            }

            /// Returns an iterator over the 66 bytes of the aggregated nonce.
            public func makeIterator() -> Data.Iterator {
                aggregatedNonce.makeIterator()
            }

            /// The 66-byte BIP-327 wire representation of the aggregated nonce, serialized via `secp256k1_musig_aggnonce_serialize`.
            public var dataRepresentation: Data {
                let context = P256K.Context.rawRepresentation
                var aggnonce = secp256k1_musig_aggnonce()
                var output = [UInt8](repeating: 0, count: P256K.MuSig.aggregatedNonceByteCount)

                aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

                _ = secp256k1_musig_aggnonce_serialize(context, &output, &aggnonce)

                return Data(output)
            }

            /// Generates a fresh nonce pair for one MuSig2 signing session using a random 133-byte session ID.
            ///
            /// > Warning: **Nonce reuse leaks the secret signing key.** This overload generates the
            /// > session ID internally from `SecureBytes`. Never reuse a ``P256K/Schnorr/SecureNonce``
            /// > across multiple signing sessions. The returned ``NonceResult`` is `~Copyable` to
            /// > prevent accidental duplication of the secret nonce.
            ///
            /// - Parameter secretKey: The signer's private key; providing it increases misuse-resistance by binding the nonce to the key.
            /// - Parameter publicKey: The signer's public key; the generated secret nonce is bound to this key and cannot sign for any other.
            /// - Parameter msg32: The 32-byte message to be signed, if known at nonce generation time.
            /// - Parameter extraInput32: Optional 32 bytes of additional entropy (e.g., current timestamp) passed to `secp256k1_musig_nonce_gen`.
            /// - Returns: A `~Copyable` ``NonceResult`` containing the public nonce (to share) and secret nonce (to consume when signing).
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `secp256k1_musig_nonce_gen` fails.
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

            /// Generates a fresh nonce pair for one MuSig2 signing session using a caller-supplied session ID.
            ///
            /// > Warning: **Nonce reuse leaks the secret signing key.** The `sessionID` **must be
            /// > unique** across all calls to this function — it is consumed (zeroed) by
            /// > `secp256k1_musig_nonce_gen` to prevent reuse at the C level. Never store or
            /// > serialize the secret nonce. The returned ``NonceResult`` is `~Copyable`.
            ///
            /// - Parameter sessionID: Uniformly random bytes used as `session_secrand32`; must never repeat. Invalidated after the call.
            /// - Parameter secretKey: The signer's private key; providing it increases misuse-resistance.
            /// - Parameter publicKey: The signer's public key; the secret nonce is bound to this key.
            /// - Parameter msg32: The 32-byte message to sign, if known at nonce generation time.
            /// - Parameter extraInput32: Optional 32 bytes of additional entropy passed to `secp256k1_musig_nonce_gen`.
            /// - Returns: A `~Copyable` ``NonceResult`` with the public nonce (to share) and secret nonce (to consume).
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if `secp256k1_musig_nonce_gen` fails.
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

        /// The output of ``Nonce/generate(secretKey:publicKey:msg32:extraInput32:)``: a public nonce to share with co-signers and a secret nonce to consume exactly once when signing.
        ///
        /// This type is `~Copyable` to prevent accidental duplication of the secret nonce. Copying
        /// the secret nonce bytes and using them twice would leak the signing key (nonce reuse).
        @frozen struct NonceResult: ~Copyable {
            /// The 66-byte public nonce to broadcast to all co-signers before aggregation.
            public let pubnonce: P256K.Schnorr.Nonce
            /// The secret nonce to pass exactly once to ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``.
            public let secnonce: P256K.Schnorr.SecureNonce
        }
    }

#endif
