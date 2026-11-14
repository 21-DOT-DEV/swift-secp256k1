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

    /// The contract class the MuSig advisory (GHSA-7g3x-fj89-693j) violated
    /// on its side: every public-key operation taking `format:` must treat it
    /// as output-only — the caller's chosen output format can never reach
    /// the input side. `uncompressedRepresentation` re-serializes the point
    /// uncompressed regardless of stored format, so it is the same-point
    /// oracle across formats.
    @Test("Public key operations honor both output formats")
    func publicKeyOperationsHonorBothFormats() throws {
        let privateKey = try P256K.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let other = try P256K.Signing.PrivateKey().publicKey
        let tweak = [UInt8](repeating: 1, count: P256K.ByteLength.dimension)

        let compressedAdd = try publicKey.add(tweak)
        let uncompressedAdd = try publicKey.add(tweak, format: .uncompressed)
        #expect(uncompressedAdd.format == .uncompressed)
        #expect(uncompressedAdd.dataRepresentation.count == P256K.Format.uncompressed.length)
        #expect(uncompressedAdd.uncompressedRepresentation == compressedAdd.uncompressedRepresentation)

        let compressedMultiply = try publicKey.multiply(tweak)
        let uncompressedMultiply = try publicKey.multiply(tweak, format: .uncompressed)
        #expect(uncompressedMultiply.format == .uncompressed)
        #expect(uncompressedMultiply.uncompressedRepresentation == compressedMultiply.uncompressedRepresentation)

        let compressedCombine = try publicKey.combine([other])
        let uncompressedCombine = try publicKey.combine([other], format: .uncompressed)
        #expect(uncompressedCombine.format == .uncompressed)
        #expect(uncompressedCombine.uncompressedRepresentation == compressedCombine.uncompressedRepresentation)

        // Reverse direction: an uncompressed-stored input must produce the
        // same points under the default compressed output — the stored
        // format must not reach the input side either.
        let uncompressedStored = try P256K.Signing.PublicKey(
            dataRepresentation: publicKey.uncompressedRepresentation,
            format: .uncompressed
        )
        let addFromUncompressed = try uncompressedStored.add(tweak)
        let multiplyFromUncompressed = try uncompressedStored.multiply(tweak)
        let combineFromUncompressed = try uncompressedStored.combine([other])
        #expect(addFromUncompressed.format == .compressed)
        #expect(addFromUncompressed.uncompressedRepresentation == uncompressedAdd.uncompressedRepresentation)
        #expect(multiplyFromUncompressed.uncompressedRepresentation == uncompressedMultiply.uncompressedRepresentation)
        #expect(combineFromUncompressed.uncompressedRepresentation == uncompressedCombine.uncompressedRepresentation)
    }

    /// Spec 005 (T004) — every public-key type's `uncompressedRepresentation` must
    /// encode the *same point* its stored-format `dataRepresentation` stores: a
    /// `0x04` tag, the identical X coordinate in bytes 1–32, and byte 64's low bit
    /// equal to the compressed tag's `0x02`/`0x03` parity (the `serialize33`/
    /// `serialize65` contract in vendored `eckey_impl.h:38-55`). Each type is
    /// checked on a compressed-stored key and on an uncompressed-stored key;
    /// the byte-correspondence oracle is uniform because `Recovery.PublicKey`
    /// exposes no `xonly`/`parity` accessor to compare against instead.
    @Test("uncompressedRepresentation encodes the same point on every public-key type")
    func uncompressedRepresentationEncodesSamePoint() throws {
        // Signing — companion key stores compressed; re-ingest 65 bytes for
        // the uncompressed-stored case.
        let signingCompressed = try P256K.Signing.PrivateKey().publicKey
        expectSEC1SamePoint(
            compressed: signingCompressed.dataRepresentation,
            uncompressed: signingCompressed.uncompressedRepresentation,
            "Signing.PublicKey compressed-stored"
        )
        let signingUncompressed = try P256K.Signing.PublicKey(
            dataRepresentation: signingCompressed.uncompressedRepresentation,
            format: .uncompressed
        )
        #expect(
            signingUncompressed.uncompressedRepresentation == signingUncompressed.dataRepresentation,
            "Signing.PublicKey uncompressed-stored: accessor must equal stored bytes"
        )
        #expect(
            signingUncompressed.uncompressedRepresentation == signingCompressed.uncompressedRepresentation,
            "Signing.PublicKey: same point across stored formats"
        )

        // Schnorr — the companion key stores *uncompressed* internally
        // (`secp256k1_keypair_create` requires it), so it doubles as this leg's
        // uncompressed-stored case. A compressed-stored Schnorr key of the same
        // point comes from the same scalar re-derived through the Signing
        // wrapper's 33-byte form.
        let schnorrPrivateKey = try P256K.Schnorr.PrivateKey()
        let schnorrUncompressedStored = schnorrPrivateKey.publicKey
        let sameScalarSigningPrivateKey = try P256K.Signing.PrivateKey(
            dataRepresentation: schnorrPrivateKey.dataRepresentation
        )
        let schnorrCompressed = try P256K.Schnorr.PublicKey(
            dataRepresentation: sameScalarSigningPrivateKey.publicKey.dataRepresentation,
            format: .compressed
        )
        expectSEC1SamePoint(
            compressed: schnorrCompressed.dataRepresentation,
            uncompressed: schnorrCompressed.uncompressedRepresentation,
            "Schnorr.PublicKey compressed-stored"
        )
        #expect(
            schnorrUncompressedStored.uncompressedRepresentation == schnorrUncompressedStored.dataRepresentation,
            "Schnorr.PublicKey uncompressed-stored: accessor must equal stored bytes"
        )
        #expect(
            schnorrUncompressedStored.uncompressedRepresentation == schnorrCompressed.uncompressedRepresentation,
            "Schnorr.PublicKey: same point across stored formats"
        )

        // KeyAgreement — companion key stores compressed.
        let keyAgreementCompressed = try P256K.KeyAgreement.PrivateKey().publicKey
        expectSEC1SamePoint(
            compressed: keyAgreementCompressed.dataRepresentation,
            uncompressed: keyAgreementCompressed.uncompressedRepresentation,
            "KeyAgreement.PublicKey compressed-stored"
        )
        let keyAgreementUncompressed = try P256K.KeyAgreement.PublicKey(
            dataRepresentation: keyAgreementCompressed.uncompressedRepresentation,
            format: .uncompressed
        )
        #expect(
            keyAgreementUncompressed.uncompressedRepresentation == keyAgreementUncompressed.dataRepresentation,
            "KeyAgreement.PublicKey uncompressed-stored: accessor must equal stored bytes"
        )
        #expect(
            keyAgreementUncompressed.uncompressedRepresentation == keyAgreementCompressed.uncompressedRepresentation,
            "KeyAgreement.PublicKey: same point across stored formats"
        )

        // MuSig — the aggregate always stores compressed; a key rebuilt from
        // 65 bytes is verification-only but serializes the same point.
        let muSigSigner = try P256K.Schnorr.PrivateKey().publicKey
        let muSigPeer = try P256K.Schnorr.PrivateKey().publicKey
        let muSigCompressed = try P256K.MuSig.aggregate([muSigSigner, muSigPeer])
        expectSEC1SamePoint(
            compressed: muSigCompressed.dataRepresentation,
            uncompressed: muSigCompressed.uncompressedRepresentation,
            "MuSig.PublicKey compressed-stored"
        )
        let muSigUncompressed = try P256K.MuSig.PublicKey(
            dataRepresentation: muSigCompressed.uncompressedRepresentation,
            format: .uncompressed
        )
        #expect(
            muSigUncompressed.uncompressedRepresentation == muSigUncompressed.dataRepresentation,
            "MuSig.PublicKey uncompressed-stored: accessor must equal stored bytes"
        )
        #expect(
            muSigUncompressed.uncompressedRepresentation == muSigCompressed.uncompressedRepresentation,
            "MuSig.PublicKey: same point across stored formats"
        )

        // Recovery — derivation-only: the stored format comes from the
        // recovery initializer, so both forms are built from one signature.
        let recoveryPrivateKey = try P256K.Recovery.PrivateKey()
        let message = Data("same-point".utf8)
        let recoverable = recoveryPrivateKey.signature(for: message)
        let recoveryCompressed = try P256K.Recovery.PublicKey(message, signature: recoverable)
        expectSEC1SamePoint(
            compressed: recoveryCompressed.dataRepresentation,
            uncompressed: recoveryCompressed.uncompressedRepresentation,
            "Recovery.PublicKey compressed-stored"
        )
        // A recovered key is the signer's public key by construction — the
        // same point the companion `publicKey` derives, byte-for-byte.
        #expect(
            recoveryCompressed.dataRepresentation == recoveryPrivateKey.publicKey.dataRepresentation,
            "Recovery.PublicKey: recovered key must equal the signer's companion public key"
        )
        #expect(
            recoveryCompressed.uncompressedRepresentation == recoveryPrivateKey.publicKey.uncompressedRepresentation,
            "Recovery.PublicKey: recovered key must serialize to the same 65 bytes as the companion key"
        )
        let recoveryUncompressed = try P256K.Recovery.PublicKey(message, signature: recoverable, format: .uncompressed)
        #expect(
            recoveryUncompressed.uncompressedRepresentation == recoveryUncompressed.dataRepresentation,
            "Recovery.PublicKey uncompressed-stored: accessor must equal stored bytes"
        )
        #expect(
            recoveryUncompressed.uncompressedRepresentation == recoveryCompressed.uncompressedRepresentation,
            "Recovery.PublicKey: same point across stored formats"
        )
    }

    /// Asserts the SEC1 same-point correspondence between a key's compressed
    /// `dataRepresentation` (33 bytes, `0x02`/`0x03` tag) and its
    /// `uncompressedRepresentation` (65 bytes, `0x04` tag): same X coordinate
    /// in bytes 1–32, and the last byte's low bit equal to the compressed
    /// tag's parity bit. Guards on both lengths first so a wrong-size argument
    /// fails its expectation instead of trapping — or silently mis-oracling —
    /// on a later index. (A 65-byte `compressed` argument means the caller
    /// stored uncompressed; that is a test-construction bug, not a key defect.)
    private func expectSEC1SamePoint(
        compressed dataRepresentation: Data,
        uncompressed uncompressedRepresentation: Data,
        _ label: String
    ) {
        #expect(
            dataRepresentation.count == P256K.Format.compressed.length,
            "\(label): compressed argument must be the 33-byte stored form"
        )
        #expect(
            uncompressedRepresentation.count == P256K.Format.uncompressed.length,
            "\(label): must return 65 bytes"
        )
        guard dataRepresentation.count == P256K.Format.compressed.length,
              uncompressedRepresentation.count == P256K.Format.uncompressed.length else {
            return
        }
        #expect(uncompressedRepresentation[0] == 0x04, "\(label): tag must be 0x04")
        #expect(
            uncompressedRepresentation[1...32] == dataRepresentation[1...32],
            "\(label): bytes 1–32 must equal the compressed X coordinate"
        )
        #expect(
            uncompressedRepresentation[64] & 1 == dataRepresentation[0] & 1,
            "\(label): last byte's parity must equal the compressed tag's parity"
        )
    }
}
