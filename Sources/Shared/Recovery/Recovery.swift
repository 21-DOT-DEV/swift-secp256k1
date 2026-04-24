//
//  Recovery.swift
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

#if Xcode || ENABLE_MODULE_RECOVERY

    // MARK: - secp256k1 + Recovery

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        /// secp256k1 ECDSA recoverable signature namespace: sign with ``PrivateKey`` to produce
        /// an ``ECDSASignature`` that allows any verifier to recover the signer's ``PublicKey``
        /// without prior knowledge.
        ///
        /// ## Overview
        ///
        /// Recoverable signatures are 65 bytes (64-byte compact ECDSA signature + 1-byte
        /// recovery ID). They are produced by `secp256k1_ecdsa_sign_recoverable` and allow the
        /// signing public key to be recovered via `secp256k1_ecdsa_recover` given only the
        /// message hash. See
        /// [`Vendor/secp256k1/include/secp256k1_recovery.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_recovery.h)
        /// for the upstream API reference.
        ///
        /// Bitcoin's
        /// [BIP-137](https://github.com/bitcoin/bips/blob/master/bip-0137.mediawiki) and
        /// [BIP-322](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki)
        /// "signed message" formats rely on this primitive for address-from-signature
        /// recovery. Recoverability trades one byte of signature size for the ability to skip
        /// transmitting the public key — a win whenever the signer and verifier share only a
        /// message and want to establish identity without a pre-exchanged key. The
        /// deterministic-nonce convention follows
        /// [RFC 6979](https://datatracker.ietf.org/doc/html/rfc6979), as with all ECDSA
        /// signing in this library.
        ///
        /// > Important: A recoverable signature that successfully passes `secp256k1_ecdsa_recover`
        /// > is **not guaranteed to pass** `secp256k1_ecdsa_verify` after conversion, because the
        /// > converted signature may not be in lower-S normalized form. Call
        /// > `secp256k1_ecdsa_signature_normalize` after
        /// > ``ECDSASignature/normalize`` if you need a signature that passes standard ECDSA verification.
        ///
        /// > Warning: **Recovery is not verification.** A successfully-recovered key is merely
        /// > a candidate public key whose signature of the given message would be this exact
        /// > byte pattern. To confirm the candidate is the *expected* signer, compare it to
        /// > the known-authentic public key via constant-time equality (e.g. `safeCompare`).
        /// > Never trust a recovered key as-authenticated without that compare step.
        ///
        /// ## Topics
        ///
        /// ### Key Types
        /// - ``PrivateKey``
        /// - ``PublicKey``
        ///
        /// ### Signature Types
        /// - ``ECDSASignature``
        enum Recovery {
            /// secp256k1 ECDSA private key for producing recoverable signatures via
            /// `secp256k1_ecdsa_sign_recoverable` with RFC 6979 deterministic nonce generation.
            ///
            /// Semantically a distinct type from ``P256K/Signing/PrivateKey`` only because its
            /// associated ``PublicKey`` recovers via `secp256k1_ecdsa_recover` rather than being
            /// transmitted alongside the signature. The underlying 32-byte scalar is identical;
            /// the two Swift types differ in the method surface they expose.
            ///
            /// ## Topics
            ///
            /// ### Construction
            /// - ``init(format:)``
            /// - ``init(dataRepresentation:format:)``
            ///
            /// ### Inspection
            /// - ``publicKey``
            /// - ``dataRepresentation``
            public struct PrivateKey: Equatable {
                /// The internal `PrivateKeyImplementation` backing this recoverable-signing key.
                ///
                /// Kept `private` — the backing type wraps the 32-byte secret scalar in
                /// `SecureBytes`-style zeroizing storage; consumers interact only through
                /// the public API surface.
                private let baseKey: PrivateKeyImplementation

                /// The secp256k1 public key derived from this private key, as a ``Recovery/PublicKey``.
                ///
                /// Computed on every access via `secp256k1_ec_pubkey_create`. For high-frequency
                /// signing loops, cache the value locally rather than re-deriving it per call.
                /// The returned public key carries the private key's ``P256K/Format`` selection.
                public var publicKey: PublicKey {
                    PublicKey(baseKey: baseKey.publicKey)
                }

                /// The raw 32-byte private key as `Data`. Keep this value confidential; disclosure
                /// allows anyone to sign on your behalf.
                ///
                /// The bytes are zeroed when the backing `PrivateKeyImplementation` is
                /// deallocated, but **copies made through this accessor are not**: any `Data`
                /// produced here escapes the zeroization scope and must be handled by the caller.
                /// Prefer restricting its reach to the minimum necessary scope (e.g. one encrypted
                /// write to a keychain) before discarding.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// Creates a random secp256k1 recoverable-signing private key by generating 32 cryptographically secure random bytes validated with `secp256k1_ec_seckey_verify`.
                ///
                /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
                /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the generated bytes are not a valid secp256k1 private key.
                public init(format: P256K.Format = .compressed) throws {
                    self.baseKey = try PrivateKeyImplementation(format: format)
                }

                /// Creates a secp256k1 recoverable-signing private key from a 32-byte raw scalar.
                ///
                /// - Parameter data: Exactly 32 bytes; must pass `secp256k1_ec_seckey_verify`.
                /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
                /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if the scalar is invalid.
                public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format = .compressed) throws {
                    self.baseKey = try PrivateKeyImplementation(dataRepresentation: data, format: format)
                }

                /// Returns `true` if both keys have identical 32-byte secret scalars.
                ///
                /// - Parameters:
                ///   - lhs: The left-hand side private key.
                ///   - rhs: The right-hand side private key.
                /// - Returns: `true` if the secret scalars are equal, `false` otherwise.
                public static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.baseKey.key == rhs.baseKey.key
                }
            }

            /// secp256k1 public key recovered from an ``ECDSASignature`` via
            /// `secp256k1_ecdsa_recover`, identifying the signer without prior knowledge of
            /// their public key.
            ///
            /// A recovered public key is mathematically a *candidate* — any signature has up
            /// to four valid recovery IDs, each producing a different candidate key. The
            /// 1-byte recovery ID stored in the ``ECDSASignature`` disambiguates which
            /// candidate the original signer chose. Always treat the recovered key as
            /// unauthenticated material until compared to a known reference.
            ///
            /// ## Topics
            ///
            /// ### Inspection
            /// - ``dataRepresentation``
            public struct PublicKey {
                /// The internal `PublicKeyImplementation` backing this recovered key.
                ///
                /// Kept `internal` — the backing type wraps the 64-byte upstream
                /// `secp256k1_pubkey` struct plus serialization format; consumers never see
                /// the raw C handle through the public API.
                let baseKey: PublicKeyImplementation

                /// The serialized public key bytes as `Data`, in the key's format.
                ///
                /// Suitable for comparison with a known-authentic public key via constant-time
                /// equality (see `safeCompare`) to authenticate the recovery result. The
                /// format (``P256K/Format/compressed`` or ``P256K/Format/uncompressed``) is
                /// inherited from the `format:` argument passed to the recovery initializer.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// Recovers the signer's public key from a message and its ``ECDSASignature`` via `secp256k1_ecdsa_recover`, hashing `data` with SHA-256 first.
                ///
                /// - Parameter data: The original message; it is SHA-256 hashed before recovery.
                /// - Parameter signature: The 65-byte ``ECDSASignature`` containing the compact signature and recovery ID.
                /// - Parameter format: The serialization format of the recovered key; defaults to `.compressed`.
                public init<D: DataProtocol>(
                    _ data: D,
                    signature: P256K.Recovery.ECDSASignature,
                    format: P256K.Format = .compressed
                ) {
                    self.baseKey = PublicKeyImplementation(
                        SHA256.hash(data: data),
                        signature: signature,
                        format: format
                    )
                }

                /// Recovers the signer's public key from a pre-computed digest and its ``ECDSASignature`` via `secp256k1_ecdsa_recover`.
                ///
                /// - Parameter digest: The pre-computed message digest that was signed.
                /// - Parameter signature: The 65-byte ``ECDSASignature`` containing the compact signature and recovery ID.
                /// - Parameter format: The serialization format of the recovered key; defaults to `.compressed`.
                public init<D: Digest>(
                    _ digest: D,
                    signature: P256K.Recovery.ECDSASignature,
                    format: P256K.Format = .compressed
                ) {
                    self.baseKey = PublicKeyImplementation(digest, signature: signature, format: format)
                }

                /// Creates a recovery public key from a validated backing implementation.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }
            }
        }
    }

#endif
