//
//  Context.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import libsecp256k1

/// Context management for the secp256k1 elliptic curve used in ECDSA signing, Schnorr signatures,
/// and key generation.
///
/// This extension provides the ``Context`` structure, which manages the lifecycle and randomization
/// of the `secp256k1_context` object that all cryptographic operations in the library depend on,
/// including ECDSA signature creation and verification, Schnorr signature operations, public key
/// generation, and ECDH key agreement. The upstream reference is
/// [`secp256k1/include/secp256k1.h`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h).
///
/// Use ``Context/rawRepresentation`` to access the shared, pre-initialized context for standard
/// operations, or create a managed ``Context`` value for fresh, independently randomized state.
///
/// ## Context Objects and Side-Channel Protection
///
/// The secp256k1 context stores randomization data that protects against side-channel leakage
/// during operations that multiply a secret scalar with the elliptic curve base point, such as
/// ECDSA signing, Schnorr signing, and public key generation. This protection is only effective
/// when the context is randomized after creation, which ``Context/init()`` handles automatically
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
    /// Create a ``Context`` value when you need a fresh, independently randomized context with
    /// isolated cryptographic state.
    ///
    /// ```swift
    /// let ctx = P256K.Context()
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
    /// (``P256K/KeyAgreement``) uses a different kind of point multiplication and does not currently
    /// benefit from context randomization.
    ///
    /// ## Topics
    ///
    /// ### Shared Context
    /// - ``rawRepresentation``
    ///
    /// ### Construction and Lifetime
    /// - ``init()``
    /// - ``withUnsafeContextPointer(_:)``
    /// - ``create()``
    struct Context: Sendable {
        /// Owns the `secp256k1_context` pointer held by a ``Context`` value.
        ///
        /// `Sendable` is verified by contract rather than by the compiler: every upstream call
        /// made through the pointer is const-qualified and thread-safe, while the two mutable
        /// calls — `secp256k1_context_randomize` and `secp256k1_context_destroy` — happen only
        /// inside `init` and `deinit`, which are exclusive by construction. The conformance
        /// additionally rests on `withUnsafeContextPointer`'s contract: a caller invoking the
        /// exclusive mutable calls on the borrowed pointer — as its `- Warning:` forbids —
        /// would race in C.
        ///
        /// Default `internal` visibility rather than `private` so tests can weakly
        /// observe `deinit` ordering; it never escapes into the public interface.
        final class Storage: @unchecked Sendable {
            /// The owned context pointer, valid until `deinit` destroys it.
            let context: OpaquePointer

            init() {
                self.context = P256K.Context.makeContext()
            }

            deinit {
                secp256k1_context_destroy(context)
            }
        }

        /// The shared secp256k1 context, created and randomized at initialization for use across all P256K cryptographic operations.
        ///
        /// Use this property to access the default secp256k1 context for ECDSA signing, Schnorr
        /// signatures, ECDH key agreement, and public key generation. The context is created once
        /// at process startup and randomized with cryptographically secure random bytes, providing
        /// side-channel protection for operations that involve secret scalar multiplication with
        /// the elliptic curve base point.
        nonisolated(unsafe) public static let rawRepresentation = P256K.Context.makeContext()

        /// The context configuration flags passed to `secp256k1_context_create`, set to `SECP256K1_CONTEXT_NONE`.
        ///
        /// `SECP256K1_CONTEXT_NONE` creates a context suitable for all secp256k1 operations.
        /// In modern versions of libsecp256k1, signing and verification capabilities are always
        /// available regardless of the flag value, making the separate `SECP256K1_CONTEXT_SIGN`
        /// and `SECP256K1_CONTEXT_VERIFY` flags unnecessary.
        static let rawValue = UInt32(SECP256K1_CONTEXT_NONE)

        /// The reference-type storage owning the context pointer.
        ///
        /// Default `internal` visibility rather than `private` so tests can
        /// weakly observe `deinit` ordering; it never escapes into the public interface.
        let storage: Storage

        /// Creates a new, independently randomized secp256k1 context owned by this value.
        ///
        /// The context is allocated with `secp256k1_context_create`, its illegal-argument
        /// and error callbacks are routed to ``P256K/invariantFailure(_:)``, and it is randomized
        /// with 32 bytes of `SecureBytes` — the same creation sequence the deprecated
        /// ``create()`` forwards to. When the
        /// last ``Context`` value sharing this storage is released, the context is destroyed via
        /// `secp256k1_context_destroy`.
        ///
        /// - Note: Context creation and randomization are treated as unreachable-by-contract
        ///   invariants — if `secp256k1_context_create` returns `nil` or
        ///   `secp256k1_context_randomize` fails, the handler installed via
        ///   ``setInvariantViolationHandler(_:)`` is notified and the process terminates via
        ///   `fatalError`.
        public init() {
            self.storage = Storage()
        }

        /// Creates a new secp256k1 context and randomizes it with cryptographically secure bytes for side-channel protection.
        ///
        /// This method allocates a new secp256k1 context using `secp256k1_context_create` with the
        /// context's `rawValue` flags, then calls `secp256k1_context_randomize` with 32 bytes of secure
        /// randomness from the internal `SecureBytes` wrapper. Randomization seeds an internal counter that blinds
        /// intermediate values during secret scalar multiplication with the elliptic curve base
        /// point, protecting ECDSA signing, Schnorr signing, and public key generation against
        /// timing and power analysis attacks.
        ///
        /// - Note: Context creation and randomization are treated as unreachable-by-contract
        ///   invariants — if `secp256k1_context_create` returns `nil` or
        ///   `secp256k1_context_randomize` fails, the handler installed via
        ///   ``setInvariantViolationHandler(_:)`` is notified and
        ///   the process terminates via `fatalError`.
        /// - Returns: An opaque pointer to the newly created and randomized secp256k1 context.
        ///   Callers remain responsible for `secp256k1_context_destroy` — the pairing
        ///   ``init()`` enforces automatically.
        @available(*, deprecated, message: "use P256K.Context() — a managed owner that destroys the context on release")
        public static func create() -> OpaquePointer {
            makeContext()
        }

        /// The shared context-creation sequence backing ``init()``, ``create()``, and
        /// ``rawRepresentation``: allocate, install the invariant-failure callbacks, randomize.
        private static func makeContext() -> OpaquePointer {
            let seed = SecureBytes(count: P256K.ByteLength.privateKey)

            guard let context = secp256k1_context_create(Self.rawValue) else {
                P256K.invariantFailure("secp256k1_context_create returned nil — library bug")
            }

            // Route upstream's own unreachable-state reports through the same
            // channel: an `ARG_CHECK` or internal-error callback firing can only
            // mean a P256K validation gap or library corruption, so both
            // callbacks end in `invariantFailure` rather than returning into
            // undefined output.
            // Installed before randomization so every later call on this context
            // is covered; `secp256k1_context_static` cannot carry custom
            // callbacks, so do not migrate this context to it.
            secp256k1_context_set_illegal_callback(context, { message, _ in
                P256K.invariantFailure("libsecp256k1 argument check failed: \(message.map { String(cString: $0) } ?? "<null>")")
            }, nil)
            secp256k1_context_set_error_callback(context, { message, _ in
                P256K.invariantFailure("libsecp256k1 internal consistency check failed: \(message.map { String(cString: $0) } ?? "<null>")")
            }, nil)

            guard seed.withUnsafeBytePointer({ seedPtr in
                secp256k1_context_randomize(context, seedPtr).boolValue
            }) else {
                P256K.invariantFailure("secp256k1_context_randomize failed — library bug")
            }

            return context
        }

        /// Borrows the underlying `secp256k1_context` pointer for the duration of `body`.
        ///
        /// This is the explicit interop path for calling the `libsecp256k1` C API directly —
        /// the equivalent of rust-secp256k1's `Secp256k1::ctx()`, whose `&self` borrow scopes
        /// the pointer's validity to the owner. The closure scope reproduces that contract: the
        /// pointer is valid for the call and must not be stored or otherwise outlive this
        /// ``Context`` value.
        ///
        /// - Warning: Do not call `secp256k1_context_destroy`,
        ///   `secp256k1_context_preallocated_destroy`, or `secp256k1_context_randomize` on the
        ///   borrowed pointer — the owner manages its lifecycle, and those functions require
        ///   exclusive access anyway.
        /// - Parameter body: A closure receiving the context's `OpaquePointer`.
        /// - Returns: The value `body` returns.
        public func withUnsafeContextPointer<Result>(
            _ body: (OpaquePointer) throws -> Result
        ) rethrows -> Result {
            try withExtendedLifetime(storage) {
                try body(storage.context)
            }
        }
    }
}
