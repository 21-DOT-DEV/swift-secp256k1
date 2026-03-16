//
//  P256K.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
#if CRYPTOKIT_NO_ACCESS_TO_FOUNDATION
    import SwiftSystem
#else
    #if canImport(FoundationEssentials)
        import FoundationEssentials
    #else
        import Foundation
    #endif
#endif

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

/// The secp256k1 Elliptic Curve.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public enum P256K: Sendable {}

/// An extension to secp256k1 containing an enum for public key formats.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// Enum representing public key formats to be passed to `secp256k1_ec_pubkey_serialize`.
    enum Format: UInt32, Sendable {
        /// Compressed public key format.
        case compressed
        /// Uncompressed public key format.
        case uncompressed

        /// The length of the public key in bytes, based on the format.
        public var length: Int {
            switch self {
            case .compressed: return P256K.ByteLength.dimension + 1
            case .uncompressed: return 2 * P256K.ByteLength.dimension + 1
            }
        }

        /// The raw UInt32 value corresponding to the public key format.
        public var rawValue: UInt32 {
            let value: Int32

            switch self {
            case .compressed: value = SECP256K1_EC_COMPRESSED
            case .uncompressed: value = SECP256K1_EC_UNCOMPRESSED
            }

            return UInt32(value)
        }
    }
}

/// An extension for secp256k1 containing nested enum byte length details.
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K {
    /// An enum containing byte details about in secp256k1.
    @usableFromInline
    enum ByteLength {
        /// Number of bytes for one dimension of a secp256k1 coordinate.
        @inlinable
        static var dimension: Int {
            32
        }

        /// Number of bytes in a secp256k1 private key.
        @inlinable
        static var privateKey: Int {
            32
        }

        /// Number of bytes in a secp256k1 signature.
        @inlinable
        static var signature: Int {
            64
        }

        /// Number of bytes in a secp256k1 signature.
        @inlinable
        static var partialSignature: Int {
            36
        }

        @inlinable
        static var uncompressedPublicKey: Int {
            65
        }
    }
}
