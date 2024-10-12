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
        let aggregate = try secp256k1.MuSig.aggregate(publicKeys)

        // Create a message to sign
        let message = "Hello, MuSig!".data(using: .utf8)!
        let messageHash = SHA256.hash(data: message)

        // Generate nonces for each signer
        let schnorrNonces = try zip(privateKeys, publicKeys).map { privateKey, publicKey in
            try secp256k1.Schnorr.Nonce(
                sessionID: Data(repeating: 0, count: 32), // You may want to use a proper session ID
                secretKey: privateKey,
                publicKey: publicKey.xonly.bytes,
                msg32: Array(messageHash)
            )
        }

        // Extract public nonces
        let publicNonces = schnorrNonces.map(\.pubnonce)

        // Aggregate public nonces
        let aggregateNonce = try secp256k1.MuSig.Nonce(aggregating: publicNonces)

        // Create partial signatures
        let partialSignatures = try zip(privateKeys, schnorrNonces).map { privateKey, nonce in
            try privateKey.schnorrSign(
                message: Array(messageHash),
                nonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        // Aggregate partial signatures
        let signature = try secp256k1.MuSig.aggregatePartialSignatures(partialSignatures)

        // Verify the signature
        XCTAssertTrue(aggregate.xonly.isValidSignature(signature, for: message))

        // Test tweaking
        let tweakedKey = try aggregate.xonly.add([UInt8](repeating: 1, count: 32))
        XCTAssertFalse(tweakedKey.isValidSignature(signature, for: message))
    }

    static var allTests = [
        ("testMusig", testMusig)
    ]
}
