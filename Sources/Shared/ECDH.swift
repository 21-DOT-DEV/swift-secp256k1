//
//  ECDH.swift
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

#if Xcode || ENABLE_MODULE_ECDH

    // MARK: - secp256k1 + KeyAgreement

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        /// secp256k1 ECDH (Elliptic-Curve Diffie-Hellman) key-agreement namespace
        /// providing ``PrivateKey`` and ``PublicKey`` for computing a ``SharedSecret`` via
        /// `secp256k1_ecdh` (declared in
        /// [`Vendor/secp256k1/include/secp256k1_ecdh.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_ecdh.h)).
        ///
        /// ## Overview
        ///
        /// ECDH computes a shared secret `S = private_key × peer_public_key` on the secp256k1
        /// elliptic curve. The upstream C function executes in constant time with respect to
        /// the secret scalar, matching its contract line: *"Compute an EC Diffie-Hellman secret
        /// in constant time."* The shared secret is returned as a serialized point in
        /// compressed (33-byte, default) or uncompressed (65-byte) form via the custom hash
        /// closure installed in ``PrivateKey/sharedSecretFromKeyAgreement(with:format:)`` —
        /// this overrides the upstream default (`secp256k1_ecdh_hash_function_sha256`, which
        /// would return a 32-byte SHA-256 hash of the compressed point) so callers receive the
        /// raw serialized EC point, suitable as input to any higher-level KDF.
        ///
        /// Bitcoin-ecosystem consumers include BIP-324 v2 P2P transport
        /// ([BIP-324](https://github.com/bitcoin/bips/blob/master/bip-0324.mediawiki)),
        /// BIP-352 Silent Payments
        /// ([BIP-352](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki)),
        /// and Lightning Network session-key derivation.
        ///
        /// > Important: **Context randomization does not provide side-channel protection for
        /// > ECDH.** Per the upstream `secp256k1_context_randomize` documentation in
        /// > [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h):
        /// > *"A notable exception [to the rule that randomization protects secret-key
        /// > operations] is the ECDH module, which relies on a different kind of elliptic
        /// > curve point multiplication and thus does not benefit from enhanced protection
        /// > against side-channel leakage currently."* Consumers needing hardened ECDH should
        /// > perform it on an air-gapped device or with platform-specific mitigations.
        ///
        /// ## Topics
        ///
        /// ### Key Types
        /// - ``PrivateKey``
        /// - ``PublicKey``
        /// - ``XonlyKey``
        enum KeyAgreement: Sendable {
            /// secp256k1 ECDH public key, accepted by
            /// ``PrivateKey/sharedSecretFromKeyAgreement(with:format:)`` to compute a
            /// ``SharedSecret``.
            ///
            /// Semantically the same 33- or 65-byte SEC1 encoded public key used by ECDSA
            /// and Schnorr; the Swift type is distinct only so that the compiler routes
            /// calls to the ECDH-specific Diffie-Hellman method instead of a signing API.
            ///
            /// ## Topics
            ///
            /// ### Construction
            /// - ``init(dataRepresentation:format:)``
            /// - ``init(x963Representation:)``
            /// - ``init(derRepresentation:)``
            ///
            /// ### Serialized Forms
            /// - ``dataRepresentation``
            /// - ``uncompressedRepresentation``
            /// - ``xonly``
            public struct PublicKey: Sendable {
                /// The internal `PublicKeyImplementation` backing this ECDH public key.
                ///
                /// Kept `internal` — the backing type wraps the 64-byte upstream
                /// `secp256k1_pubkey` struct plus serialization format; consumers never see
                /// the raw C handle through the public API.
                let baseKey: PublicKeyImplementation

                /// Creates a secp256k1 ECDH public key from serialized bytes.
                ///
                /// - Parameter data: Serialized public key bytes whose length must match
                ///   `format.length` (33 for compressed, 65 for uncompressed).
                /// - Parameter format: The serialization format; defaults to `.compressed`
                ///   (33 bytes).
                /// - Throws: ``secp256k1Error/underlyingCryptoError`` if parsing via
                ///   `secp256k1_ec_pubkey_parse` fails (invalid encoding or off-curve point).
                public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format = .compressed) throws {
                    self.baseKey = try PublicKeyImplementation(dataRepresentation: data, format: format)
                }

                /// Creates an ECDH public key from a validated backing implementation.
                ///
                /// Internal-visibility constructor used by the companion ``PrivateKey``'s
                /// ``PrivateKey/publicKey`` accessor after the backing implementation has
                /// already been validated.
                ///
                /// - Parameter baseKey: A validated `PublicKeyImplementation` produced by
                ///   the upstream C parser.
                init(baseKey: PublicKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// The 32-byte x-only public key (X coordinate only) derived from this key.
                ///
                /// Computed on every access via `secp256k1_xonly_pubkey_from_pubkey`. Useful
                /// when a downstream protocol (Taproot-aware ECDH schemes, Silent Payments)
                /// needs the BIP-340-style x-only representation of the same public point.
                public var xonly: P256K.KeyAgreement.XonlyKey {
                    XonlyKey(baseKey: baseKey.xonly)
                }

                /// The 65-byte uncompressed serialization of this public key (`0x04` prefix
                /// + 32-byte X + 32-byte Y).
                ///
                /// Always returns the uncompressed form regardless of the key's stored
                /// ``P256K/Format``. Useful when interoperating with systems that require
                /// the full `(x, y)` point encoding.
                public var uncompressedRepresentation: Data {
                    baseKey.uncompressedRepresentation
                }

                /// The serialized public key bytes as `Data`, in the key's
                /// ``P256K/Format``.
                ///
                /// Suitable for transmission and persistence. Format is the one passed at
                /// construction time and can be inspected via the backing implementation's
                /// `format` property when needed.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The serialized public key bytes as `[UInt8]`.
                ///
                /// Internal-visibility accessor used by peer-facing Swift helpers that want
                /// to avoid the `Data` allocation; external callers use
                /// ``dataRepresentation`` for the `Data` form.
                var bytes: [UInt8] {
                    baseKey.bytes
                }

                /// Creates a secp256k1 public key for key agreement from a Distinguished Encoding Rules (DER) encoded representation.
                ///
                /// - Parameters:
                ///   - derRepresentation: A DER-encoded representation of the key.
                public init<Bytes: RandomAccessCollection>(derRepresentation: Bytes) throws where Bytes.Element == UInt8 {
                    let bytes = Array(derRepresentation)
                    let parsed = try ASN1.SubjectPublicKeyInfo(asn1Encoded: bytes)
                    self = try .init(x963Representation: parsed.key)
                }

                /// Creates a secp256k1 ECDH public key from an ANSI X9.63 representation.
                ///
                /// - Parameter x963Representation: 33 bytes for compressed or 65 bytes for uncompressed; byte-length determines the format automatically.
                /// - Throws: `CryptoKitError.incorrectParameterSize` if the length is neither 33 nor 65 bytes.
                public init<Bytes: ContiguousBytes>(x963Representation: Bytes) throws {
                    let length = x963Representation.withUnsafeBytes { $0.count }

                    switch length {
                    case P256K.ByteLength.dimension + 1:
                        self.baseKey = try PublicKeyImplementation(dataRepresentation: x963Representation, format: .compressed)

                    case (2 * P256K.ByteLength.dimension) + 1:
                        self.baseKey = try PublicKeyImplementation(dataRepresentation: x963Representation, format: .uncompressed)

                    default:
                        throw CryptoKitError.incorrectParameterSize
                    }
                }
            }

            /// The 32-byte x-only form of a ``PublicKey``, derived via
            /// `secp256k1_xonly_pubkey_from_pubkey`.
            ///
            /// Drops the Y-coordinate parity bit from the 33-byte compressed encoding,
            /// matching the BIP-340 x-only representation. The 1-bit parity is preserved
            /// separately in ``parity`` so Taproot-aware ECDH schemes can reconstruct the
            /// full point when needed.
            ///
            /// ## Topics
            ///
            /// ### Inspection
            /// - ``dataRepresentation``
            /// - ``parity``
            public struct XonlyKey: Sendable {
                /// The internal `XonlyKeyImplementation` backing this x-only key.
                ///
                /// Kept `private` — the backing type is an internal convenience over the
                /// upstream `secp256k1_xonly_pubkey` struct; consumers never see or
                /// manipulate it directly.
                private let baseKey: XonlyKeyImplementation

                /// The 32-byte X coordinate as `Data`.
                ///
                /// Stable across libsecp256k1 versions — safe to persist as a BIP-340-style
                /// key identifier. Pair with ``parity`` when the full `(x, y)` point must
                /// be reconstructed downstream.
                public var dataRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// `true` if the full public key's Y coordinate is odd (the x-only point is
                /// the negation of the original pubkey), `false` if even; as returned by
                /// `secp256k1_xonly_pubkey_from_pubkey`.
                ///
                /// BIP-340 verifiers operate against the even-Y representative of a point,
                /// so the parity bit is tracked separately. `true` means the original
                /// pubkey had odd Y and had its sign flipped during x-only conversion.
                public var parity: Bool {
                    baseKey.keyParity.boolValue
                }

                /// Creates an ECDH x-only key from a validated backing implementation.
                ///
                /// Internal-visibility constructor used by ``PublicKey/xonly``; consumers
                /// access x-only keys through that accessor rather than constructing
                /// directly.
                ///
                /// - Parameter baseKey: A validated `XonlyKeyImplementation`.
                init(baseKey: XonlyKeyImplementation) {
                    self.baseKey = baseKey
                }
            }

            /// secp256k1 ECDH private key for deriving a ``SharedSecret`` with a peer's
            /// ``PublicKey`` via `secp256k1_ecdh`.
            ///
            /// The underlying 32-byte scalar is identical to an ECDSA or Schnorr private
            /// key on the same curve; the Swift type is distinct only to route calls to
            /// the Diffie-Hellman method surface instead of a signing API. Secret bytes are
            /// held in `SecureBytes`-style zeroizing storage via the backing
            /// `PrivateKeyImplementation`.
            ///
            /// ## Topics
            ///
            /// ### Construction
            /// - ``init(format:)``
            /// - ``init(dataRepresentation:format:)``
            ///
            /// ### Inspection
            /// - ``publicKey``
            /// - ``rawRepresentation``
            ///
            /// ### Key Agreement
            /// - ``sharedSecretFromKeyAgreement(with:format:)``
            public struct PrivateKey: Sendable {
                /// The internal `PrivateKeyImplementation` backing this ECDH signing key.
                ///
                /// Kept `internal` — the backing type wraps the 32-byte secret scalar in
                /// `SecureBytes`-style zeroizing storage; consumers interact only through
                /// the public API surface and the DH protocol conformance.
                let baseKey: PrivateKeyImplementation

                /// Creates a random secp256k1 ECDH private key.
                ///
                /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
                /// - Throws: ``secp256k1Error/underlyingCryptoError`` if key generation fails.
                public init(format: P256K.Format = .compressed) throws {
                    self.baseKey = try PrivateKeyImplementation(format: format)
                }

                /// Creates a secp256k1 ECDH private key from a 32-byte raw scalar.
                ///
                /// - Parameter data: Exactly 32 bytes; must pass `secp256k1_ec_seckey_verify`.
                /// - Parameter format: The serialization format of the companion ``publicKey``; defaults to `.compressed`.
                /// - Throws: ``secp256k1Error/incorrectKeySize`` if `data` is not 32 bytes; ``secp256k1Error/underlyingCryptoError`` if the scalar is invalid.
                public init<D: ContiguousBytes>(dataRepresentation data: D, format: P256K.Format = .compressed) throws {
                    self.baseKey = try PrivateKeyImplementation(dataRepresentation: data, format: format)
                }

                /// Creates an ECDH private key from a validated backing implementation.
                init(baseKey: PrivateKeyImplementation) {
                    self.baseKey = baseKey
                }

                /// The secp256k1 public key derived from this private key, as a
                /// ``PublicKey``.
                ///
                /// Computed on every access via `secp256k1_ec_pubkey_create`. For
                /// high-frequency key-agreement loops, cache the value locally rather than
                /// re-deriving it per call. The returned public key carries the private
                /// key's ``P256K/Format`` selection.
                public var publicKey: P256K.KeyAgreement.PublicKey {
                    PublicKey(baseKey: baseKey.publicKey)
                }

                /// The raw 32-byte private key as `Data`. Keep this value confidential;
                /// disclosure allows anyone to compute shared secrets with this key.
                ///
                /// The bytes are zeroed when the backing `PrivateKeyImplementation` is
                /// deallocated, but **copies made through this accessor are not**: any
                /// `Data` produced here escapes the zeroization scope and must be handled
                /// by the caller. Prefer restricting its reach to the minimum necessary
                /// scope (e.g. one encrypted write to a keychain) before discarding.
                public var rawRepresentation: Data {
                    baseKey.dataRepresentation
                }

                /// The raw 32-byte private key as `SecureBytes`.
                ///
                /// Internal-visibility accessor used by Swift-side helpers that participate
                /// in the `SecureBytes` lifetime; external callers use ``rawRepresentation``
                /// for a `Data` copy.
                var bytes: SecureBytes {
                    baseKey.key
                }
            }
        }
    }

    // MARK: - secp256k1 + DH

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    extension P256K.KeyAgreement.PrivateKey: DiffieHellmanKeyAgreement {
        /// The C function type for a custom ECDH hash function that serializes the shared
        /// EC point into secret bytes.
        ///
        /// Matches the upstream `secp256k1_ecdh_hash_function` typedef in
        /// [`Vendor/secp256k1/include/secp256k1_ecdh.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_ecdh.h).
        /// The installed closure receives the 32-byte `x` and `y` coordinates of the
        /// shared point along with a user-data pointer; the upstream contract requires
        /// returning `1` on success (allowing `secp256k1_ecdh` itself to return `1`) and
        /// `0` on failure (which propagates as `secp256k1_ecdh` returning `0`).
        public typealias HashFunctionType = @convention(c) (
            UnsafeMutablePointer<UInt8>?,
            UnsafePointer<UInt8>?,
            UnsafePointer<UInt8>?,
            UnsafeMutableRawPointer?
        ) -> Int32

        /// Computes a compressed-format ECDH shared secret with `publicKeyShare` via
        /// `secp256k1_ecdh`.
        ///
        /// Convenience wrapper that delegates to ``sharedSecretFromKeyAgreement(with:format:)``
        /// with `.compressed` as the serialization format, matching the
        /// `DiffieHellmanKeyAgreement` protocol signature.
        ///
        /// - Parameter publicKeyShare: The peer's public key.
        /// - Returns: A ``SharedSecret`` in compressed (33-byte) format.
        func sharedSecretFromKeyAgreement(with publicKeyShare: P256K.KeyAgreement.PublicKey) -> SharedSecret {
            sharedSecretFromKeyAgreement(with: publicKeyShare, format: .compressed)
        }

        /// Computes an ECDH shared secret by calling `secp256k1_ecdh` with a custom hash
        /// closure that serializes the shared point.
        ///
        /// The shared point is serialized as a compressed (33-byte) or uncompressed
        /// (65-byte) public key depending on `format`. This overrides the upstream default
        /// (`secp256k1_ecdh_hash_function_sha256`, which would return a 32-byte SHA-256
        /// hash of the compressed point) so callers receive the raw serialized EC point,
        /// suitable as input to any higher-level KDF.
        ///
        /// > Important: **Context randomization does not protect this operation against
        /// > side-channel attacks.** Per upstream `secp256k1_context_randomize`
        /// > documentation, ECDH uses variable-point multiplication rather than base-point
        /// > multiplication, and is explicitly excluded from the protection that
        /// > randomization provides to ECDSA / Schnorr signing.
        ///
        /// - Parameter publicKeyShare: The peer's secp256k1 public key.
        /// - Parameter format: Whether to serialize the shared point as compressed
        ///   (33 bytes, default) or uncompressed (65 bytes).
        /// - Returns: A ``SharedSecret`` containing the serialized shared point.
        public func sharedSecretFromKeyAgreement(
            with publicKeyShare: P256K.KeyAgreement.PublicKey,
            format: P256K.Format = .compressed
        ) -> SharedSecret {
            let context = P256K.Context.rawRepresentation
            var publicKey = publicKeyShare.baseKey.rawRepresentation
            var sharedSecret = [UInt8](repeating: 0, count: format.length)
            var data = [UInt8](repeating: format == .compressed ? 1 : 0, count: 1)

            guard secp256k1_ecdh(context, &sharedSecret, &publicKey, baseKey.key.bytes, hashClosure(), &data).boolValue else {
                fatalError("secp256k1_ecdh failed with valid keys — library bug")
            }

            return SharedSecret(ss: SecureBytes(bytes: sharedSecret), format: format)
        }

        /// Returns a `secp256k1_ecdh` hash function closure that serializes the shared EC
        /// point as a compressed or uncompressed public key, bypassing the default SHA-256
        /// hashing.
        ///
        /// The returned closure reads a `Bool` from the `data` pointer (set by
        /// ``sharedSecretFromKeyAgreement(with:format:)`` based on the requested `format`)
        /// and writes either the 33-byte compressed encoding (`0x02`/`0x03` prefix + X) or
        /// the 65-byte uncompressed encoding (`0x04` prefix + X + Y). Construction of the
        /// prefix byte follows the SEC1 convention: for compressed encoding, the low bit
        /// of the Y coordinate determines whether to prefix with `0x02` (even Y) or
        /// `0x03` (odd Y).
        ///
        /// - Returns: A C-compatible ``HashFunctionType`` closure for use as the `hashfp`
        ///   argument of `secp256k1_ecdh`.
        func hashClosure() -> HashFunctionType {
            { output, x32, y32, data in
                guard let output, let x32, let y32, let compressed = data?.load(as: Bool.self) else { return 0 }

                let lastByte = y32.advanced(by: P256K.ByteLength.dimension - 1).pointee
                let version: UInt8 = compressed ? (lastByte & 0x01) | 0x02 : 0x04

                output.update(repeating: version, count: 1)
                output.advanced(by: 1).update(from: x32, count: P256K.ByteLength.dimension)

                if compressed == false {
                    output.advanced(by: P256K.ByteLength.dimension + 1)
                        .update(from: y32, count: P256K.ByteLength.dimension)
                }

                return 1
            }
        }
    }

#endif
