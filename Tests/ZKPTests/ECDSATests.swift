//
//  ECDSATests.swift
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

import Foundation
import Testing

struct ECDSATestSuite {
    @Test("Signing test with expected signature verification")
    func signingECDSA() {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedSignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVg=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.signature(for: messageData)

        // Verify the signature matches the expected output
        #expect(signature.dataRepresentation.base64EncodedString() == expectedSignature)
        #expect(try! signature.derRepresentation.base64EncodedString() == expectedDerSignature)
    }

    @Test("Signature Verification Test")
    func verifyingTest() {
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.signature(for: messageData)

        // Verify that the public key is valid for the generated signature
        #expect(privateKey.publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    @Test("DER Signature Verification Test")
    func verifyingDER() {
        let expectedDerSignature = Data(
            base64Encoded: "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A==",
            options: .ignoreUnknownCharacters
        )!
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! P256K.Signing.ECDSASignature(derRepresentation: expectedDerSignature)

        // Convert XCTAssertTrue to #expect
        #expect(privateKey.publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    @Test("Verify invalid raw signature initialization throws correct error")
    func testInvalidRawSignature() {
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Signing.ECDSASignature(dataRepresentation: Data())
        }
    }

    @Test("Verify invalid DER signature initialization throws correct error")
    func testInvalidDerSignature() {
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Signing.ECDSASignature(derRepresentation: Data())
        }
    }

    @Test("Signing with PEM representation")
    func testSigningPEM() {
        let privateKeyString = """
        -----BEGIN EC PRIVATE KEY-----
        MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
        oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
        2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END EC PRIVATE KEY-----
        """

        let expectedDerSignature = "MEQCIC8k5whKPsPg7XtWTInvhGL4iEU6lP6yPdpEXXZ2mOhFAiAZ3Po9tEDV8mQ8LDzwF0nhPmAn9VLYG8bkuY6PKruZNQ=="
        let privateKey = try! P256K.Signing.PrivateKey(pemRepresentation: privateKeyString)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.signature(for: messageData)

        // Verify the signature matches the expected output
        #expect(try! signature.derRepresentation.base64EncodedString() == expectedDerSignature, "Signature DER representation mismatch")
    }

    @Test("Verifying with PEM representation")
    func testVerifyingPEM() {
        let publicKeyString = """
        -----BEGIN PUBLIC KEY-----
        MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMA
        cjHIrTDS6HEELgguOatmFBOp2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END PUBLIC KEY-----
        """

        let expectedSignature = "MEQCIEwVxXLE/mwaRzxLvz9VIcMtHaa/Wf1WRxiBJ6NEuWHeAiAQWf2oqqBqEtBABbmwsXqjCJFvsaPt8o+VaOthto1kWQ=="
        let expectedDerSignature = Data(base64Encoded: expectedSignature, options: .ignoreUnknownCharacters)!

        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!
        let signature = try! P256K.Signing.ECDSASignature(derRepresentation: expectedDerSignature)
        let publicKey = try! P256K.Signing.PublicKey(pemRepresentation: publicKeyString)

        #expect(publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)), "Signature validation failed")
    }
}
