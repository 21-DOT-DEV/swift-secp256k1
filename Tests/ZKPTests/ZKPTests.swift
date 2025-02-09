import XCTest
@testable import ZKP

final class ZKPTests: XCTestCase {
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
        let firstNonce = try secp256k1.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: Array(messageHash)
        )

        let secondNonce = try secp256k1.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: Array(messageHash)
        )

        let thirdNonce = try secp256k1.MuSig.Nonce.generate(
            secretKey: privateKeys[2],
            publicKey: privateKeys[2].publicKey,
            msg32: Array(messageHash)
        )

        // Extract public nonces
        let publicNonces = [firstNonce.pubnonce, secondNonce.pubnonce, thirdNonce.pubnonce]

        // Aggregate public nonces
        let aggregateNonce = try secp256k1.MuSig.Nonce(aggregating: publicNonces)

        // Create partial signatures
        let firstPartialSignature = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let secondPartialSignature = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let thirdPartialSignature = try privateKeys[2].partialSignature(
            for: messageHash,
            pubnonce: thirdNonce.pubnonce,
            secureNonce: thirdNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // Expected error when uncommented
//        let forthPartialSignature = try privateKeys[1].partialSignature(
//            for: messageHash,
//            pubnonce: thirdNonce.pubnonce,
//            secureNonce: thirdNonce.secnonce,
//            publicNonceAggregate: aggregateNonce,
//            publicKeyAggregate: aggregate
//        )

        // Aggregate partial signatures
        _ = try secp256k1.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature, thirdPartialSignature])

        // Verify the signature
        XCTAssertTrue(
            aggregate.isValidSignature(
                firstPartialSignature,
                publicKey: publicKeys.first!,
                nonce: publicNonces.first!,
                for: messageHash
            )
        )
    }

    static var allTests = [
        ("testMusig", testMusig)
    ]
}
