import XCTest
@testable import secp256k1
import secp256k1_utils

final class secp256k1Tests: XCTestCase {
    /// Uncompressed Keypair test
    func testUncompressedKeypairCreation() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destory context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubkeyLen = 65
        var cPubkey = secp256k1_pubkey()
        var publicKey = [UInt8](repeating: 0, count: pubkeyLen)
        
        let privateKey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".byteArray()
        
        // Verify the context and keys are setup correctly
        XCTAssertEqual(secp256k1_context_randomize(context, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &cPubkey, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_serialize(context, &publicKey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)), 1)

        let hexString = """
        04734B3511150A60FC8CAC329CD5FF804555728740F2F2E98BC4242135EF5D5E4E6C4918116B0866F50C46614F3015D8667FBFB058471D662A642B8EA2C9C78E8A
        """
        
        // Define the expected public key
        let expectedPublicKey = try! hexString.byteArray()
        
        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, publicKey)
        XCTAssertEqual(hexString.lowercased(), String(byteArray: publicKey))
    }
    
    /// Compressed Keypair test
    func testCompressedKeypairCreation() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destory context after execution
        defer { secp256k1_context_destroy(context) }

        // Setup private and public key variables
        var pubkeyLen = 33
        var cPubkey = secp256k1_pubkey()
        var publicKey = [UInt8](repeating: 0, count: pubkeyLen)
        
        let privateKey = try! "B035FCFC6ABF660856C5F3A6F9AC51FCA897BB4E76AD9ACA3EFD40DA6B9C864B".byteArray()
        
        // Verify the context and keys are setup correctly
        XCTAssertEqual(secp256k1_context_randomize(context, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &cPubkey, privateKey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_serialize(context, &publicKey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_COMPRESSED)), 1)

        // Define the expected public key
        let expectedPublicKey = try! "02EA724B70B48B61FB87E4310871A48C65BF38BF3FDFEFE73C2B90F8F32F9C1794".byteArray()

        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, publicKey)
    }

    static var allTests = [
        ("testUncompressedKeypairCreation", testUncompressedKeypairCreation),
        ("testCompressedKeypairCreation", testCompressedKeypairCreation),
    ]
}
