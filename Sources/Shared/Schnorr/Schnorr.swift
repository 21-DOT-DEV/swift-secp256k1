//
//  Schnorr.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

#if canImport(libsecp256k1_zkp)
    import libsecp256k1_zkp
#elseif canImport(libsecp256k1)
    import libsecp256k1
#endif

#if Xcode || ENABLE_MODULE_SCHNORRSIG

    @available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
    public extension P256K {
        enum Schnorr {
            /// Fixed number of bytes for Schnorr signature
            ///
            /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
            @inlinable static var signatureByteCount: Int {
                64
            }

            /// Fixed number of bytes for x-only key
            ///
            /// [BIP340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#abstract)
            @inlinable static var xonlyByteCount: Int {
                32
            }

            /// Tuple representation of ``SECP256K1_SCHNORRSIG_EXTRAPARAMS_MAGIC``
            ///
            /// Only used at initialization and has no other function than making sure the object is initialized.
            ///
            /// [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_schnorrsig.h#L88)
            @inlinable static var magic: (UInt8, UInt8, UInt8, UInt8) {
                (218, 111, 179, 140)
            }
        }
    }

#endif
