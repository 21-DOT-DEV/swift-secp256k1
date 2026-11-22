//
//  ECDHTests.swift
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

struct ECDHTestSuite {
    @Test("Test Key Agreement")
    func keyAgreement() throws {
        let privateString1 = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        let privateString2 = "5f6d5afecc677d66fb3d41eee7a8ad8195659ceff588edaf416a9a17daf38fdd"

        let privateBytes1 = try privateString1.bytes
        let privateBytes2 = try privateString2.bytes

        let privateKey1 = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateBytes1)
        let privateKey2 = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateBytes2)

        let sharedSecret1 = privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        let sharedSecret2 = privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey)

        #expect(sharedSecret1.byteArray == sharedSecret2.byteArray, "Shared secrets should be equal")
        #expect(
            sharedSecret1.uncompressedRepresentation == sharedSecret2.uncompressedRepresentation,
            "Uncompressed shared secrets should be equal"
        )
    }

    /// `SharedSecret.uncompressedRepresentation` returns the 65-byte SEC1
    /// encoding of the same shared point: `0x04` tag, bytes 1–32 equal to the
    /// stored compressed form's X coordinate, and byte 64's low bit matching
    /// the compressed tag's `0x02`/`0x03` parity — the `serialize33`/`serialize65`
    /// contract in vendored `eckey_impl.h`.
    @Test("SharedSecret uncompressedRepresentation encodes the same point")
    func sharedSecretUncompressedRepresentation() throws {
        let privateKey = try P256K.KeyAgreement.PrivateKey()
        let peerPrivateKey = try P256K.KeyAgreement.PrivateKey()

        let sharedSecret = privateKey.sharedSecretFromKeyAgreement(with: peerPrivateKey.publicKey)
        let compressed = sharedSecret.byteArray
        let uncompressed = sharedSecret.uncompressedRepresentation

        #expect(compressed.count == P256K.Format.compressed.length)
        #expect(uncompressed.count == P256K.Format.uncompressed.length)
        #expect(uncompressed.first == 0x04, "Uncompressed secret must carry the 0x04 tag")
        #expect(Data(uncompressed[1...32]) == Data(compressed[1...32]), "X coordinate must match the compressed form")
        #expect(
            uncompressed[64] & 0x01 == (compressed[0] == 0x03 ? 1 : 0),
            "Y parity must match the compressed tag"
        )
    }

    /// Known-answer ECDH: scalar 1 against peers with scalars 6 and 7 shares
    /// the points 6·G and 7·G, whose SEC1 encodings are published constants.
    /// The pair covers both compressed-tag parities (6·G has odd Y → `0x03`,
    /// 7·G has even Y → `0x02`), so a parity slip in the tag byte is caught
    /// deterministically — self-consistency checks between two derived
    /// secrets can't see corruption that hits both paths identically.
    @Test("Key agreement stores the known shared point bytes")
    func keyAgreementKnownAnswer() throws {
        let scalar1 = try "0000000000000000000000000000000000000000000000000000000000000001".bytes
        let scalar6 = try "0000000000000000000000000000000000000000000000000000000000000006".bytes
        let scalar7 = try "0000000000000000000000000000000000000000000000000000000000000007".bytes
        let privateKey = try P256K.KeyAgreement.PrivateKey(dataRepresentation: scalar1)
        let peerPrivateKey6 = try P256K.KeyAgreement.PrivateKey(dataRepresentation: scalar6)
        let peerPrivateKey7 = try P256K.KeyAgreement.PrivateKey(dataRepresentation: scalar7)

        let sharedSecret6 = privateKey.sharedSecretFromKeyAgreement(with: peerPrivateKey6.publicKey)
        let sharedSecret7 = privateKey.sharedSecretFromKeyAgreement(with: peerPrivateKey7.publicKey)
        let peerSharedSecret7 = peerPrivateKey7.sharedSecretFromKeyAgreement(with: privateKey.publicKey)

        // 1 × (6·G) = 6·G (odd Y); 1 × (7·G) = 7·G (even Y)
        let expectedCompressed6 = try "03fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556".bytes
        let expectedUncompressed6 = try "04fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556ae12777aacfbb620f3be96017f45c560de80f0f6518fe4a03c870c36b075f297".bytes
        let expectedCompressed7 = try "025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc".bytes
        let expectedUncompressed7 = try "045cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc6aebca40ba255960a3178d6d861a54dba813d0b813fde7b5a5082628087264da".bytes

        #expect(sharedSecret7.byteArray == peerSharedSecret7.byteArray, "Both parties must agree on the secret")
        #expect(sharedSecret6.byteArray == expectedCompressed6, "Stored secret must be the 33-byte compressed 6G")
        #expect(sharedSecret7.byteArray == expectedCompressed7, "Stored secret must be the 33-byte compressed 7G")
        #expect(
            sharedSecret6.uncompressedRepresentation == Data(expectedUncompressed6),
            "uncompressedRepresentation must be the 65-byte 6G"
        )
        #expect(
            sharedSecret7.uncompressedRepresentation == Data(expectedUncompressed7),
            "uncompressedRepresentation must be the 65-byte 7G"
        )
    }

    @Test("KeyAgreement private-key initializers store a compressed companion public key")
    func privateKeyInitializerCompanionsCompressed() throws {
        let privateBytes = try "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed".bytes

        let generated = try P256K.KeyAgreement.PrivateKey()
        let imported = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateBytes)

        #expect(generated.publicKey.baseKey.format == .compressed, "init() companion should store compressed")
        #expect(imported.publicKey.baseKey.format == .compressed, "init(dataRepresentation:) companion should store compressed")
        #expect(generated.publicKey.dataRepresentation.count == P256K.Format.compressed.length, "init() companion length mismatch")
        #expect(imported.publicKey.dataRepresentation.count == P256K.Format.compressed.length, "init(dataRepresentation:) companion length mismatch")
    }

    @Test("Test Key Agreement Public Key Tweak Addition")
    func keyAgreementPublicKeyTweakAdd() throws {
        let privateSign1 = try P256K.Signing.PrivateKey()
        let privateSign2 = try P256K.Signing.PrivateKey()

        let privateKey1 = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign1.dataRepresentation)
        let privateKey2 = try P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign2.dataRepresentation)

        let publicKey1 = try P256K.KeyAgreement.PublicKey(dataRepresentation: privateKey1.publicKey.dataRepresentation)

        let sharedSecret1 = privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
        let sharedSecret2 = privateKey2.sharedSecretFromKeyAgreement(with: publicKey1)

        #expect(sharedSecret1.byteArray == sharedSecret2.byteArray, "Shared secrets should be equal")

        let symmetricKey1 = SHA256.hash(data: sharedSecret1.byteArray)
        let symmetricKey2 = SHA256.hash(data: sharedSecret2.byteArray)

        let sharedSecretSign1 = try P256K.Schnorr.PrivateKey(dataRepresentation: symmetricKey1.byteArray)
        let sharedSecretSign2 = try P256K.Signing.PrivateKey(dataRepresentation: symmetricKey2.byteArray)

        let privateTweak1 = try sharedSecretSign1.add(Array(privateSign1.publicKey.xonly.dataRepresentation))
        let publicTweak2 = try sharedSecretSign2.publicKey.add(Array(privateSign1.publicKey.xonly.dataRepresentation))

        let schnorrPrivate = try P256K.Schnorr.PrivateKey(dataRepresentation: sharedSecretSign2.dataRepresentation)
        let xonlyTweak2 = try schnorrPrivate.xonly.add(Array(privateSign1.publicKey.xonly.dataRepresentation))

        #expect(
            sharedSecretSign2.publicKey.xonly.parity
                ? privateTweak1.publicKey.dataRepresentation != publicTweak2.dataRepresentation
                : privateTweak1.publicKey.dataRepresentation == publicTweak2.dataRepresentation,
            "Tweak addition expectation mismatch based on parity"
        )

        #expect(privateTweak1.publicKey.xonly.dataRepresentation == xonlyTweak2.dataRepresentation, "Xonly tweaks do not match")
    }
}
