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

/// A public extension that provides additional functionality to the `secp256k1` structure.
///
/// This extension includes a nested structure, `Context`, which represents the context for `secp256k1` operations.
/// The primary purpose of context objects is to store randomization data for enhanced protection against side-channel
/// leakage. This protection is only effective if the context is randomized after its creation.
///
/// A constructed context can safely be used from multiple threads simultaneously, but API calls that take a non-const
/// pointer to a context need exclusive access to it. In particular this is the case for `secp256k1_context_destroy`,
/// `secp256k1_context_preallocated_destroy`, and `secp256k1_context_randomize`.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// A structure that represents the context flags for `secp256k1` operations.
    ///
    /// The `Context` structure is used to create and manage the context for `secp256k1` operations.
    /// It is used in the creation of the `secp256k1` context and also in determining the size of the preallocated
    /// memory for the context.
    struct Context: Sendable {
        /// The raw representation of `secp256k1.Context`
        nonisolated(unsafe) public static let rawRepresentation = P256K.Context.create()

        /// The raw value of the context flags.
        static let rawValue = UInt32(SECP256K1_CONTEXT_NONE)

        /// Creates a new `secp256k1` context with the specified flags.
        ///
        /// - Precondition: Context creation and randomization must succeed.
        /// - Returns: An opaque pointer to the created context.
        ///
        /// This static method creates a new `secp256k1` context with the specified flags. The flags are represented by
        /// the `Context` structure. A precondition failure occurs if the context creation or randomization fails.
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
