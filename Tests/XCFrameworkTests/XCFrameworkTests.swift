//
//  XCFrameworkTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import P256K
import Testing

struct XCFrameworkTestSuite {
    @Test("Compressed Key pair test with raw data")
    func compressedKeypairImplementationWithRaw() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

        #expect(String(bytes: privateKey.dataRepresentation) == expectedPrivateKey)
        #expect(String(bytes: privateKey.publicKey.dataRepresentation) == expectedPublicKey)
    }
}
