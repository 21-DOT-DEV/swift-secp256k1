//
//  TweakTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
@testable import P256K
import Testing

struct TweakTestSuite {
    @Test("Verify private key tweak addition produces expected result")
    func privateKeyTweakAdd() throws {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let expectedTweakedPrivateKey = "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let tweak = try SHA256.hash(data: #require(expectedPrivateKey.data(using: .utf8)))

        // Tweak the private key
        let tweakedPrivateKey = try privateKey.add(Array(tweak))

        // Verify the tweaked private key matches expected value
        #expect(String(bytes: tweakedPrivateKey.dataRepresentation) == expectedTweakedPrivateKey)
        // Verify original public key remains correct
        #expect(expectedPublicKey == String(bytes: privateKey.publicKey.dataRepresentation))
        // The tweak mutates a copy — the original key's bytes are unchanged
        #expect(privateKey.dataRepresentation == Data(privateKeyBytes))
    }

    @Test("Verify private key tweak addition produces expected result")
    func schnorrPrivateKeyTweakAdd() throws {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let expectedPublicKey = "023521df7b94248ffdf0d37f738a4792cc3932b6b1b89ef71cddde8251383b26e7"
        let expectedTweakedPrivateKey = "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let tweak = try SHA256.hash(data: #require(expectedPrivateKey.data(using: .utf8)))

        // Tweak the private key
        let tweakedPrivateKey = try privateKey.add(Array(tweak))

        // Verify the tweaked private key matches expected value
        #expect(String(bytes: tweakedPrivateKey.dataRepresentation) == expectedTweakedPrivateKey)
        // Verify original public key remains correct
        #expect(expectedPublicKey == String(bytes: privateKey.publicKey.dataRepresentation))
        // The tweak mutates a copy — the original key's bytes are unchanged
        #expect(privateKey.dataRepresentation == Data(privateKeyBytes))
    }

    @Test("Verify tweak/negation never mutate the original private key")
    func privateKeyOperationsDoNotMutateOriginal() throws {
        let privateKeyBytes = try "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed".bytes
        let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let tweak = [UInt8](repeating: 1, count: P256K.ByteLength.dimension)

        _ = try privateKey.add(tweak)
        #expect(privateKey.dataRepresentation == Data(privateKeyBytes), "add() mutated the original key")
        _ = try privateKey.multiply(tweak)
        #expect(privateKey.dataRepresentation == Data(privateKeyBytes), "multiply() mutated the original key")
        _ = privateKey.negation
        #expect(privateKey.dataRepresentation == Data(privateKeyBytes), "negation mutated the original key")
    }

    @Test("Verify tweak APIs reject non-32-byte tweaks")
    func invalidTweakSizeThrows() throws {
        // Upstream tweak functions read a fixed 32 bytes — a shorter input is
        // an out-of-bounds read, not a validation failure.
        let privateKey = try P256K.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let schnorrPrivateKey = try P256K.Schnorr.PrivateKey()
        let xonlyKey = schnorrPrivateKey.xonly
        let shortTweak = [UInt8](repeating: 1, count: 16)

        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try privateKey.add(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try privateKey.multiply(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try publicKey.add(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try publicKey.multiply(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try schnorrPrivateKey.add(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try xonlyKey.add(shortTweak)
        }
    }
}
