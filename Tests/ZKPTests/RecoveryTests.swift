//
//  RecoveryTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(ZKP)
    @testable import ZKP
#else
    @testable import P256K
#endif

import Testing
import XCTest

struct RecoveryTestSuite {
    @Test("Recovery signing test with expected recovery signature verification")
    func recoverySigningTest() {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedRecoverySignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVgE="
        let expectedSignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVg=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = try! privateKey.signature(for: messageData)

        // Verify the recovery signature matches the expected output
        #expect(recoverySignature.dataRepresentation.base64EncodedString() == expectedRecoverySignature)

        let signature = try! recoverySignature.normalize

        // Verify the signature matches the expected output
        #expect(signature.dataRepresentation.base64EncodedString() == expectedSignature)
        #expect(try! signature.derRepresentation.base64EncodedString() == expectedDerSignature)
    }

    @Test("Public key recovery test")
    func publicKeyRecoveryTest() {
        let expectedRecoverySignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVgE="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = try! privateKey.signature(for: messageData)

        // Verify the recovery signature matches the expected output
        #expect(recoverySignature.dataRepresentation.base64EncodedString() == expectedRecoverySignature)

        let publicKey = try! P256K.Recovery.PublicKey(messageData, signature: recoverySignature)

        // Verify the recovered public key matches the expected public key
        #expect(publicKey.dataRepresentation == privateKey.publicKey.dataRepresentation)
    }
}
