//
//  ECDHTests.swift
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

struct ECDHTestSuite {
    @Test("Test Key Agreement")
    func testKeyAgreement() {
        let privateString1 = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let privateString2 = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"

        let privateBytes1 = try! privateString1.bytes
        let privateBytes2 = try! privateString2.bytes

        let privateKey1 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateBytes1)
        let privateKey2 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateBytes2)

        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey, format: .uncompressed)
        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey, format: .uncompressed)

        #expect(sharedSecret1.bytes == sharedSecret2.bytes, "Shared secrets should be equal")
    }

    @Test("Test Key Agreement Public Key Tweak Addition")
    func testKeyAgreementPublicKeyTweakAdd() {
        let privateSign1 = try! P256K.Signing.PrivateKey()
        let privateSign2 = try! P256K.Signing.PrivateKey()

        let privateKey1 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign1.dataRepresentation)
        let privateKey2 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign2.dataRepresentation)

        let publicKey1 = try! P256K.KeyAgreement.PublicKey(dataRepresentation: privateKey1.publicKey.dataRepresentation)

        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: publicKey1)

        #expect(sharedSecret1.bytes == sharedSecret2.bytes, "Shared secrets should be equal")

        let symmetricKey1 = SHA256.hash(data: sharedSecret1.bytes)
        let symmetricKey2 = SHA256.hash(data: sharedSecret2.bytes)

        let sharedSecretSign1 = try! P256K.Signing.PrivateKey(dataRepresentation: symmetricKey1.bytes)
        let sharedSecretSign2 = try! P256K.Signing.PrivateKey(dataRepresentation: symmetricKey2.bytes)

        let privateTweak1 = try! sharedSecretSign1.add(xonly: privateSign1.publicKey.xonly.bytes)
        let publicTweak2 = try! sharedSecretSign2.publicKey.add(privateSign1.publicKey.xonly.bytes)

        let schnorrPrivate = try! P256K.Schnorr.PrivateKey(dataRepresentation: sharedSecretSign2.dataRepresentation)
        let xonlyTweak2 = try! schnorrPrivate.xonly.add(privateSign1.publicKey.xonly.bytes)

        #expect(
            sharedSecretSign2.publicKey.xonly.parity
                ? privateTweak1.publicKey.dataRepresentation != publicTweak2.dataRepresentation
                : privateTweak1.publicKey.dataRepresentation == publicTweak2.dataRepresentation,
            "Tweak addition expectation mismatch based on parity"
        )

        #expect(privateTweak1.publicKey.xonly.bytes == xonlyTweak2.bytes, "Xonly tweaks do not match")
    }
}
