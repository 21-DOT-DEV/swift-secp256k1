//
//  SchnorrTests.swift
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
import XCTest

struct SchnorrTestSuite {
    @Test("Schnorr Signing Test")
    func schnorrSigningTest() throws {
        // Official BIP-340 test vector, index 0: secret key 3, zero message,
        // all-zero auxiliary randomness — the deterministic-nonce case.
        let expectedDerSignature = "6QeDH4CEjRBppTcbQCQQNkvfHF+DB7AITFXxzi3KghUl9mpKheqLceSCp084LSzl6+7o/bIXL0d99JANMQU2wA=="
        let expectedSignature = "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0"
        let expectedPublicKey = "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
        let expectedPublicKeyBytes = try expectedPublicKey.bytes
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageDigest = try "0000000000000000000000000000000000000000000000000000000000000000".bytes
        let auxRand = try "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try privateKey.signature(message: messageDigest, auxiliaryRand: auxRand)

        // The vector row's public-key column pins secret-key → x-only
        // derivation alongside the signature bytes (the same full-row check
        // rust-secp256k1's BIP-340 driver performs).
        #expect(expectedPublicKeyBytes == privateKey.xonly.bytes)

        // Verify the signature matches the expected output
        #expect(expectedSignature == String(bytes: Array(signature.dataRepresentation)))
        #expect(expectedDerSignature == signature.dataRepresentation.base64EncodedString())
    }

    @Test("Schnorr Verifying Pre-Test")
    func schnorrVerifyingPreTest() throws {
        let expectedPrivateKey = "4894b8087f428971b55ff96e16f7127340138bc84e7973821a224cad02055975"
        let expectedSignature = "ad57c21d383ef8ac799adfd469a221c40ef9f09563a16682b9ab1edc46c33d6d6a1d719761d269e87ab971e0ffafc1618a4666a4f9aef4abddc3ea9fc0cd5b12"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageDigest: [UInt8] = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!.byteArray
        let auxRand = try "f50c8c99e39a82f125fa83186b5f2483f39fb0fb56269c755689313a177be6ea".bytes

        let signature = try privateKey.signature(customMessage: messageDigest, auxiliaryRand: auxRand)

        // Verify the signature matches the expected signature
        #expect(String(bytes: signature.dataRepresentation.byteArray) == expectedSignature)

        // Verify the signature is valid
        #expect(privateKey.xonly.isValid(signature, for: messageDigest))
    }

    @Test("Schnorr fresh-auxiliary signing verifies")
    func schnorrFreshAuxRandSigns() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let message = try "0000000000000000000000000000000000000000000000000000000000000000".bytes
        let custom = "We're all Satoshi Nakamoto and a bit of Harold Thomas Finney II.".data(using: .utf8)!.byteArray

        // Fresh-aux paths draw nonce randomness internally, so the signatures
        // are nondeterministic — the check is round-trip verification, and
        // two successive signatures over the same input differing confirms
        // the fresh randomness actually varies the nonce.
        let signature = try privateKey.signature(message: message)
        #expect(privateKey.xonly.isValid(signature, for: message))

        let customSignature = try privateKey.signature(customMessage: custom)
        #expect(privateKey.xonly.isValid(customSignature, for: custom))

        let second = try privateKey.signature(message: message)
        #expect(signature.dataRepresentation != second.dataRepresentation)

