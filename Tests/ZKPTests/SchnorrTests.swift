//
//  SchnorrTests.swift
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

struct SchnorrTestSuite {
    @Test("Schnorr Signing Test")
    func schnorrSigningTest() {
        let expectedDerSignature = "6QeDH4CEjRBppTcbQCQQNkvfHF+DB7AITFXxzi3KghUl9mpKheqLceSCp084LSzl6+7o/bIXL0d99JANMQU2wA=="
        let expectedSignature = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes
        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Verify the signature matches the expected output
        #expect(expectedSignature == String(bytes: Array(signature.dataRepresentation)))
        #expect(expectedDerSignature == signature.dataRepresentation.base64EncodedString())
    }

    @Test("Schnorr Verifying Pre-Test")
    func schnorrVerifyingPreTest() {
        let expectedPrivateKey = "4894b8087f428971b55ff96e16f7127340138bc84e7973821a224cad02055975"
        let expectedSignature = "ad57c21d383ef8ac799adfd469a221c40ef9f09563a16682b9ab1edc46c33d6d6a1d719761d269e87ab971e0ffafc1618a4666a4f9aef4abddc3ea9fc0cd5b12"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let throwKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let privateKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!.bytes
        var auxRand = try! "f50c8c99e39a82f125fa83186b5f2483f39fb0fb56269c755689313a177be6ea".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Verify the signature matches the expected signature
        #expect(String(bytes: signature.dataRepresentation.bytes) == expectedSignature)

        // Verify the signature is valid
        #expect(privateKey.xonly.isValid(signature, for: &messageDigest))

        // Verify that an error is thrown for the strict signature case
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try throwKey.signature(message: &messageDigest, auxiliaryRand: &auxRand, strict: true)
        }
    }

    @Test("Schnorr Verifying Test")
    func schnorrVerifyingTest() {
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes
        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Test the verification of the signature output
        #expect(privateKey.xonly.isValid(signature, for: &messageDigest))
    }

    @Test("Test Schnorr Negating")
    func testSchnorrNegating() {
        let privateBytes = try! "56baa476b36a5b1548279f5bf57b82db39e594aee7912cde30977b8e80e6edca".bytes
        let negatedBytes = try! "a9455b894c95a4eab7d860a40a847d2380c94837c7b7735d8f3ae2fe4f4f5377".bytes

        let privateKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: privateBytes)
        let negatedKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: negatedBytes).negation

        #expect(privateKey == negatedKey, "Private key should equal negated key")
        #expect(privateKey.dataRepresentation == negatedKey.dataRepresentation, "Data representation of private key should equal negated key")
        #expect(privateKey.xonly == negatedKey.xonly, "Xonly of private key should equal negated key")
        #expect(privateKey.xonly.bytes == negatedKey.xonly.bytes, "Xonly bytes of private key should equal negated key")
    }
}
