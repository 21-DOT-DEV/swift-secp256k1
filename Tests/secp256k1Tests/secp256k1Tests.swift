@testable import secp256k1
import XCTest

final class secp256k1Tests: XCTestCase {
    /// Uncompressed Key pair test
    func testUncompressedKeypairCreation() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubkeyLen = 65
        var cPubkey = secp256k1_pubkey()
        var publicKey = [UInt8](repeating: 0, count: pubkeyLen)

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        // Verify the context and keys are setup correctly
        XCTAssertEqual(secp256k1_context_randomize(context, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &cPubkey, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_serialize(context, &publicKey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)), 1)

        let hexString = """
        04734B3511150A60FC8CAC329CD5FF804555728740F2F2E98BC4242135EF5D5E4E6C4918116B0866F50C46614F3015D8667FBFB058471D662A642B8EA2C9C78E8A
        """

        // Define the expected public key
        let expectedPublicKey = try! hexString.bytes

        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, publicKey)
        XCTAssertEqual(hexString.lowercased(), String(bytes: publicKey))
    }

    /// Compressed Key pair test
    func testCompressedKeypairCreation() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubkeyLen = 33
        var cPubkey = secp256k1_pubkey()
        var publicKey = [UInt8](repeating: 0, count: pubkeyLen)
        let privateKey = try! "B035FCFC6ABF660856C5F3A6F9AC51FCA897BB4E76AD9ACA3EFD40DA6B9C864B".bytes

        // Verify the context and keys are setup correctly
        XCTAssertEqual(secp256k1_context_randomize(context, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &cPubkey, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_serialize(context, &publicKey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_COMPRESSED)), 1)

        // Define the expected public key
        let expectedPublicKey = try! "02EA724B70B48B61FB87E4310871A48C65BF38BF3FDFEFE73C2B90F8F32F9C1794".bytes

        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, publicKey)
    }

    func testECDHBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var point = secp256k1_pubkey()
        var res = [UInt8](repeating: 0, count: 32)
        var s_one = [UInt8](repeating: 0, count: 32)

        s_one[31] = 1

        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &point, s_one), 1)
        XCTAssertEqual(secp256k1_ecdh(context, &res, &point, s_one, nil, nil), 1)
    }

    func testExtraKeysBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var pubKey = secp256k1_pubkey()
        var xOnlyPubKey = secp256k1_xonly_pubkey()
        var pk_parity = Int32()

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &pubKey, privateKey), 1)
        XCTAssertEqual(secp256k1_xonly_pubkey_from_pubkey(context, &xOnlyPubKey, &pk_parity, &pubKey), 1)
    }

    func testRecoveryBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var pubKey = secp256k1_pubkey()
        var recsig = secp256k1_ecdsa_recoverable_signature()
        var message = [UInt8](repeating: 0, count: 32)

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        XCTAssertEqual(secp256k1_ec_seckey_verify(context, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &pubKey, privateKey), 1)
        XCTAssertEqual(secp256k1_ecdsa_sign_recoverable(context, &recsig, &message, privateKey, nil, nil), 1)
    }

    func testSchnorrBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        var keypair = secp256k1_keypair()
        var xpubKey = secp256k1_xonly_pubkey()
        var xpubKeyBytes = [UInt8](repeating: 0, count: 32)

        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes

        XCTAssertEqual(secp256k1_keypair_create(context, &keypair, privateKey), 1)
        XCTAssertEqual(secp256k1_keypair_xonly_pub(context, &xpubKey, nil, &keypair), 1)
        XCTAssertEqual(secp256k1_xonly_pubkey_serialize(context, &xpubKeyBytes, &xpubKey), 1)

        let expectedXPubKey = "734b3511150a60fc8cac329cd5ff804555728740f2f2e98bc4242135ef5d5e4e"

        XCTAssertEqual(String(bytes: xpubKeyBytes), expectedXPubKey)
    }

    /// Compressed Key pair test
    func testCompressedKeypairImplementationWithRaw() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)

        // Verify the keys matches the expected keys output
        XCTAssertEqual(expectedPrivateKey, String(bytes: privateKey.rawRepresentation))
        XCTAssertEqual(expectedPublicKey, String(bytes: privateKey.publicKey.rawRepresentation))
    }

    /// SHA256 test
    func testSha256() {
        let expectedHashDigest = "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342"
        let data = "For this sample, this 63-byte string will be used as input data".data(using: .utf8)!

        let digest = SHA256.hash(data: data)

        // Verify the hash digest matches the expected output
        XCTAssertEqual(expectedHashDigest, String(bytes: Array(digest)))
    }

    func testSigning() {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedSignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVg=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.ecdsa.signature(for: messageData)

        // Verify the signature matches the expected output
        XCTAssertEqual(expectedSignature, signature.rawRepresentation.base64EncodedString())
        XCTAssertEqual(expectedDerSignature, try! signature.derRepresentation.base64EncodedString())
    }

    func testSchnorrSigning() {
        let expectedDerSignature = "6QeDH4CEjRBppTcbQCQQNkvfHF+DB7AITFXxzi3KghUl9mpKheqLceSCp084LSzl6+7o/bIXL0d99JANMQU2wA=="
        let expectedSignature = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.schnorr.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Verify the signature matches the expected output
        XCTAssertEqual(expectedSignature, String(bytes: Array(signature.rawRepresentation)))
        XCTAssertEqual(expectedDerSignature, signature.rawRepresentation.base64EncodedString())
    }

    func testVerifying() {
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.ecdsa.signature(for: messageData)

        // Test the verification of the signature output
        XCTAssertTrue(privateKey.publicKey.ecdsa.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    func testSchnorrVerifyingPre() {
        let expectedPrivateKey = "4894b8087f428971b55ff96e16f7127340138bc84e7973821a224cad02055975"
        let expectedSignature = "ad57c21d383ef8ac799adfd469a221c40ef9f09563a16682b9ab1edc46c33d6d6a1d719761d269e87ab971e0ffafc1618a4666a4f9aef4abddc3ea9fc0cd5b12"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        var messageDigest = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!.bytes
        var auxRand = try! "f50c8c99e39a82f125fa83186b5f2483f39fb0fb56269c755689313a177be6ea".bytes

        let signature = try! privateKey.schnorr.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Test the verification of the signature output
        XCTAssertEqual(expectedSignature, String(bytes: signature.rawRepresentation.bytes))
        XCTAssertTrue(privateKey.publicKey.schnorr.isValid(signature, for: &messageDigest))
    }

    func testSchnorrVerifying() {
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes
        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.schnorr.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Test the verification of the signature output
        XCTAssertTrue(privateKey.publicKey.schnorr.isValid(signature, for: &messageDigest))
    }

    func testVerifyingDER() {
        let expectedDerSignature = Data(base64Encoded: "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A==", options: .ignoreUnknownCharacters)!
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! secp256k1.Signing.ECDSASignature(derRepresentation: expectedDerSignature)

        // Test the verification of the signature output
        XCTAssertTrue(privateKey.publicKey.ecdsa.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    func testPrivateKey() {
        XCTAssertNoThrow(try secp256k1.Signing.PrivateKey())
    }

    func testCompressedPublicKey() {
        let privateKey = try! secp256k1.Signing.PrivateKey()

        XCTAssertEqual(privateKey.publicKey.format, .compressed)
        XCTAssertEqual(privateKey.publicKey.rawRepresentation.count, secp256k1.Format.compressed.length)
    }

    func testUncompressedPublicKey() {
        let privateKey = try! secp256k1.Signing.PrivateKey(format: .uncompressed)

        XCTAssertEqual(privateKey.publicKey.format, .uncompressed)
        XCTAssertEqual(privateKey.publicKey.rawRepresentation.count, secp256k1.Format.uncompressed.length)
    }

    func testUncompressedPublicKeyWithKey() {
        let privateBytes = try! "703d3b63e84421e59f9359f8b27c25365df9d85b6b1566e3168412fa599c12f4".bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateBytes, format: .uncompressed)

        XCTAssertEqual(privateKey.publicKey.format, .uncompressed)
        XCTAssertEqual(privateKey.publicKey.rawRepresentation.count, secp256k1.Format.uncompressed.length)

        let expectedPublicKeyString = """
        04c9c68596824505dd6cd1993a16452b4b1a13bacde56f80e9049fd03850cce137c1fa4acb7bef7edcc04f4fa29e071ea17e34fa07fa5d87b5ebf6340df6558498
        """

        // Define the expected public key
        let expectedPublicKey = try! expectedPublicKeyString.bytes

        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, privateKey.publicKey.rawRepresentation.bytes)
        XCTAssertEqual(expectedPublicKeyString, String(bytes: privateKey.publicKey.rawRepresentation.bytes))
    }

    func testInvalidRawSignature() {
        XCTAssertThrowsError(
            try secp256k1.Signing.ECDSASignature(rawRepresentation: Data()),
            "Thrown Error", { error in
                XCTAssertEqual(error as? secp256k1Error, secp256k1Error.incorrectParameterSize)
            }
        )
    }

    func testInvalidDerSignature() {
        XCTAssertThrowsError(
            try secp256k1.Signing.ECDSASignature(derRepresentation: Data()),
            "Thrown Error", { error in
                XCTAssertEqual(error as? secp256k1Error, secp256k1Error.underlyingCryptoError)
            }
        )
    }

    func testInvalidPrivateKeyBytes() {
        let expectedPrivateKey = "55f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"

        XCTAssertThrowsError(try expectedPrivateKey.bytes)
    }

    func testInvalidPrivateKeyLength() {
        let expectedPrivateKey = "555f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes

        XCTAssertThrowsError(
            try secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes),
            "Thrown Error", { error in
                XCTAssertEqual(error as? secp256k1Error, secp256k1Error.incorrectKeySize)
            }
        )
    }

    func testKeypairSafeCompare() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        var privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey0 = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        let privateKey1 = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)

        // Verify the keys match
        XCTAssertEqual(privateKey0, privateKey1)

        let expectedFailingPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888dd"
        privateKeyBytes = try! expectedFailingPrivateKey.bytes
        let privateKey2 = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)

        XCTAssertNotEqual(privateKey0, privateKey2)
    }

    func testZeroization() {
        var array: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9]

        memset_s(&array, array.capacity, 0, array.capacity)

        let set0 = Set(array)

        array = [UInt8](repeating: 1, count: Int.random(in: 10...100_000))

        XCTAssertGreaterThan(array.count, 9)

        memset_s(&array, array.capacity, 0, array.capacity)

        let set1 = Set(array)

        XCTAssertEqual(set0.first, 0)
        XCTAssertEqual(set0.count, 1)
        XCTAssertEqual(set0, set1)
    }

    func testPrivateKeyTweakAdd() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let expectedTweakedPrivateKey = "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)
        let tweak = SHA256.hash(data: expectedPrivateKey.data(using: .utf8)!)

        // tweak the private key
        let tweakedPrivateKey = try! privateKey.add(xonly: Array(tweak))

        // Verify the keys matches the expected keys output
        XCTAssertEqual(String(bytes: tweakedPrivateKey.rawRepresentation), expectedTweakedPrivateKey)
        XCTAssertEqual(expectedPublicKey, String(bytes: privateKey.publicKey.rawRepresentation))
    }

    func testKeyAgreement() {
        let privateString1 = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let privateString2 = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"

        let privateBytes1 = try! privateString1.bytes
        let privateBytes2 = try! privateString2.bytes

        let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateBytes1)
        let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateBytes2)

        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey)

        XCTAssertEqual(sharedSecret1.bytes, sharedSecret2.bytes)
    }

    func testKeyAgreementPublicKeyTweakAdd() {
        let privateSign1 = try! secp256k1.Signing.PrivateKey()
        let privateSign2 = try! secp256k1.Signing.PrivateKey()

        let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateSign1.rawRepresentation)
        let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateSign2.rawRepresentation)

        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey)

        XCTAssertEqual(sharedSecret1.bytes, sharedSecret2.bytes)

        let sharedSecretSign1 = try! secp256k1.Signing.PrivateKey(rawRepresentation: sharedSecret1.bytes)
        let sharedSecretSign2 = try! secp256k1.Signing.PrivateKey(rawRepresentation: sharedSecret2.bytes)

        let privateTweak1 = try! sharedSecretSign1.add(xonly: privateSign1.publicKey.xonly.bytes)
        let publicTweak2 = try! sharedSecretSign2.publicKey.add(privateSign1.publicKey.xonly.bytes)
        let xonlyTweak2 = try! sharedSecretSign2.publicKey.xonly.add(privateSign1.publicKey.xonly.bytes)

        if sharedSecretSign2.publicKey.xonly.parity {
            XCTAssertNotEqual(privateTweak1.publicKey.rawRepresentation, publicTweak2.rawRepresentation)
        } else {
            XCTAssertEqual(privateTweak1.publicKey.rawRepresentation, publicTweak2.rawRepresentation)
        }

        XCTAssertEqual(privateTweak1.publicKey.xonly.bytes, xonlyTweak2.bytes)
    }

    static var allTests = [
        ("testUncompressedKeypairCreation", testUncompressedKeypairCreation),
        ("testCompressedKeypairCreation", testCompressedKeypairCreation),
        ("testECDHBindings", testECDHBindings),
        ("testExtraKeysBindings", testExtraKeysBindings),
        ("testRecoveryBindings", testRecoveryBindings),
        ("testSchnorrBindings", testSchnorrBindings),
        ("testCompressedKeypairImplementationWithRaw", testCompressedKeypairImplementationWithRaw),
        ("testSha256", testSha256),
        ("testSigning", testSigning),
        ("testSchnorrSigning", testSchnorrSigning),
        ("testVerifying", testVerifying),
        ("testSchnorrVerifyingPre", testSchnorrVerifyingPre),
        ("testSchnorrVerifying", testSchnorrVerifying),
        ("testVerifyingDER", testVerifyingDER),
        ("testPrivateKey", testPrivateKey),
        ("testCompressedPublicKey", testCompressedPublicKey),
        ("testUncompressedPublicKey", testUncompressedPublicKey),
        ("testUncompressedPublicKeyWithKey", testUncompressedPublicKeyWithKey),
        ("testInvalidRawSignature", testInvalidRawSignature),
        ("testInvalidDerSignature", testInvalidDerSignature),
        ("testInvalidPrivateKeyBytes", testInvalidPrivateKeyBytes),
        ("testInvalidPrivateKeyLength", testInvalidPrivateKeyLength),
        ("testKeypairSafeCompare", testKeypairSafeCompare),
        ("testZeroization", testZeroization),
        ("testPrivateKeyTweakAdd", testPrivateKeyTweakAdd),
        ("testKeyAgreement", testKeyAgreement),
        ("testKeyAgreementPublicKeyTweakAdd", testKeyAgreementPublicKeyTweakAdd)
    ]
}