        // The same borrow on the signing side — a rebased slice signs only its window.
        let sliceSignature = try privateKey.signature(customMessage: ([0xFF] + custom)[1...])
        #expect(privateKey.xonly.isValid(sliceSignature, for: custom))
    }

    @Test("Schnorr Verifying Test")
    func schnorrVerifyingTest() throws {
        let expectedPrivateKey = "0000000000000000000000000000000000000000000000000000000000000003"
        let privateKeyBytes = try expectedPrivateKey.bytes
        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)
        let messageDigest = try "0000000000000000000000000000000000000000000000000000000000000000".bytes
        let auxRand = try "0000000000000000000000000000000000000000000000000000000000000000".bytes

        let signature = try privateKey.signature(message: messageDigest, auxiliaryRand: auxRand)

        // Test the verification of the signature output
        #expect(privateKey.xonly.isValid(signature, for: messageDigest))

        // The retyped verifier borrows any `ContiguousBytes` — a `Data` value and
        // a rebased `ArraySlice` (non-zero start index) must verify the same bytes.
        #expect(privateKey.xonly.isValid(signature, for: Data(messageDigest)))
        #expect(privateKey.xonly.isValid(signature, for: ([0xFF] + messageDigest)[1...]))
    }

    @Test("Schnorr signing rejects a non-32-byte auxiliaryRand")
    func shortAuxRandThrows() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let digest = SHA256.hash(data: "We're all Satoshi.".data(using: .utf8)!)
        let message = try "0000000000000000000000000000000000000000000000000000000000000000".bytes
        let shortAux = [UInt8](repeating: 1, count: 16)

        // `auxiliaryRand` feeds upstream's `ndata` pointer, which reads a fixed
        // 32 bytes — a shorter input is an out-of-bounds read, not a signing failure.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try privateKey.signature(for: digest, auxiliaryRand: shortAux)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try privateKey.signature(message: message, auxiliaryRand: shortAux)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try privateKey.signature(customMessage: message, auxiliaryRand: shortAux)
        }
    }

    @Test("Schnorr 32-byte methods reject off-size messages")
    func schnorrMessageLengthGate() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let validAuxRand = [UInt8](repeating: 0x5A, count: 32)

        // Both fixed-size methods gate on `message.count == 32` — shorter
        // inputs must throw exactly as longer ones do. A 100-byte message is
        // a legitimate BIP-340 signing input (vector row 18): the fixed-size
        // methods must still refuse it.
        for length in [0, 1, 31, 33, 64, 100] {
            let message = [UInt8](repeating: 0xAB, count: length)
            #expect(throws: secp256k1Error.incorrectParameterSize) {
                _ = try privateKey.signature(message: message)
            }
            #expect(throws: secp256k1Error.incorrectParameterSize) {
                _ = try privateKey.signature(message: message, auxiliaryRand: validAuxRand)
            }
        }

        // The deliberately-named escape hatch stays open: the same 100 bytes
        // sign through `customMessage:` and verify at natural length —
        // arbitrary-length messages are spec-legal, just never implicit.
        let hundredBytes = [UInt8](repeating: 0xAB, count: 100)
        let signature = try privateKey.signature(customMessage: hundredBytes)
        #expect(privateKey.xonly.isValid(signature, for: hundredBytes))

        // A signature over one custom message must not verify against a
        // different message — the negative control proving the round-trip
        // above actually checks the bytes.
        #expect(!privateKey.xonly.isValid(signature, for: [UInt8](repeating: 0xCD, count: 100)))
    }

    @Test("Schnorr digest and empty-message signing verify")
    func schnorrDigestAndEmptySign() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let digest = SHA256.hash(data: "We're all Satoshi.".data(using: .utf8)!)
        let auxRand = try "0000000000000000000000000000000000000000000000000000000000000000".bytes

        // The Digest overloads sign the digest's natural bytes as the message —
        // verify with the matching digest verifier.
        let freshSignature = try privateKey.signature(for: digest)
        #expect(privateKey.xonly.isValidSignature(freshSignature, for: digest))

        let auxSignature = try privateKey.signature(for: digest, auxiliaryRand: auxRand)
        #expect(privateKey.xonly.isValidSignature(auxSignature, for: digest))

        // An empty message is legal upstream — it reaches C with
        // `msglen = 0` (`msg` may be NULL) and must round-trip through verify.
        let emptyMessage: [UInt8] = []
        let emptySignature = try privateKey.signature(customMessage: emptyMessage)
        #expect(privateKey.xonly.isValid(emptySignature, for: emptyMessage))
    }

    @Test("x-only key rejects malformed coordinates at construction")
    func xonlyKeyRejectsMalformed() throws {
        // `secp256k1_xonly_pubkey_parse` reads a fixed 32 bytes and requires the
        // coordinate to lift to a curve point — malformed input is rejected at
        // construction so no downstream path can observe an invalid key.
        #expect(throws: secp256k1Error.incorrectKeySize) {
            _ = try P256K.Schnorr.XonlyKey(dataRepresentation: [UInt8](repeating: 2, count: 16))
        }

        // 0xFF×32 ≥ the field order p — the x coordinate never lifts to a curve point.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Schnorr.XonlyKey(dataRepresentation: [UInt8](repeating: 0xFF, count: 32))
        }
    }

    @Test("Test Schnorr Negating")
    func schnorrNegating() throws {
        let privateBytes = try "56baa476b36a5b1548279f5bf57b82db39e594aee7912cde30977b8e80e6edca".bytes
        let negatedBytes = try "a9455b894c95a4eab7d860a40a847d2380c94837c7b7735d8f3ae2fe4f4f5377".bytes

        let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateBytes)
        let negatedKey = try P256K.Schnorr.PrivateKey(dataRepresentation: negatedBytes).negation

        #expect(privateKey == negatedKey, "Private key should equal negated key")
        #expect(privateKey.dataRepresentation == negatedKey.dataRepresentation, "Data representation of private key should equal negated key")
        #expect(privateKey.xonly == negatedKey.xonly, "Xonly of private key should equal negated key")
        #expect(privateKey.xonly.bytes == negatedKey.xonly.bytes, "Xonly bytes of private key should equal negated key")
    }
}
