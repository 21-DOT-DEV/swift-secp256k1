//
//  Schnorr+PrivateKey.swift
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

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K.Schnorr {
        /// secp256k1
        /// [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr
        /// private key for signing messages with ``SchnorrSignature`` and for deriving the
        /// x-only public key used in verification.
        ///
        /// ## Overview
        ///
        /// Schnorr signatures use `secp256k1_schnorrsig_sign_custom` with the BIP-340 nonce
        /// function (`secp256k1_nonce_function_bip340`), both declared in
        /// [`Vendor/secp256k1/include/secp256k1_schnorrsig.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h).
        /// Unlike ECDSA, signing takes a 32-byte auxiliary randomness input that is mixed
        /// into the nonce for protection against fault attacks; the default
        /// `signature(for:)` overloads supply fresh random bytes automatically via
        /// `SecureBytes`.
        ///
        /// Verification uses x-only public keys (``xonly``), not full compressed keys. The
        /// ``publicKey`` property returns the full ``PublicKey`` for contexts that require
        /// it (key aggregation, Taproot key-path spending).
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init()``
        /// - ``init(dataRepresentation:)``
        ///
        /// ### Inspection
        /// - ``publicKey``
        /// - ``xonly``
        /// - ``dataRepresentation``
        /// - ``negation``
        struct PrivateKey: Equatable {
            /// The internal `PrivateKeyImplementation` backing this Schnorr signing key.
            ///
            /// Kept `private` — the backing type wraps the 32-byte secret scalar in
            /// `SecureBytes`-style zeroizing storage; consumers interact only through the
            /// public API surface.
            private let baseKey: PrivateKeyImplementation

            /// The raw 32-byte secret key bytes as `SecureBytes`.
            ///
            /// Internal-visibility accessor used by Swift-side Schnorr signing helpers.
            /// External callers use ``dataRepresentation`` for a `Data` copy.
            var key: SecureBytes {
                baseKey.key
            }

            /// The full secp256k1 public key derived from this private key, in uncompressed
            /// form (65 bytes).
            ///
            /// Returned as a full ``PublicKey`` rather than an x-only key because some
            /// downstream operations (key aggregation, tweak addition on the full point)
            /// need both coordinates. Use ``xonly`` instead for direct BIP-340 verification.
            public var publicKey: PublicKey {
                PublicKey(baseKey: baseKey.publicKey)
            }

            /// The 32-byte x-only public key (X coordinate only) for verifying BIP-340
            /// Schnorr signatures created with this key.
            ///
            /// This is the canonical external identifier for a Schnorr signer — it's what a
            /// BIP-340 verifier consumes and what Taproot outputs commit to.
            public var xonly: XonlyKey {
                XonlyKey(baseKey: baseKey.publicKey.xonly)
            }

            /// The raw 32-byte secret key as `Data`. Keep this value confidential;
            /// disclosure allows anyone to sign on your behalf.
            ///
            /// The bytes are zeroed when the backing `PrivateKeyImplementation` is
            /// deallocated, but **copies made through this accessor are not**: any `Data`
            /// produced here escapes the zeroization scope and must be handled by the
            /// caller.
            public var dataRepresentation: Data {
                baseKey.dataRepresentation
            }

            /// A new ``PrivateKey`` whose secret scalar is the additive inverse modulo the
            /// secp256k1 curve order, produced by `secp256k1_ec_seckey_negate`.
            ///
            /// Useful in BIP-340 when the signing key must represent the even-Y
            /// x-only public key: if ``xonly``'s parity is odd, the signer negates the
            /// secret scalar before signing so the effective public key has even Y.
            public var negation: Self {
                Self(baseKey: baseKey.negation)
            }

            /// Creates a private key from a validated backing implementation.
            ///
            /// Internal-visibility constructor used when the backing implementation has
            /// already been validated (e.g. by ``negation``); consumers use ``init()`` or
            /// ``init(dataRepresentation:)`` instead.
            ///
            /// - Parameter baseKey: A validated `PrivateKeyImplementation`.
            init(baseKey: PrivateKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Creates a random secp256k1 Schnorr private key by generating 32 cryptographically secure random bytes validated with `secp256k1_ec_seckey_verify`.
            ///
            /// The backing key always uses the uncompressed public key format internally, as required by `secp256k1_keypair_create`.
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the generated bytes are not a valid secp256k1 private key (probability < 2⁻¹²⁸).
            public init() throws {
                self.baseKey = try PrivateKeyImplementation(format: .uncompressed)
            }

            /// Creates a secp256k1 Schnorr private key from a 32-byte raw scalar.
            ///
            /// - Parameter data: Exactly 32 bytes representing the private key scalar; must pass `secp256k1_ec_seckey_verify`.
            /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if the scalar is invalid.
            public init<D: ContiguousBytes>(dataRepresentation data: D) throws {
                self.baseKey = try PrivateKeyImplementation(dataRepresentation: data)
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
    }

#endif
