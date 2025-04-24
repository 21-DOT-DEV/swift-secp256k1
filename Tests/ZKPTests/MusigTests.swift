//
//  MusigTests.swift
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

import Foundation
import Testing

struct MuSigTestSuite {
    @Test("MuSig Signing and Verification")
    func testMusig() {
        // Test MuSig aggregate
        let privateKeys = [
            try! P256K.Schnorr.PrivateKey(),
            try! P256K.Schnorr.PrivateKey(),
            try! P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try! P256K.MuSig.aggregate(publicKeys)

        // Create a message to sign
        let message = "Hello, MuSig!".data(using: .utf8)!
        let messageHash = SHA256.hash(data: message)

        // Generate nonces for each signer
        let firstNonce = try! P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: Array(messageHash)
        )

        let secondNonce = try! P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: Array(messageHash)
        )

        let thirdNonce = try! P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[2],
            publicKey: privateKeys[2].publicKey,
            msg32: Array(messageHash)
        )

        // Extract public nonces
        let publicNonces = [firstNonce.pubnonce, secondNonce.pubnonce, thirdNonce.pubnonce]

        // Aggregate public nonces
        let aggregateNonce = try! P256K.MuSig.Nonce(aggregating: publicNonces)

        // Create partial signatures
        let firstPartialSignature = try! privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let secondPartialSignature = try! privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        let thirdPartialSignature = try! privateKeys[2].partialSignature(
            for: messageHash,
            pubnonce: thirdNonce.pubnonce,
            secureNonce: thirdNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // Uncomment to see expected error
//        let forthPartialSignature = try privateKeys[1].partialSignature(
//            for: messageHash,
//            pubnonce: thirdNonce.pubnonce,
//            secureNonce: thirdNonce.secnonce,
//            publicNonceAggregate: aggregateNonce,
//            publicKeyAggregate: aggregate
//        )

        // Aggregate partial signatures
        _ = try! P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature, thirdPartialSignature])

        // Verify the signature
        #expect(aggregate.isValidSignature(firstPartialSignature, publicKey: publicKeys.first!, nonce: publicNonces.first!, for: messageHash), "MuSig signature verification failed.")
    }
}
