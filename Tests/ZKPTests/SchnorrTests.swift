//
//  SchnorrTests.swift
//  swift-secp256k1
//
//  Created by csjones on 2/10/25.
//

#if canImport(ZKP)
@testable import ZKP
#else
@testable import P256K
#endif

import XCTest
import Testing

struct SchnorrTestSuite {

    @Test("Schnorr Signing Test")
    func schnorrSigningTest() {
        let expectedDerSignature = "6QeDH4CEjRBppTcbQCQQNkvfHF+DB7AITFXxzi3KghUl9mpKheqLceSCp084LSzl6+7o/bIXL0d99JANMQU2wA=="
        let expectedSignature = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes
        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Verify the signature matches the expected output
        #expect(expectedSignature == String(bytes: Array(signature.dataRepresentation)))
        #expect(expectedDerSignature == signature.dataRepresentation.base64EncodedString())
    }
}
