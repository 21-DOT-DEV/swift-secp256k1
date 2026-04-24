//
//  Schnorr+Nonces.swift
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
    public extension P256K.Schnorr {
        /// The byte length of a BIP-327 serialized public nonce (66 bytes).
        ///
        /// Matches the `out66` buffer size of `secp256k1_musig_pubnonce_serialize` in
        /// [`Vendor/secp256k1-zkp/include/secp256k1_musig.h`](https://github.com/BlockstreamResearch/secp256k1-zkp/blob/master/include/secp256k1_musig.h).
        /// The in-memory struct `secp256k1_musig_pubnonce` is 132 bytes; this serialized
        /// form is the stable wire format.
        static let publicNonceByteCount = 66

        /// A signer's secret nonce for MuSig2 operations, modeled as `~Copyable` to prevent
        /// accidental duplication and nonce reuse.
        ///
        /// > Warning: **Nonce reuse leaks the secret signing key.** The upstream
        /// > `secp256k1_musig_partial_sign` zeroes the secnonce after use (see
        /// > [`Vendor/secp256k1-zkp/include/secp256k1_musig.h`](https://github.com/BlockstreamResearch/secp256k1-zkp/blob/master/include/secp256k1_musig.h)
        /// > `secp256k1_musig_nonce_gen`: *"This function overwrites the given secnonce with
        /// > zeros and will abort if given a secnonce that is all zeros."*). Never copy or
        /// > serialize the secret nonce bytes; always provide a unique `sessionID` per
        /// > signing session.
        struct SecureNonce: ~Copyable {
            /// The opaque 132-byte `secp256k1_musig_secnonce` struct bytes.
            ///
            /// Internal-visibility storage; the `~Copyable` conformance prevents consumers
            /// from accessing these bytes outside the one-shot partial-signing flow that
            /// zeroes them after use.
            let data: Data

            /// Wraps raw secret-nonce bytes produced by upstream nonce-generation helpers.
            ///
            /// Internal-visibility constructor; consumers obtain a `SecureNonce` only via
            /// the MuSig nonce-generation entry points.
            ///
            /// - Parameter data: The 132-byte opaque `secp256k1_musig_secnonce` buffer.
            init(_ data: Data) {
                self.data = data
            }
        }

        /// A signer's public nonce for MuSig2 operations, exchanged between signers during
        /// the nonce-aggregation phase of
        /// [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki).
        ///
        /// Unlike ``SecureNonce``, a public nonce is safe to transmit and copy. The
        /// internal representation is the opaque 132-byte `secp256k1_musig_pubnonce` struct;
        /// the wire format is the 66-byte ``dataRepresentation`` produced by
        /// `secp256k1_musig_pubnonce_serialize`.
        ///
        /// ## Topics
        ///
        /// ### Construction
        /// - ``init(dataRepresentation:)``
        ///
        /// ### Serialization
        /// - ``dataRepresentation``
        struct Nonce: ContiguousBytes, Sequence {
            /// The opaque 132-byte `secp256k1_musig_pubnonce` struct bytes.
            ///
            /// Internal-visibility storage; external callers use ``dataRepresentation`` for
            /// the 66-byte stable wire format.
            let pubnonce: Data

            /// Creates a public nonce from the internal 132-byte representation.
            ///
            /// Internal-visibility constructor used by nonce generation and aggregation.
            ///
            /// - Parameter pubnonce: The 132-byte opaque `secp256k1_musig_pubnonce` buffer.
            init(pubnonce: Data) {
                self.pubnonce = pubnonce
            }

            /// Creates a public nonce from a 66-byte serialized representation.
            ///
            /// Parses the BIP-327 wire format via `secp256k1_musig_pubnonce_parse`.
            ///
            /// - Parameter dataRepresentation: A 66-byte serialized public nonce.
            /// - Throws: ``secp256k1Error/underlyingCryptoError`` if the byte count is
            ///   wrong or parsing fails.
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
            /// Note this exposes the **132-byte internal struct**, not the 66-byte wire
            /// format; use ``dataRepresentation`` for the serialized form.
            ///
            /// - Parameter body: A closure that takes an `UnsafeRawBufferPointer` and
            ///   returns a value.
            /// - Returns: The value returned by the closure.
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
                try pubnonce.withUnsafeBytes(body)
            }

            /// Returns an iterator over the bytes of the public nonce.
            ///
            /// Iterates over the **132-byte internal struct bytes**, not the 66-byte wire
            /// format.
            ///
            /// - Returns: An iterator for the public nonce data.
            public func makeIterator() -> Data.Iterator {
                pubnonce.makeIterator()
            }

            /// A 66-byte data representation of the public nonce in BIP-327 wire format,
            /// produced by `secp256k1_musig_pubnonce_serialize`.
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
