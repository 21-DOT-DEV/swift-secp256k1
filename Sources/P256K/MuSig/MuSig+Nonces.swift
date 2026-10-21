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
import libsecp256k1

#if Xcode || ENABLE_MODULE_MUSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.MuSig {
        /// The byte length of a serialized MuSig2 aggregated nonce: 66 bytes (two 33-byte compressed points in BIP-327 wire format).
        static let aggregatedNonceByteCount = 66

        /// 66-byte aggregated MuSig2 public nonce produced by `secp256k1_musig_nonce_agg`
        /// from all signers' individual public nonces, required before any partial signing
        /// can occur.
        ///
        /// ## Overview
        ///
        /// Aggregation is specified in
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki) and
        /// implemented in
        /// [`secp256k1/include/secp256k1_musig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_musig.h).
        /// The aggregated nonce is computed once from all signers' ``P256K/Schnorr/Nonce``
        /// values and then shared with every signer before they call
        /// ``P256K/Schnorr/PrivateKey/partialSignature(for:pubnonce:secureNonce:publicNonceAggregate:xonlyKeyAggregate:)``.
        /// An untrusted aggregator may compute the aggregate nonce; if the result is wrong,
        /// the final signature will simply be invalid rather than leaking key material.
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:)``
        /// - ``init(aggregating:)``
        /// - ``generate(secretKey:publicKey:msg32:extraInput32:)``
        /// - ``generate(sessionSecretRand:secretKey:publicKey:msg32:extraInput32:)``
        ///
        /// ### Serialization
        /// - ``dataRepresentation``
        struct Nonce: ContiguousBytes, Sequence {
            /// The raw `secp256k1_musig_aggnonce` struct bytes (132 bytes); parse-validated
            /// at construction or produced by `secp256k1_musig_nonce_agg`.
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
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `pubnonces` is empty —
            ///   upstream `ARG_CHECK`s `n_pubnonces > 0`, which aborts the process;
            ///   ``secp256k1Error/underlyingCryptoError`` if `secp256k1_musig_nonce_agg` fails.
            public init(aggregating pubnonces: [P256K.Schnorr.Nonce]) throws {
                let context = P256K.Context.rawRepresentation
                var aggNonce = secp256k1_musig_aggnonce()

                guard pubnonces.isEmpty == false else {
                    throw secp256k1Error.incorrectParameterSize
                }

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

            /// Calls `body` with an unsafe pointer to the 66-byte BIP-327 wire form —
            /// the same bytes ``dataRepresentation`` returns.
            ///
            /// - Parameter body: A closure receiving an `UnsafeRawBufferPointer` over the nonce data.
            /// - Returns: The value returned by `body`.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try dataRepresentation.withUnsafeBytes(body)
            }

            /// Returns an iterator over the 66-byte BIP-327 wire form of the aggregated nonce.
            public func makeIterator() -> Data.Iterator {
                dataRepresentation.makeIterator()
            }

            /// The 66-byte BIP-327 wire representation of the aggregated nonce, serialized via `secp256k1_musig_aggnonce_serialize`.
            public var dataRepresentation: Data {
                let context = P256K.Context.rawRepresentation
                var aggnonce = secp256k1_musig_aggnonce()
                var output = [UInt8](repeating: 0, count: P256K.MuSig.aggregatedNonceByteCount)

                aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

                // `aggregatedNonce` was produced upstream (nonce_agg or a
                // successful parse), so the load inside serialize cannot fail.
                precondition(
                    secp256k1_musig_aggnonce_serialize(context, &output, &aggnonce).boolValue,
                    "secp256k1_musig_aggnonce_serialize failed on upstream-produced nonce — library bug"
                )

                return Data(output)
            }

            /// Generates a fresh nonce pair for one MuSig2 signing session with internally generated session randomness.
            ///
            /// > Warning: **Nonce reuse leaks the secret signing key.** This overload generates a
            /// > fresh ``SessionSecretRand`` internally — the recommended path per BIP-327, which
            /// > requires a fresh uniformly random value per session. Never reuse a
            /// > ``P256K/Schnorr/SecureNonce`` across multiple signing sessions. The returned
            /// > ``NonceResult`` is `~Copyable` to prevent accidental duplication of the secret nonce.
            ///
            /// - Parameter secretKey: The signer's private key; providing it increases misuse-resistance by binding the nonce to the key.
            /// - Parameter publicKey: The signer's public key; the generated secret nonce is bound to this key and cannot sign for any other.
            /// - Parameter msg32: The message to be signed; `nil` if not yet known. Any length is
            ///   accepted — the bytes are reduced to the 32-byte `msg32` value per SEC1 §4.1.3
            ///   (leftmost 32 bytes for longer inputs, integer value for shorter).
            ///   Providing it binds the nonce to the message, increasing misuse-resistance.
            /// - Parameter extraInput32: Optional 32 bytes of additional entropy (e.g., current timestamp) passed to `secp256k1_musig_nonce_gen`.
            /// - Returns: A `~Copyable` ``NonceResult`` containing the public nonce (to share) and secret nonce (to consume when signing).
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `extraInput32` is
            ///   present but not exactly 32 bytes; ``secp256k1Error/underlyingCryptoError`` if
            ///   `secp256k1_musig_nonce_gen` fails.
            public static func generate(
                secretKey: P256K.Schnorr.PrivateKey?,
                publicKey: P256K.Schnorr.PublicKey,
                msg32: [UInt8]?,
                extraInput32: [UInt8]? = nil
            ) throws -> NonceResult {
                try generate(
                    sessionSecretRand: SessionSecretRand(),
                    secretKey: secretKey,
                    publicKey: publicKey,
                    msg32: msg32,
                    extraInput32: extraInput32
                )
            }

            /// Generates a fresh nonce pair for one MuSig2 signing session using a caller-supplied ``SessionSecretRand``.
            ///
            /// > Warning: **Nonce reuse leaks the secret signing key.** Each ``SessionSecretRand``
            /// > must be used for exactly one call — the value is consumed, so reuse is prevented
            /// > at compile time by the type's `~Copyable` conformance rather than relying on the
            /// > caller to discard the bytes. `secp256k1_musig_nonce_gen` additionally zeroes the
            /// > value's own `SecureBytes` buffer in place on success. Never store or serialize the secret nonce. The
            /// > returned ``NonceResult`` is `~Copyable`.
            ///
            /// - Parameter sessionSecretRand: Secret, uniformly random session input consumed by this call — see ``SessionSecretRand``.
            /// - Parameter secretKey: The signer's private key; providing it increases misuse-resistance.
            /// - Parameter publicKey: The signer's public key; the secret nonce is bound to this key.
            /// - Parameter msg32: The message to sign; `nil` if not yet known. Any length is
            ///   accepted — the bytes are reduced to the 32-byte `msg32` value per SEC1 §4.1.3
            ///   (leftmost 32 bytes for longer inputs, integer value for shorter).
            ///   Providing it binds the nonce to the message, increasing misuse-resistance.
            /// - Parameter extraInput32: Optional 32 bytes of additional entropy passed to `secp256k1_musig_nonce_gen`.
            /// - Returns: A `~Copyable` ``NonceResult`` with the public nonce (to share) and secret nonce (to consume).
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `extraInput32` is
            ///   present but not exactly 32 bytes; ``secp256k1Error/underlyingCryptoError`` if
            ///   `secp256k1_musig_nonce_gen` fails.
            public static func generate(
                sessionSecretRand: consuming SessionSecretRand,
                secretKey: P256K.Schnorr.PrivateKey?,
                publicKey: P256K.Schnorr.PublicKey,
                msg32: [UInt8]?,
                extraInput32: [UInt8]?
            ) throws -> NonceResult {
                let context = P256K.Context.rawRepresentation
                var secnonce = secp256k1_musig_secnonce()
                var pubnonce = secp256k1_musig_pubnonce()
                var pubkey = publicKey.baseKey.rawRepresentation
                let msg32Bytes = msg32?.msg32Bytes

                if let extraInput32, extraInput32.count != P256K.ByteLength.dimension {
                    throw secp256k1Error.incorrectParameterSize
                }

                // `sessionSecretRand` holds the only `SecureBytes` reference (the type is
                // `~Copyable`), so `withUnsafeMutableBytes` yields a pointer into its own
                // buffer — upstream zeroes that storage in place on success, and the
                // `SecureBytes` backing `memset_s`-zeroes it on release either way.
                let nonceGenerated = try sessionSecretRand.bytes.withUnsafeMutableBytes { rand -> Bool in
                    guard let sessionSecrand = rand.bindMemory(to: UInt8.self).baseAddress else {
                        throw secp256k1Error.underlyingCryptoError
                    }
                    // Read the secret key from its `SecureBytes` backing rather than
                    // copying into a temporary array that would be freed unzeroed.
                    if let secretKey {
                        return secretKey.key.withUnsafeBytes { key in
                            secp256k1_musig_nonce_gen(
                                context,
                                &secnonce,
                                &pubnonce,
                                sessionSecrand,
                                key.bindMemory(to: UInt8.self).baseAddress,
                                &pubkey,
                                msg32Bytes,
                                nil,
                                extraInput32
                            ).boolValue
                        }
                    }
                    return secp256k1_musig_nonce_gen(
                        context,
                        &secnonce,
                        &pubnonce,
                        sessionSecrand,
                        nil,
                        &pubkey,
                        msg32Bytes,
                        nil,
                        extraInput32
                    ).boolValue
                }
                guard nonceGenerated else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return NonceResult(
                    pubnonce: P256K.Schnorr.Nonce(pubnonce: Swift.withUnsafeBytes(of: pubnonce) { Data($0) }),
                    secnonce: P256K.Schnorr.SecureNonce(Swift.withUnsafeBytes(of: secnonce) { SecureBytes(bytes: $0) })
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

        /// The 32 bytes of secret, uniformly random input (`session_secrand32`) that
        /// `secp256k1_musig_nonce_gen` mixes into every MuSig2 nonce derivation.
        ///
        /// Modeled as `~Copyable` so a value cannot be duplicated and must be consumed by
        /// ``Nonce/generate(sessionSecretRand:secretKey:publicKey:msg32:extraInput32:)`` —
        /// reusing this input produces identical nonces and leaks the secret signing key.
        /// The randomness lives in `SecureBytes`, the same auto-zeroing storage used for
        /// private keys and shared secrets: `secp256k1_musig_nonce_gen` zeroes this value's
        /// own buffer in place on a successful call, and the `SecureBytes` backing runs
        /// `memset_s` when the value is released — covering never-consumed values and calls
        /// where upstream returns failure (it only guarantees zeroing on success).
        ///
        /// Like libsecp256k1's own best-effort model, this does not cover copies outside
        /// the value's control: the caller's source array passed to ``init(bytes:)`` (per
        /// that initializer's warning) and any bytes the compiler may spill to the stack
        /// or the OS may page out — OS-level `mlock` protection is out of scope.
        ///
        /// ## Topics
        /// - ``init()``
        /// - ``init(bytes:)``
        /// - ``byteCount``
        struct SessionSecretRand: ~Copyable {
            /// The exact byte count `secp256k1_musig_nonce_gen` reads and zeroes: 32.
            public static let byteCount = 32

            /// The 32-byte session secret randomness consumed by `secp256k1_musig_nonce_gen`,
            /// held in auto-zeroing ``SecureBytes`` storage.
            var bytes: SecureBytes

            /// Generates fresh uniformly random session randomness from the system CSPRNG — the recommended path.
            public init() {
                self.bytes = SecureBytes(count: Self.byteCount)
            }

            /// Creates session randomness from caller-supplied bytes, e.g. deterministic test
            /// vectors or an external entropy source such as a hardware RNG.
            ///
            /// > Warning: The bytes **must be uniformly random and kept secret** — even from
            /// > co-signers. If a co-signer can predict them, they can recompute the secret
            /// > nonce and extract the secret key from the partial signature. Each value is
            /// > consumed by exactly one signing session. The source array is not zeroed —
            /// > discard or zero it yourself after constructing this value.
            ///
            /// - Parameter bytes: Exactly ``byteCount`` (32) bytes of secret uniform randomness.
            /// - Throws: ``secp256k1Error/incorrectParameterSize`` if `bytes.count` is not exactly 32.
            public init(bytes: [UInt8]) throws {
                guard bytes.count == Self.byteCount else {
                    throw secp256k1Error.incorrectParameterSize
                }
                self.bytes = SecureBytes(bytes: bytes)
            }
        }
    }

#endif
