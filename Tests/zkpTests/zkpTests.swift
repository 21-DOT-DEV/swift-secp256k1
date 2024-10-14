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
        let schnorrNonces = try privateKeys.map { privateKey in
            try secp256k1.Schnorr.Nonce(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: Array(messageHash)
            )
        }

        // Extract public nonces
        let publicNonces = schnorrNonces.map(\.pubnonce)

        // Aggregate public nonces
        let aggregateNonce = try secp256k1.MuSig.Nonce(aggregating: publicNonces)

        // Create partial signatures
        let partialSignatures = try zip(privateKeys, schnorrNonces).map { privateKey, nonce in
            try privateKey.partialSignature(
                for: messageHash,
                nonce: nonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        // Aggregate partial signatures
        let signature = try secp256k1.MuSig.aggregateSignatures(partialSignatures)

        // Verify the signature
        XCTAssertTrue(
            aggregate.isValidSignature(
                partialSignatures.first!,
                publicKey: publicKeys.first!,
                nonce: schnorrNonces.first!,
                for: messageHash
            )
        )
    }

    static var allTests = [
        ("testMusig", testMusig)
    ]
}
