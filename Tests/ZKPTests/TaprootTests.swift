//
//  TaprootTests.swift
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

struct TaprootTestSuite {
    @Test("Test Taproot Derivation")
    func testTaprootDerivation() {
        let privateKeyBytes = try! "41F41D69260DF4CF277826A9B65A3717E4EEDDBEEDF637F212CA096576479361".bytes
        let privateKey = try! P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let internalKeyBytes = try! "cc8a4bc64d897bddc5fbc2f670f7a8ba0b386779106cf1223c6fc5d7cd6fc115".bytes
        let internalKey = privateKey.xonly

        #expect(internalKey.bytes == internalKeyBytes, "Internal key bytes should match expected")

        let tweakHash = try! SHA256.taggedHash(
            tag: "TapTweak".data(using: .utf8)!,
            data: Data(internalKey.bytes)
        )

        let outputKeyBytes = try! "a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c".bytes
        let outputKey = try! internalKey.add(tweakHash.bytes)

        #expect(outputKey.bytes == outputKeyBytes, "Output key bytes should match expected")
    }

    @Test("Test Tapscript execution and hash verification")
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
        let alice = try! P256K.Signing.PrivateKey(dataRepresentation: aliceBytes)
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

        #expect(String(bytes: Array(aliceLeafHash).bytes) == aliceExpectedLeafHash, "Alice's leaf hash mismatch")

        let bobBytes = try! "81b637d8fcd2c6da6359e6963113a1170de795e4b725b84d1e0b4cfd9ec58ce9".bytes
        let bob = try! P256K.Signing.PrivateKey(dataRepresentation: bobBytes)
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

        #expect(String(bytes: Array(bobLeafHash).bytes) == bobExpectedLeafHash, "Bob's leaf hash mismatch")

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

        #expect(String(bytes: Array(merkleRoot).bytes) == expectedMerkleRoot, "Merkle root mismatch")
    }
}
