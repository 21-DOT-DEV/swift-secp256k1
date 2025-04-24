//
//  Context.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2021 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(libsecp256k1_zkp)
    @_implementationOnly import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    @_implementationOnly import libsecp256k1
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
public extension P256K {
    /// A structure that represents the context flags for `secp256k1` operations.
    ///
    /// This structure conforms to the `OptionSet` protocol, allowing you to combine different context flags.
    /// It includes a static property, `none`, which represents a `Context` with no flags.
    ///
    /// The `Context` structure is used to create and manage the context for `secp256k1` operations.
    /// It is used in the creation of the `secp256k1` context and also in determining the size of the preallocated
    /// memory for the context.
    struct Context: OptionSet {
        /// The raw representation of `secp256k1.Context`
        public static let rawRepresentation = try! P256K.Context.create()

        /// The raw value of the context flags.
        public let rawValue: UInt32

        /// Creates a new `Context` instance with the specified raw value.
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        /// Initializes a new Context with the specified raw value.
        /// - Parameter rawValue: The Int32 raw value for the context flags.
        init(rawValue: Int32) { self.rawValue = UInt32(rawValue) }

        /// No context flag.
        ///
        /// This static property represents a `Context` with no flags. It can be used when creating a `secp256k1`
        /// context with no flags.
        public static let none = Self(rawValue: SECP256K1_CONTEXT_NONE)

        /// Creates a new `secp256k1` context with the specified flags.
        ///
        /// - Parameter context: The context flags to create a new `secp256k1` context.
        /// - Throws: An error of type `secp256k1Error.underlyingCryptoError` if the context creation or randomization
        /// fails.
        /// - Returns: An opaque pointer to the created context.
        ///
        /// This static method creates a new `secp256k1` context with the specified flags. The flags are represented by
        /// the `Context` structure. The method throws an error if the context creation or randomization fails. If the
        /// context creation is successful, the method returns an opaque pointer to the created context.
        public static func create(_ context: Self = .none) throws -> OpaquePointer {
            var randomBytes = SecureBytes(count: P256K.ByteLength.privateKey).bytes
            guard let context = secp256k1_context_create(context.rawValue),
                  secp256k1_context_randomize(context, &randomBytes).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            return context
        }
    }
}
