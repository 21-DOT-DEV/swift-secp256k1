//
//  DeprecatedAliasTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
@testable import P256K
import Testing

/// Equivalence pins for the `@available(*, deprecated, renamed:)` forwarders —
/// the old names must keep returning the same value, in their old shape, until
/// removal at 1.0. Upstream's own harness keeps the identical check ("Check that
/// deprecated alias gives the same result", `modules/schnorrsig/tests_impl.h`).
/// Each test is marked `@available(*, deprecated)` so exercising the aliases
/// emits no warnings; delete this suite with the aliases at 1.0.
struct DeprecatedAliasTestSuite {
    /// `P256K.Signing.XonlyKey.bytes` forwards to `dataRepresentation` as `[UInt8]`.
    @available(*, deprecated)
    @Test("Signing.XonlyKey.bytes returns dataRepresentation as [UInt8]")
    func signingXonlyBytesAlias() throws {
        let xonly = try P256K.Signing.PrivateKey().publicKey.xonly
        #expect(xonly.bytes == Array(xonly.dataRepresentation))
    }

    #if Xcode || ENABLE_MODULE_SCHNORRSIG
        /// `P256K.Schnorr.XonlyKey.bytes` forwards to `dataRepresentation` as `[UInt8]`.
        @available(*, deprecated)
        @Test("Schnorr.XonlyKey.bytes returns dataRepresentation as [UInt8]")
        func schnorrXonlyBytesAlias() throws {
            let xonly = try P256K.Schnorr.PrivateKey().xonly
            #expect(xonly.bytes == Array(xonly.dataRepresentation))
        }
    #endif

    #if Xcode || ENABLE_MODULE_MUSIG
        /// `P256K.MuSig.XonlyKey.bytes` forwards to `dataRepresentation` as `[UInt8]`.
        @available(*, deprecated)
        @Test("MuSig.XonlyKey.bytes returns dataRepresentation as [UInt8]")
        func musigXonlyBytesAlias() throws {
            let xonly = try P256K.MuSig.aggregate([P256K.Schnorr.PrivateKey().publicKey]).xonly
            #expect(xonly.bytes == Array(xonly.dataRepresentation))
        }
    #endif

    #if Xcode || ENABLE_MODULE_RECOVERY
        /// `P256K.Recovery.ECDSASignature.normalize` forwards to `signature` —
        /// the same standard-form signature, never low-S-normalized.
        @available(*, deprecated)
        @Test("ECDSASignature.normalize returns the same signature")
        func recoveryNormalizeAlias() throws {
            let recoverable = try P256K.Recovery.PrivateKey().signature(for: Data("deprecated alias".utf8))
            #expect(recoverable.normalize.dataRepresentation == recoverable.signature.dataRepresentation)
        }
    #endif
}
