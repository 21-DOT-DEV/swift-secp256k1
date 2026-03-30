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
    /// The 32-byte x-only form of a secp256k1 ``P256K/Signing/PublicKey``, as defined by BIP-340: the X coordinate of the public key point with implicit even-Y parity unless ``parity`` is `true`.
    struct XonlyKey: Sendable {
        /// The internal backing x-only key implementation.
        private let baseKey: XonlyKeyImplementation

        /// The 32-byte X coordinate of this x-only public key.
        public var bytes: [UInt8] {
            baseKey.bytes
        }

        /// The Y-coordinate parity of the underlying secp256k1 public key, as returned by `secp256k1_xonly_pubkey_from_pubkey`.
        ///
        /// `false` means the Y coordinate is even (the canonical BIP-340 form); `true` means it is odd
        /// (the public key point is the negation of the even-Y point with the same X coordinate).
        public var parity: Bool {
            baseKey.keyParity.boolValue
        }

        /// Creates a ``XonlyKey`` from a validated backing implementation.
        init(baseKey: XonlyKeyImplementation) {
            self.baseKey = baseKey
        }

        /// Creates a ``XonlyKey`` from a 32-byte X-coordinate and its Y-coordinate parity.
        ///
        /// - Parameter data: The 32-byte X coordinate of the x-only public key.
        /// - Parameter keyParity: The Y-coordinate parity as `Int32`: `0` = even, `1` = odd.
        public init<D: ContiguousBytes>(dataRepresentation data: D, keyParity: Int32) {
            self.baseKey = XonlyKeyImplementation(dataRepresentation: data.bytes, keyParity: keyParity)
        }
    }
}
