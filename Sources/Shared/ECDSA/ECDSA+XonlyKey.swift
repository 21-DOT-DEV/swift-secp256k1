//
//  ECDSA+XonlyKey.swift
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

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K.Signing {
    /// The corresponding x-only public key for the secp256k1 curve.
    struct XonlyKey: Sendable {
        /// Generated secp256k1 x-only public key.
        private let baseKey: XonlyKeyImplementation

        /// The secp256k1 x-only public key object.
        public var bytes: [UInt8] {
            baseKey.bytes
        }

        /// A boolean that indicates the point's parity.
        ///
        /// Set to `true` if the point encoded by the x-only public key is the negation of the public key,
        /// and set to `false` otherwise.
        public var parity: Bool {
            baseKey.keyParity.boolValue
        }

        /// Generates a secp256k1 x-only public key.
        ///
        /// - Parameter baseKey: Generated secp256k1 x-only public key.
        init(baseKey: XonlyKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Generates a secp256k1 x-only public key from a raw representation and key parity.
        ///
        /// - Parameter data: A data representation of the x-only public key.
        /// - Parameter keyParity: The key parity as an `Int32`.
        public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32) {
            self.baseKey = XonlyKeyImplementation(dataRepresentation: data.bytes, keyParity: keyParity)
        }
    }
}
