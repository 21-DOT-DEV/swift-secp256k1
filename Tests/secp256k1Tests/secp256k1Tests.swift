import XCTest
@testable import secp256k1

final class secp256k1Tests: XCTestCase {
    /// Basic Keypair test
    func testKeypairCreation() {
        // Initialize context
        let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

        // Destory context after execution
        defer {
            secp256k1_context_destroy(context)
        }

        // Setup private and public key variables
        var pubkeyLen = 65
        var cPubkey = secp256k1_pubkey()
        var pubkey = [UInt8](repeating: 0, count: pubkeyLen)
        let privkey: [UInt8] = [0,1,0,0,1,0,1,0,1,0,1,0,1,0,0,1,1,1,0,0,1,0,0,1,1,0,0,1,0,0,32,0]

        // Verify the context and keys are setup correctly
        XCTAssertEqual(secp256k1_context_randomize(context, privkey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_create(context, &cPubkey, privkey), 1)
        XCTAssertEqual(secp256k1_ec_pubkey_serialize(context, &pubkey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)), 1)

        // Define the expected public key
        let expectedPublicKey: [UInt8] = [
            4,96,104, 212, 128, 165, 213,
            207, 134, 132, 22, 247, 38,
            114, 82, 108, 77, 43, 6, 56,
            80, 113, 12, 11, 119, 7, 240,
            188, 73, 170, 44, 202, 33, 225,
            30, 248, 53, 138, 34, 22, 100,
            96, 31, 76, 64, 125, 71, 127,
            62, 155, 108, 243, 17, 222, 97,
            234, 75, 247, 187, 83, 151, 206,
            27, 38, 228
        ]

        // Verify the generated public key matches the expected public key
        XCTAssertEqual(expectedPublicKey, pubkey)
    }

    static var allTests = [
        ("testKeypairCreation", testKeypairCreation),
    ]
}
