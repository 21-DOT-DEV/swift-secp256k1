//
//  AsymmetricTests.swift
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

struct AsymmetricTestSuite {

    @Test("Compressed Key pair test with raw data")
    func compressedKeypairImplementationWithRaw() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

        #expect(String(bytes: privateKey.dataRepresentation) == expectedPrivateKey)
        #expect(String(bytes: privateKey.publicKey.dataRepresentation) == expectedPublicKey)
    }

    @Test("Verify initialization of private key does not throw an error")
    func testPrivateKey() {
        #expect((try? P256K.Signing.PrivateKey()) != nil)
    }

    @Test("Verify compressed public key characteristics")
    func testCompressedPublicKey() {
        let privateKey = try! P256K.Signing.PrivateKey()
        #expect(privateKey.publicKey.format == .compressed, "PublicKey format should be compressed")
        #expect(privateKey.publicKey.dataRepresentation.count == P256K.Format.compressed.length, "PublicKey length mismatch for compressed format")
    }

    @Test("Verify uncompressed public key characteristics")
    func testUncompressedPublicKey() {
        let privateKey = try! P256K.Signing.PrivateKey(format: .uncompressed)
        #expect(privateKey.publicKey.format == .uncompressed, "PublicKey format should be uncompressed")
        #expect(privateKey.publicKey.dataRepresentation.count == P256K.Format.uncompressed.length, "PublicKey length mismatch for uncompressed format")
    }

    @Test("Verify uncompressed public key with specific bytes")
    func testUncompressedPublicKeyWithKey() {
        let privateBytes = try! "703d3b63e84421e59f9359f8b27c25365df9d85b6b1566e3168412fa599c12f4".bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateBytes, format: .uncompressed)
        #expect(privateKey.publicKey.format == .uncompressed, "PublicKey format should be uncompressed")
        #expect(privateKey.publicKey.dataRepresentation.count == P256K.Format.uncompressed.length, "PublicKey length mismatch for uncompressed format")

        let expectedPublicKeyString = "04c9c68596824505dd6cd1993a16452b4b1a13bacde56f80e9049fd03850cce137c1fa4acb7bef7edcc04f4fa29e071ea17e34fa07fa5d87b5ebf6340df6558498"
        let expectedPublicKey = try! expectedPublicKeyString.bytes

        #expect(expectedPublicKey == privateKey.publicKey.bytes, "PublicKey bytes do not match expected value")
        #expect(expectedPublicKeyString == String(bytes: privateKey.publicKey.bytes), "PublicKey string representation mismatch")
    }

    @Test("Verify invalid private key bytes throw appropriate error")
    func testInvalidPrivateKeyBytes() {
        let expectedPrivateKey = "55f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        #expect(throws: (any Error).self) {
            _ = try expectedPrivateKey.bytes
        }
    }

    @Test("Verify initialization with invalid private key length throws appropriate error")
    func testInvalidPrivateKeyLength() {
        let expectedPrivateKey = "555f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes

        #expect(throws: secp256k1Error.incorrectKeySize) {
            try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        }
    }

    @Test("Test conversion of xonly public key to full public key")
    func testXonlyToPublicKey() {
        let privateKey = try! P256K.Signing.PrivateKey()
        let publicKey = P256K.Signing.PublicKey(xonlyKey: privateKey.publicKey.xonly)

        #expect(privateKey.publicKey.dataRepresentation == publicKey.dataRepresentation, "Public key data representations should match")
    }

    @Test("Public Key Combination Test")
    func testPubkeyCombine() {
        let publicKeyBytes1 = try! "021b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014".bytes
        let publicKeyBytes2 = try! "0260303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752".bytes

        let publicKey1 = try! P256K.Signing.PublicKey(dataRepresentation: publicKeyBytes1, format: .compressed)
        let publicKey2 = try! P256K.Signing.PublicKey(dataRepresentation: publicKeyBytes2, format: .compressed)

        let combinedPublicKey = try! publicKey1.combine([publicKey2])

        let expectedCombinedKey = try! "03d6a3a9d62c7650fcac18f9ee68c7a004ebad71b7581b683062213ad9f37ddb28".bytes

        #expect(combinedPublicKey.dataRepresentation.bytes == expectedCombinedKey, "Combined public key does not match the expected value.")
    }

    @Test("Private Key PEM Test")
    func testPrivateKeyPEM() {
        let privateKeyString = """
        -----BEGIN EC PRIVATE KEY-----
        MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
        oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
        2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END EC PRIVATE KEY-----
        """

        let privateKey = try! P256K.Signing.PrivateKey(pemRepresentation: privateKeyString)
        let expectedPrivateKey = "15f01cf0e979ce9bd3b19e2db9f07ad4f476f5b3a749d5dcc47ee293ca5c873b"

        #expect(expectedPrivateKey == String(bytes: privateKey.dataRepresentation), "Private key PEM data does not match the expected value.")
    }

    @Test("Public Key PEM Test")
    func testPublicKeyPEM() {
        let publicKeyString = """
        -----BEGIN PUBLIC KEY-----
        MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMA
        cjHIrTDS6HEELgguOatmFBOp2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END PUBLIC KEY-----
        """

        let privateKeyBytes = try! "15f01cf0e979ce9bd3b19e2db9f07ad4f476f5b3a749d5dcc47ee293ca5c873b".bytes
        let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes, format: .uncompressed)
        let publicKey = try! P256K.Signing.PublicKey(pemRepresentation: publicKeyString)

        #expect(privateKey.publicKey.dataRepresentation == publicKey.dataRepresentation, "Public key PEM data representation does not match the expected value.")
    }

}
