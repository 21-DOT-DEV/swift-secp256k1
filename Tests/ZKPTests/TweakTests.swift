//
//  TweakTests.swift
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

struct TweakTestSuite {
    @Test("Verify private key tweak addition produces expected result")
    func testPrivateKeyTweakAdd() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let expectedTweakedPrivateKey = "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let tweak = SHA256.hash(data: expectedPrivateKey.data(using: .utf8)!)

        // Tweak the private key
        let tweakedPrivateKey = try! privateKey.add(xonly: Array(tweak))

        // Verify the tweaked private key matches expected value
        #expect(String(bytes: tweakedPrivateKey.dataRepresentation) == expectedTweakedPrivateKey)
        // Verify original public key remains correct
        #expect(expectedPublicKey == String(bytes: privateKey.publicKey.dataRepresentation))
    }
}
