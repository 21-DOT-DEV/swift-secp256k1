#if canImport(zkp)
    @testable import zkp
#else
    @testable import secp256k1
#endif

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
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

        // Verify the keys matches the expected keys output
        XCTAssertEqual(expectedPrivateKey, String(bytes: privateKey.dataRepresentation))
        XCTAssertEqual(expectedPublicKey, String(bytes: privateKey.publicKey.dataRepresentation))
    }

    /// SHA256 test
    func testSha256() {
        let expectedHashDigest = "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342"
        let data = "For this sample, this 63-byte string will be used as input data".data(using: .utf8)!

        let digest = SHA256.hash(data: data)

        // Verify the hash digest matches the expected output
        XCTAssertEqual(expectedHashDigest, String(bytes: Array(digest)))
    }

    func testShaHashDigest() {
        let expectedHash = try! "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342".bytes
        let data = "For this sample, this 63-byte string will be used as input data".data(using: .utf8)!

        let digest = SHA256.hash(data: data)

        let constructedDigest = HashDigest(expectedHash)

        // Verify the generated hash digest matches the manual constructed hash digest
        XCTAssertEqual(String(bytes: Array(digest)), String(bytes: Array(constructedDigest)))
    }

    func testSigning() {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedSignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVg=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.signature(for: messageData)

        // Verify the signature matches the expected output
        XCTAssertEqual(expectedSignature, signature.dataRepresentation.base64EncodedString())
        XCTAssertEqual(expectedDerSignature, try! signature.derRepresentation.base64EncodedString())
    }

    func testRecoverySigning() {
        let expectedDerSignature = "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A=="
        let expectedRecoverySignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVgE="
        let expectedSignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVg=="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = try! privateKey.signature(for: messageData)

        // Verify the recovery signature matches the expected output
        XCTAssertEqual(expectedRecoverySignature, recoverySignature.dataRepresentation.base64EncodedString())

        let signature = try! recoverySignature.normalize

        // Verify the signature matches the expected output
        XCTAssertEqual(expectedSignature, signature.dataRepresentation.base64EncodedString())
        XCTAssertEqual(expectedDerSignature, try! signature.derRepresentation.base64EncodedString())
    }

    func testPublicKeyRecovery() {
        let expectedRecoverySignature = "rPnhleCU8vQOthm5h4gX/5UbmxH6w3zw1ykAmLvvtXT4YGKBoiMaP8eBBF8upN8IaTYmO7+o0Vyhf+cODD1uVgE="
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Recovery.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let recoverySignature = try! privateKey.signature(for: messageData)

        // Verify the recovery signature matches the expected output
        XCTAssertEqual(expectedRecoverySignature, recoverySignature.dataRepresentation.base64EncodedString())

        let publicKey = try! secp256k1.Recovery.PublicKey(messageData, signature: recoverySignature)

        // Verify the recovered public key matches the expected public key
        XCTAssertEqual(publicKey.dataRepresentation, privateKey.publicKey.dataRepresentation)
    }

    func testSchnorrSigning() {
        let expectedDerSignature = "6QeDH4CEjRBppTcbQCQQNkvfHF+DB7AITFXxzi3KghUl9mpKheqLceSCp084LSzl6+7o/bIXL0d99JANMQU2wA=="
        let expectedSignature = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Verify the signature matches the expected output
        XCTAssertEqual(expectedSignature, String(bytes: Array(signature.dataRepresentation)))
        XCTAssertEqual(expectedDerSignature, signature.dataRepresentation.base64EncodedString())
    }

    func testVerifying() {
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.signature(for: messageData)

        // Test the verification of the signature output
        XCTAssertTrue(privateKey.publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    func testSchnorrVerifyingPre() {
        let expectedPrivateKey = "4894b8087f428971b55ff96e16f7127340138bc84e7973821a224cad02055975"
        let expectedSignature = "ad57c21d383ef8ac799adfd469a221c40ef9f09563a16682b9ab1edc46c33d6d6a1d719761d269e87ab971e0ffafc1618a4666a4f9aef4abddc3ea9fc0cd5b12"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let throwKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let privateKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!.bytes
        var auxRand = try! "f50c8c99e39a82f125fa83186b5f2483f39fb0fb56269c755689313a177be6ea".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Test the verification of the signature output
        XCTAssertEqual(expectedSignature, String(bytes: signature.dataRepresentation.bytes))
        XCTAssertTrue(privateKey.xonly.isValid(signature, for: &messageDigest))
        XCTAssertThrowsError(try throwKey.signature(message: &messageDigest, auxiliaryRand: &auxRand, strict: true))
    }

    func testSchnorrVerifying() {
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        var messageDigest = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes
        var auxRand = try! "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)

        // Test the verification of the signature output
        XCTAssertTrue(privateKey.xonly.isValid(signature, for: &messageDigest))
    }

    func testVerifyingDER() {
        let expectedDerSignature = Data(base64Encoded: "MEQCIHS177uYACnX8HzD+hGbG5X/F4iHuRm2DvTylOCV4fmsAiBWbj0MDud/oVzRqL87JjZpCN+kLl8Egcc/GiOigWJg+A==", options: .ignoreUnknownCharacters)!
        let expectedPrivateKey = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"
        let privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! secp256k1.Signing.ECDSASignature(derRepresentation: expectedDerSignature)

        // Test the verification of the signature output
        XCTAssertTrue(privateKey.publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    func testPrivateKey() {
        XCTAssertNoThrow(try secp256k1.Signing.PrivateKey())
    }

    func testCompressedPublicKey() {
        let privateKey = try! secp256k1.Signing.PrivateKey()

        XCTAssertEqual(privateKey.publicKey.format, .compressed)
        XCTAssertEqual(privateKey.publicKey.dataRepresentation.count, secp256k1.Format.compressed.length)
    }

    func testUncompressedPublicKey() {
        let privateKey = try! secp256k1.Signing.PrivateKey(format: .uncompressed)

        XCTAssertEqual(privateKey.publicKey.format, .uncompressed)
        XCTAssertEqual(privateKey.publicKey.dataRepresentation.count, secp256k1.Format.uncompressed.length)
    }

    func testUncompressedPublicKeyWithKey() {
        let privateBytes = try! "703d3b63e84421e59f9359f8b27c25365df9d85b6b1566e3168412fa599c12f4".bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateBytes, format: .uncompressed)

        XCTAssertEqual(privateKey.publicKey.format, .uncompressed)
        XCTAssertEqual(privateKey.publicKey.dataRepresentation.count, secp256k1.Format.uncompressed.length)

        let expectedPublicKeyString = """
        04c9c68596824505dd6cd1993a16452b4b1a13bacde56f80e9049fd03850cce137c1fa4acb7bef7edcc04f4fa29e071ea17e34fa07fa5d87b5ebf6340df6558498
        """

        // Define the expected public key
        let expectedPublicKey = try! expectedPublicKeyString.bytes

        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, privateKey.publicKey.bytes)
        XCTAssertEqual(expectedPublicKeyString, String(bytes: privateKey.publicKey.bytes))
    }

    func testInvalidRawSignature() {
        XCTAssertThrowsError(
            try secp256k1.Signing.ECDSASignature(dataRepresentation: Data()),
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
            try secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes),
            "Thrown Error", { error in
                XCTAssertEqual(error as? secp256k1Error, secp256k1Error.incorrectKeySize)
            }
        )
    }

    func testKeypairSafeCompare() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        var privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey0 = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let privateKey1 = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

        // Verify the keys match
        XCTAssertEqual(privateKey0, privateKey1)

        let expectedFailingPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888dd"
        privateKeyBytes = try! expectedFailingPrivateKey.bytes
        let privateKey2 = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

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
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let tweak = SHA256.hash(data: expectedPrivateKey.data(using: .utf8)!)

        // tweak the private key
        let tweakedPrivateKey = try! privateKey.add(xonly: Array(tweak))

        // Verify the keys matches the expected keys output
        XCTAssertEqual(String(bytes: tweakedPrivateKey.dataRepresentation), expectedTweakedPrivateKey)
        XCTAssertEqual(expectedPublicKey, String(bytes: privateKey.publicKey.dataRepresentation))
    }

    func testKeyAgreement() {
        let privateString1 = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let privateString2 = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"

        let privateBytes1 = try! privateString1.bytes
        let privateBytes2 = try! privateString2.bytes

        let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey(dataRepresentation: privateBytes1)
        let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey(dataRepresentation: privateBytes2)

        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey, format: .uncompressed)
        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey, format: .uncompressed)

        XCTAssertEqual(sharedSecret1.bytes, sharedSecret2.bytes)
    }

    func testKeyAgreementHashFunction() {
        let context = secp256k1.Context.rawRepresentation
        let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey()
        let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey()

        var pub = secp256k1_pubkey()
        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        var sharedSecret2 = [UInt8](repeating: 0, count: 32)

        XCTAssertEqual(secp256k1_ec_pubkey_parse(context, &pub, privateKey1.publicKey.bytes, privateKey1.publicKey.bytes.count), 1)
        XCTAssertEqual(secp256k1_ecdh(context, &sharedSecret2, &pub, privateKey2.baseKey.key.bytes, nil, nil), 1)

        let symmerticKey = SHA256.hash(data: sharedSecret1.bytes)

        XCTAssertEqual(symmerticKey.bytes, sharedSecret2)
    }

    func testKeyAgreementPublicKeyTweakAdd() {
        let privateSign1 = try! secp256k1.Signing.PrivateKey()
        let privateSign2 = try! secp256k1.Signing.PrivateKey()

        let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey(dataRepresentation: privateSign1.dataRepresentation)
        let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey(dataRepresentation: privateSign2.dataRepresentation)

        let publicKey1 = try! secp256k1.KeyAgreement.PublicKey(dataRepresentation: privateKey1.publicKey.dataRepresentation)

        let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: publicKey1)

        XCTAssertEqual(sharedSecret1.bytes, sharedSecret2.bytes)

        let symmetricKey1 = SHA256.hash(data: sharedSecret1.bytes)
        let symmetricKey2 = SHA256.hash(data: sharedSecret2.bytes)

        let sharedSecretSign1 = try! secp256k1.Signing.PrivateKey(dataRepresentation: symmetricKey1.bytes)
        let sharedSecretSign2 = try! secp256k1.Signing.PrivateKey(dataRepresentation: symmetricKey2.bytes)

        let privateTweak1 = try! sharedSecretSign1.add(xonly: privateSign1.publicKey.xonly.bytes)
        let publicTweak2 = try! sharedSecretSign2.publicKey.add(privateSign1.publicKey.xonly.bytes)

        let schnorrPrivate = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: sharedSecretSign2.dataRepresentation)
        let xonlyTweak2 = try! schnorrPrivate.xonly.add(privateSign1.publicKey.xonly.bytes)

        if sharedSecretSign2.publicKey.xonly.parity {
            XCTAssertNotEqual(privateTweak1.publicKey.dataRepresentation, publicTweak2.dataRepresentation)
        } else {
            XCTAssertEqual(privateTweak1.publicKey.dataRepresentation, publicTweak2.dataRepresentation)
        }

        XCTAssertEqual(privateTweak1.publicKey.xonly.bytes, xonlyTweak2.bytes)
    }

    func testXonlyToPublicKey() {
        let privateKey = try! secp256k1.Signing.PrivateKey()
        let publicKey = secp256k1.Signing.PublicKey(xonlyKey: privateKey.publicKey.xonly)

        XCTAssertEqual(privateKey.publicKey.dataRepresentation, publicKey.dataRepresentation)
    }

    func testTapscript() {
        let OP_CHECKSEQUENCEVERIFY = Data([0xB2])
        let OP_DROP = Data([0x75])
        let OP_CHECKSIG = Data([0xAC])
        let OP_SHA256 = Data([0xA8])
        let OP_EQUALVERIFY = Data([0x88])

        var value = UInt64(144)
        let numberOfBytes = ((64 - value.leadingZeroBitCount) / 8) + 1
        let array = withUnsafeBytes(of: &value) { Array($0).prefix(numberOfBytes) }

        let aliceBytes = try! "2bd806c97f0e00af1a1fc3328fa763a9269723c8db8fac4f93af71db186d6e90".bytes
        let alice = try! secp256k1.Signing.PrivateKey(dataRepresentation: aliceBytes)
        let aliceScript = Data([UInt8(array.count)] + array) +
            OP_CHECKSEQUENCEVERIFY +
            OP_DROP +
            Data([UInt8(alice.publicKey.xonly.bytes.count)] + alice.publicKey.xonly.bytes) +
            OP_CHECKSIG
        let aliceLeafHash = try! SHA256.taggedHash(
            tag: "TapLeaf".data(using: .utf8)!,
            data: Data([0xC0]) + aliceScript.compactSizePrefix
        )

        let aliceExpectedLeafHash = "c81451874bd9ebd4b6fd4bba1f84cdfb533c532365d22a0a702205ff658b17c9"

        XCTAssertEqual(String(bytes: Array(aliceLeafHash).bytes), aliceExpectedLeafHash)

        let bobBytes = try! "81b637d8fcd2c6da6359e6963113a1170de795e4b725b84d1e0b4cfd9ec58ce9".bytes
        let bob = try! secp256k1.Signing.PrivateKey(dataRepresentation: bobBytes)
        let preimageBytes = try! "6c60f404f8167a38fc70eaf8aa17ac351023bef86bcb9d1086a19afe95bd5333".bytes
        let bobScript = OP_SHA256 +
            Data([UInt8(preimageBytes.count)] + preimageBytes.bytes) +
            OP_EQUALVERIFY +
            Data([UInt8(bob.publicKey.xonly.bytes.count)] + bob.publicKey.xonly.bytes) +
            OP_CHECKSIG
        let bobLeafHash = try! SHA256.taggedHash(
            tag: "TapLeaf".data(using: .utf8)!,
            data: Data([0xC0]) + bobScript.compactSizePrefix
        )

        let bobExpectedLeafHash = "632c8632b4f29c6291416e23135cf78ecb82e525788ea5ed6483e3c6ce943b42"

        XCTAssertEqual(String(bytes: Array(bobLeafHash).bytes), bobExpectedLeafHash)

        var leftHash, rightHash: Data
        if aliceLeafHash < bobLeafHash {
            leftHash = Data(aliceLeafHash)
            rightHash = Data(bobLeafHash)
        } else {
            leftHash = Data(bobLeafHash)
            rightHash = Data(aliceLeafHash)
        }

        let merkleRoot = try! SHA256.taggedHash(
            tag: "TapBranch".data(using: .utf8)!,
            data: leftHash + rightHash
        )

        let expectedMerkleRoot = "41646f8c1fe2a96ddad7f5471bc4fee7da98794ef8c45a4f4fc6a559d60c9f6b"

        XCTAssertEqual(String(bytes: Array(merkleRoot).bytes), expectedMerkleRoot)
    }

    func testCompactSizePrefix() {
        let bytes = try! "c15bf08d58a430f8c222bffaf9127249c5cdff70a2d68b2b45637eb662b6b88eb5c81451874bd9ebd4b6fd4bba1f84cdfb533c532365d22a0a702205ff658b17c9".bytes
        let compactBytes = "41c15bf08d58a430f8c222bffaf9127249c5cdff70a2d68b2b45637eb662b6b88eb5c81451874bd9ebd4b6fd4bba1f84cdfb533c532365d22a0a702205ff658b17c9"
        XCTAssertEqual(compactBytes, String(bytes: Array(Data(bytes).compactSizePrefix)), "Compact size prefix encoding is incorrect.")
    }

    func testSchnorrNegating() {
        let privateBytes = try! "56baa476b36a5b1548279f5bf57b82db39e594aee7912cde30977b8e80e6edca".bytes
        let negatedBytes = try! "a9455b894c95a4eab7d860a40a847d2380c94837c7b7735d8f3ae2fe4f4f5377".bytes

        let privateKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateBytes)
        let negatedKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: negatedBytes).negation

        XCTAssertEqual(privateKey, negatedKey)
        XCTAssertEqual(privateKey.dataRepresentation, negatedKey.dataRepresentation)
        XCTAssertEqual(privateKey.xonly, negatedKey.xonly)
        XCTAssertEqual(privateKey.xonly.bytes, negatedKey.xonly.bytes)
    }

    func testTaprootDerivation() {
        let privateKeyBytes = try! "41F41D69260DF4CF277826A9B65A3717E4EEDDBEEDF637F212CA096576479361".bytes
        let privateKey = try! secp256k1.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let internalKeyBytes = try! "cc8a4bc64d897bddc5fbc2f670f7a8ba0b386779106cf1223c6fc5d7cd6fc115".bytes
        let internalKey = privateKey.xonly

        XCTAssertEqual(internalKey.bytes, internalKeyBytes)

        let tweakHash = try! SHA256.taggedHash(
            tag: "TapTweak".data(using: .utf8)!,
            data: Data(internalKey.bytes)
        )

        let outputKeyBytes = try! "a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c".bytes
        let outputKey = try! internalKey.add(tweakHash.bytes)

        XCTAssertEqual(outputKey.bytes, outputKeyBytes)
    }

    func testPubkeyCombine() {
        let publicKeyBytes1 = try! "021b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014".bytes
        let publicKeyBytes2 = try! "0260303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752".bytes

        let publicKey1 = try! secp256k1.Signing.PublicKey(dataRepresentation: publicKeyBytes1, format: .compressed)
        let publicKey2 = try! secp256k1.Signing.PublicKey(dataRepresentation: publicKeyBytes2, format: .compressed)

        let combinedPublicKey = try! publicKey1.combine([publicKey2])

        // Define the expected combined key
        let expectedCombinedKey = try! "03d6a3a9d62c7650fcac18f9ee68c7a004ebad71b7581b683062213ad9f37ddb28".bytes

        XCTAssertEqual(combinedPublicKey.dataRepresentation.bytes, expectedCombinedKey)
    }

    func testPubkeyCombineBindings() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE))!

        // Destroy context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubKeyLen = 33
        var cPubKey1 = secp256k1_pubkey()
        var cPubKey2 = secp256k1_pubkey()

        let publicKeyBytes1 = try! "021b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014".bytes
        let publicKeyBytes2 = try! "0260303ae22b998861bce3b28f33eec1be758a213c86c93c076dbe9f558c11c752".bytes

        // Verify the context and keys are setup correctly
        XCTAssertEqual(secp256k1_ec_pubkey_parse(context, &cPubKey1, publicKeyBytes1, pubKeyLen), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_parse(context, &cPubKey2, publicKeyBytes2, pubKeyLen), 1)

        let pubKeys: [UnsafePointer<secp256k1_pubkey>?] = [UnsafePointer(&cPubKey1), UnsafePointer(&cPubKey2)]
        var combinedKey = secp256k1_pubkey()
        var combinedKeyBytes = [UInt8](repeating: 0, count: pubKeyLen)

        // Combine the two public keys
        XCTAssertEqual(secp256k1_ec_pubkey_combine(context, &combinedKey, pubKeys, 2), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_serialize(context, &combinedKeyBytes, &pubKeyLen, &combinedKey, secp256k1.Format.compressed.rawValue), 1)

        // Define the expected combined key
        let expectedCombinedKey = try! "03d6a3a9d62c7650fcac18f9ee68c7a004ebad71b7581b683062213ad9f37ddb28".bytes

        XCTAssertEqual(combinedKeyBytes, expectedCombinedKey)
    }

    func testPrivateKeyPEM() {
        let privateKeyString = """
        -----BEGIN EC PRIVATE KEY-----
        MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
        oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
        2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END EC PRIVATE KEY-----
        """

        let privateKey = try! secp256k1.Signing.PrivateKey(pemRepresentation: privateKeyString)
        let expectedPrivateKey = "15f01cf0e979ce9bd3b19e2db9f07ad4f476f5b3a749d5dcc47ee293ca5c873b"

        // Verify the keys matches the expected keys output
        XCTAssertEqual(expectedPrivateKey, String(bytes: privateKey.dataRepresentation))
    }

    func testPublicKeyPEM() {
        let publicKeyString = """
        -----BEGIN PUBLIC KEY-----
        MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMA
        cjHIrTDS6HEELgguOatmFBOp2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END PUBLIC KEY-----
        """

        let privateKeyBytes = try! "15f01cf0e979ce9bd3b19e2db9f07ad4f476f5b3a749d5dcc47ee293ca5c873b".bytes
        let privateKey = try! secp256k1.Signing.PrivateKey(dataRepresentation: privateKeyBytes, format: .uncompressed)
        let publicKey = try! secp256k1.Signing.PublicKey(pemRepresentation: publicKeyString)

        // Verify the keys matches the expected keys output
        XCTAssertEqual(privateKey.publicKey.dataRepresentation, publicKey.dataRepresentation)
    }

    func testSigningPEM() {
        let privateKeyString = """
        -----BEGIN EC PRIVATE KEY-----
        MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
        oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
        2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
        -----END EC PRIVATE KEY-----
        """

        let expectedDerSignature = "MEQCIC8k5whKPsPg7XtWTInvhGL4iEU6lP6yPdpEXXZ2mOhFAiAZ3Po9tEDV8mQ8LDzwF0nhPmAn9VLYG8bkuY6PKruZNQ=="
        let privateKey = try! secp256k1.Signing.PrivateKey(pemRepresentation: privateKeyString)
        let messageData = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!

        let signature = try! privateKey.signature(for: messageData)

        // Verify the signature matches the expected output
        XCTAssertEqual(expectedDerSignature, try! signature.derRepresentation.base64EncodedString())
    }

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
        let signature = try! secp256k1.Signing.ECDSASignature(derRepresentation: expectedDerSignature)
        let publicKey = try! secp256k1.Signing.PublicKey(pemRepresentation: publicKeyString)

        XCTAssertTrue(publicKey.isValidSignature(signature, for: SHA256.hash(data: messageData)))
    }

    @available(macOS 13.3, *)
    func testUInt256() {
        let expectedPrivateKey: UInt256 = 0x7DA1_2CC3_9BB4_189A_C72D_34FC_2225_DF5C_F36A_AACD_CAC7_E5A4_3963_299B_C8D8_88ED
        let expectedPrivateKey2: UInt256 = 0x1BB5_FC86_3773_7549_414D_7F1B_82A5_C12D_234B_56DB_AC17_5E14_0F63_046A_EBA8_DF87
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let combinedPrivateKey = expectedPrivateKey + expectedPrivateKey2

        let privateKey = try! secp256k1.Signing.PrivateKey(expectedPrivateKey)
        let privateKey2 = try! secp256k1.Signing.PrivateKey(expectedPrivateKey2)
        let privateKey3 = try! secp256k1.Signing.PrivateKey(combinedPrivateKey)

        print("privateKey \(String(bytes: privateKey.rawRepresentation))")
        print("privateKey2 \(String(bytes: privateKey2.rawRepresentation))")
        print("combinedPrivateKey UInt256 \(combinedPrivateKey)")
        print("combinedPrivateKey P256K1 \(String(bytes: privateKey3.rawRepresentation))")

        print("publicKey \(String(bytes: privateKey.publicKey.rawRepresentation))")
        print("publicKey2 \(String(bytes: privateKey2.publicKey.rawRepresentation))")

        let combinedPublicKey = try! secp256k1.Signing.PublicKey.combine(privateKey.publicKey, privateKey2.publicKey)

        print("combinedPublicKey UInt256 \(String(bytes: privateKey3.publicKey.rawRepresentation))")
        print("combinedPublicKey P256K1 \(String(bytes: combinedPublicKey.rawRepresentation))")

        // Verify the keys matches the expected keys output
        XCTAssertEqual(expectedPrivateKey, UInt256(rawValue: privateKey.rawRepresentation))
        XCTAssertEqual(expectedPublicKey, String(bytes: privateKey.publicKey.rawRepresentation))
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
        ("testShaHashDigest", testShaHashDigest),
        ("testRecoverySigning", testRecoverySigning),
        ("testPublicKeyRecovery", testPublicKeyRecovery),
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
        ("testKeyAgreementHashFunction", testKeyAgreementHashFunction),
        ("testKeyAgreementPublicKeyTweakAdd", testKeyAgreementPublicKeyTweakAdd),
        ("testXonlyToPublicKey", testXonlyToPublicKey),
        ("testTapscript", testTapscript),
        ("testCompactSizePrefix", testCompactSizePrefix),
        ("testSchnorrNegating", testSchnorrNegating),
        ("testTaprootDerivation", testTaprootDerivation),
        ("testPubkeyCombine", testPubkeyCombine),
        ("testPubkeyCombineBindings", testPubkeyCombineBindings),
        ("testPrivateKeyPEM", testPrivateKeyPEM),
        ("testPublicKeyPEM", testPublicKeyPEM),
        ("testSigningPEM", testSigningPEM),
        ("testVerifyingPEM", testVerifyingPEM)
    ]
}
