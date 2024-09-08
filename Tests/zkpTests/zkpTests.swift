import XCTest
@testable import zkp

final class zkpTests: XCTestCase {
    func testMusig() throws {
        // Test MuSig aggregate
        let privateKeys = [
            try secp256k1.Schnorr.PrivateKey(),
            try secp256k1.Schnorr.PrivateKey(),
            try secp256k1.Schnorr.PrivateKey()
        ]
        
        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try! secp256k1.Schnorr.aggregate(publicKeys)
        
        let signature = try aggregate.xonly.
        let aggregateSignature = try aggregate.sign(message: "Hello World", signature: signature)
        
        XCTAssert
    }

    static var allTests = [
        ("testMusig", testMusig)
    ]
}
