//
//  Schnorr+XonlyKey.swift
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
        /// The corresponding x-only public key for the secp256k1 curve.
        struct XonlyKey: Equatable {
            /// Generated secp256k1 x-only public key.
            private let baseKey: XonlyKeyImplementation

            /// The secp256k1 x-only public key object.
            public var bytes: [UInt8] {
                baseKey.bytes
            }

            /// Schnorr x-only public key parity is implicitly even, therefore this always returns `false`.
            public var parity: Bool {
                baseKey.keyParity.boolValue
            }

            /// The cache of information about public key aggregation.
            public var cache: Data {
                Data(baseKey.cache)
            }

            /// Generates a secp256k1 x-only public key.
            ///
            /// - Parameter baseKey: Generated secp256k1 x-only public key.
            init(baseKey: XonlyKeyImplementation) {
                self.baseKey = baseKey
            }

            /// Generates a secp256k1 x-only public key from a raw representation.
            ///
            /// - Parameter data: A data representation of the x-only public key.
            /// - Parameter keyParity: The key parity as an `Int32`.
            public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32 = 0, cache: [UInt8] = []) {
                self.baseKey = XonlyKeyImplementation(dataRepresentation: data, keyParity: keyParity, cache: cache)
            }

            /// Determines if two x-only keys are equal.
            ///
            /// - Parameters:
            ///   - lhs: The left-hand side private key.
            ///   - rhs: The right-hand side private key.
            /// - Returns: True if the private keys are equal, false otherwise.
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.baseKey.bytes == rhs.baseKey.bytes
            }
        }
    }

#endif
