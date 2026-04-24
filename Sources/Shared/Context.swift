//
//  Context.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// Context management for the secp256k1 elliptic curve used in ECDSA signing, Schnorr signatures,
/// and key generation.
///
/// This extension provides the ``Context`` structure, which manages the lifecycle and randomization
/// of the `secp256k1_context` object that all cryptographic operations in the library depend on,
/// including ECDSA signature creation and verification, Schnorr signature operations, public key
/// generation, and ECDH key agreement. The upstream reference is
/// [`Vendor/secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h).
///
/// Use ``Context/rawRepresentation`` to access the shared, pre-initialized context for standard
/// operations, or call ``Context/create()`` to create a fresh, independently randomized context.
///
/// ## Context Objects and Side-Channel Protection
///
/// The secp256k1 context stores randomization data that protects against side-channel leakage
/// during operations that multiply a secret scalar with the elliptic curve base point, such as
/// ECDSA signing, Schnorr signing, and public key generation. This protection is only effective
/// when the context is randomized after creation, which ``Context/create()`` handles automatically
/// using 32 bytes of cryptographically secure randomness drawn via `SecureBytes`.
///
/// Per the upstream `secp256k1_context_randomize` documentation:
/// *"A notable exception to that rule is the ECDH module, which relies on a different kind of
/// elliptic curve point multiplication and thus does not benefit from enhanced protection against
/// side-channel leakage currently."* Consumers needing hardened ECDH should look beyond context
/// randomization.
///
/// ## Thread Safety
///
/// A constructed context can safely be used from multiple threads simultaneously, but API calls
/// that take a non-const pointer to a context need exclusive access to it. In particular this is
/// the case for `secp256k1_context_destroy`, `secp256k1_context_preallocated_destroy`, and
/// `secp256k1_context_randomize`.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// The secp256k1 context manages cryptographic state for ECDSA and Schnorr operations with automatic side-channel protection via base point blinding.
    ///
    /// `Context` wraps the libsecp256k1 context object that all cryptographic operations in the
    /// P256K library require, including ECDSA signing, Schnorr signatures, public key generation,
    /// and ECDH key agreement. It handles context creation with `SECP256K1_CONTEXT_NONE` flags and
    /// immediately randomizes the internal state using cryptographically secure random bytes to
    /// protect against side-channel attacks during operations that involve secret scalar
    /// multiplication with the elliptic curve base point.
    ///
    /// ## Usage
    ///
    /// Most operations should use the shared ``rawRepresentation`` context, which is created and
    /// randomized once at process startup.
    ///
    /// ```swift
    /// let ctx = P256K.Context.rawRepresentation
    /// ```
    ///
    /// Call ``create()`` when you need a fresh, independently randomized context with isolated
    /// cryptographic state.
    ///
    /// ```swift
    /// let ctx = P256K.Context.create()
    /// ```
    ///
    /// ## secp256k1 Context Lifecycle
    ///
    /// The secp256k1 library requires a context object to be passed to nearly every API function.
    /// Context creation allocates internal data structures, and randomization seeds an internal
    /// counter that blinds intermediate values during secret scalar multiplication with the
    /// elliptic curve base point. The ``rawRepresentation`` property provides a single shared
    /// context that is created and randomized once at process startup, avoiding repeated allocation
    /// overhead.
    ///
    /// ## Side-Channel Protection Scope
    ///
    /// Randomization protects operations that multiply a secret scalar with the elliptic curve base
    /// point, including ECDSA signing, Schnorr signing, and public key generation. The ECDH module
    /// uses a different kind of point multiplication and does not currently benefit from context
    /// randomization.
    ///
    /// ## Topics
    ///
    /// ### Shared Context
    /// - ``rawRepresentation``
    ///
    /// ### Construction
    /// - ``create()``
    struct Context: Sendable {
        /// The shared secp256k1 context, created and randomized at initialization for use across all P256K cryptographic operations.
        ///
        /// Use this property to access the default secp256k1 context for ECDSA signing, Schnorr
        /// signatures, ECDH key agreement, and public key generation. The context is created once
        /// with ``create()`` and randomized with cryptographically secure random bytes, providing
        /// side-channel protection for operations that involve secret scalar multiplication with
        /// the elliptic curve base point.
        nonisolated(unsafe) public static let rawRepresentation = P256K.Context.create()

        /// The context configuration flags passed to `secp256k1_context_create`, set to `SECP256K1_CONTEXT_NONE`.
        ///
        /// `SECP256K1_CONTEXT_NONE` creates a context suitable for all secp256k1 operations.
        /// In modern versions of libsecp256k1, signing and verification capabilities are always
        /// available regardless of the flag value, making the separate `SECP256K1_CONTEXT_SIGN`
        /// and `SECP256K1_CONTEXT_VERIFY` flags unnecessary.
        static let rawValue = UInt32(SECP256K1_CONTEXT_NONE)

        /// Creates a new secp256k1 context and randomizes it with cryptographically secure bytes for side-channel protection.
        ///
        /// This method allocates a new secp256k1 context using `secp256k1_context_create` with the
        /// context's `rawValue` flags, then calls `secp256k1_context_randomize` with 32 bytes of secure
        /// randomness from the internal `SecureBytes` wrapper. Randomization seeds an internal counter that blinds
        /// intermediate values during secret scalar multiplication with the elliptic curve base
        /// point, protecting ECDSA signing, Schnorr signing, and public key generation against
        /// timing and power analysis attacks.
        ///
        /// - Precondition: Context creation and randomization must both succeed. A precondition
        ///   failure occurs if `secp256k1_context_create` returns `nil` or if
        ///   `secp256k1_context_randomize` fails.
        /// - Returns: An opaque pointer to the newly created and randomized secp256k1 context.
        public static func create() -> OpaquePointer {
            var randomBytes = SecureBytes(count: P256K.ByteLength.privateKey).bytes

            guard let context = secp256k1_context_create(Self.rawValue) else {
                preconditionFailure("Failed to create secp256k1 context")
            }

            precondition(
                secp256k1_context_randomize(context, &randomBytes).boolValue,
                "Failed to randomize secp256k1 context"
            )

            return context
        }
    }
}
