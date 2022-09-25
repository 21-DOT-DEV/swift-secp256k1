import XCTest

final class secp256k1Tests: XCTestCase, APITestingType {
    func testUncompressedKeypairCreation() { uncompressedKeypairCreation() }
    func testCompressedKeypairCreation() { compressedKeypairCreation() }
    func testECDHBindings() { ecdhBindings() }
    func testExtraKeysBindings() { extraKeysBindings() }
    func testRecoveryBindings() { recoveryBindings() }
    func testSchnorrBindings() { schnorrBindings() }
    func testCompressedKeypairImplementationWithRaw() { compressedKeypairImplementationWithRaw() }
    func testSha256() { sha256() }
    func testSha32BytesDigest() { sha32BytesDigest() }
    func testSigning() { signing() }
    func testRecoverySigning() { recoverySigning() }
    func testPublicKeyRecovery() { publicKeyRecovery() }
    func testSchnorrSigning() { schnorrSigning() }
    func testVerifying() { verifying() }
    func testSchnorrVerifyingPre() { schnorrVerifyingPre() }
    func testSchnorrVerifying() { schnorrVerifying() }
    func testVerifyingDER() { verifyingDER() }
    func testPrivateKey() { privateKey() }
    func testCompressedPublicKey() { compressedPublicKey() }
    func testUncompressedPublicKey() { uncompressedPublicKey() }
    func testUncompressedPublicKeyWithKey() { uncompressedPublicKeyWithKey() }
    func testInvalidRawSignature() { invalidRawSignature() }
    func testInvalidDerSignature() { invalidDerSignature() }
    func testInvalidPrivateKeyBytes() { invalidPrivateKeyBytes() }
    func testInvalidPrivateKeyLength() { invalidPrivateKeyLength() }
    func testKeypairSafeCompare() { keypairSafeCompare() }
    func testZeroization() { zeroization() }
    func testPrivateKeyTweakAdd() { privateKeyTweakAdd() }
    func testKeyAgreement() { keyAgreement() }
    func testKeyAgreementPublicKeyTweakAdd() { keyAgreementPublicKeyTweakAdd() }
    func testXonlyToPublicKey() { xonlyToPublicKey() }

    static var allTests = [
        ("testUncompressedKeypairCreation", testUncompressedKeypairCreation),
        ("testCompressedKeypairCreation", testCompressedKeypairCreation),
        ("testECDHBindings", testECDHBindings),
        ("testExtraKeysBindings", testExtraKeysBindings),
        ("testRecoveryBindings", testRecoveryBindings),
        ("testSchnorrBindings", testSchnorrBindings),
        ("testCompressedKeypairImplementationWithRaw", testCompressedKeypairImplementationWithRaw),
        ("testSha256", testSha256),
        ("testSha32BytesDigest", testSha32BytesDigest),
        ("testSigning", testSigning),
        ("testRecoverySigning", testRecoverySigning),
        ("testPublicKeyRecovery", testPublicKeyRecovery),
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
        ("testKeyAgreementPublicKeyTweakAdd", testKeyAgreementPublicKeyTweakAdd),
        ("testXonlyToPublicKey", testXonlyToPublicKey)
    ]
}
