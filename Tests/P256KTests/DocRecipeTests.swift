//
//  DocRecipeTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(CryptoKit)
    import CryptoKit
#endif
import Foundation
import P256K
import Testing

/// Compile-and-run scaffold for the DocC recipe articles — each test mirrors
/// an article's exact code so a recipe cannot silently drift from the API.
/// A plain `import` (not `@testable`) keeps that proof honest: the recipes
/// must compile as consumer code.
struct DocRecipeTests {
    #if Xcode || ENABLE_MODULE_SCHNORRSIG
        /// Mirrors `SigningFixedSizeMessages`: hash → `signature(message:)` →
        /// `xonly.isValid` — plus the 32-byte gate the article documents.
        @Test("Recipe: fixed-32-byte Schnorr sign and verify")
        func signingFixedSizeMessageRecipe() throws {
            let privateKey = try P256K.Schnorr.PrivateKey()

            // The protocol's committed message is a 32-byte hash — or becomes one.
            let messageData = Data("Vires in Numeris.".utf8)
            let messageHash = SHA256.hash(data: messageData)

            // Sign — fresh auxiliary randomness is drawn internally.
            let signature = try privateKey.signature(message: messageHash)

            // Verify against the signer's x-only public identity.
            let isValid = privateKey.xonly.isValid(signature, for: messageHash)

            #expect(isValid)

            // A non-32-byte input through the 32-byte method throws.
            let unhashed100 = Data(repeating: 0xAB, count: 100)
            #expect(throws: secp256k1Error.incorrectParameterSize) {
                try privateKey.signature(message: unhashed100)
            }
        }
    #endif

    #if Xcode || ENABLE_MODULE_ECDH
        /// Mirrors `DerivingKeysFromSharedSecrets` step 1: both parties derive
        /// the identical compressed point, and slicing the prefix byte yields
        /// the bare 32-byte shared x — from the uncompressed layout too.
        @Test("Recipe: ECDH shared secret → shared x coordinate")
        func sharedSecretXCoordinateRecipe() throws {
            let privateKey = try P256K.KeyAgreement.PrivateKey()
            let peerPrivateKey = try P256K.KeyAgreement.PrivateKey()

            // Both parties derive the identical 33-byte compressed point.
            let sharedSecret = privateKey.sharedSecretFromKeyAgreement(with: peerPrivateKey.publicKey)
            let peerSharedSecret = peerPrivateKey.sharedSecretFromKeyAgreement(with: privateKey.publicKey)

            // Slice the compressed-point prefix byte → the bare 32-byte shared x.
            // (byteArray is the article's documented convenience for needing
            // the raw bytes — here, to check the layout claims.)
            let sharedX = Data(sharedSecret.byteArray.dropFirst())
            let peerSharedX = Data(peerSharedSecret.byteArray.dropFirst())

            #expect(sharedX.count == 32)
            #expect(sharedX == peerSharedX)

            // The uncompressed layout: x is 0-indexed bytes 1–32 (the 32 bytes
            // after the 0x04 prefix), never the last 32 — that's the y coordinate.
            let uncompressed = privateKey.sharedSecretFromKeyAgreement(
                with: peerPrivateKey.publicKey,
                format: .uncompressed
            )
            let sharedXFromUncompressed = Data(uncompressed.byteArray.dropFirst().prefix(32))
            #expect(sharedXFromUncompressed == sharedX)
        }

        #if canImport(CryptoKit)
            /// Mirrors `DerivingKeysFromSharedSecrets` step 2: the scoped borrow →
            /// `SymmetricKey` input key material → `HKDF` with the protocol's salt.
            /// Needs CryptoKit — on Linux a consumer would import `Crypto` from
            /// apple/swift-crypto, which this package does not declare (P256K
            /// vendors swift-crypto internally and exports no `Crypto` module),
            /// so this half is Apple-only here.
            @Test("Recipe: shared x → HKDF (NIP-44 shape)")
            func sharedSecretKeyDerivationRecipe() throws {
                let privateKey = try P256K.KeyAgreement.PrivateKey()
                let peerPrivateKey = try P256K.KeyAgreement.PrivateKey()

                let sharedSecret = privateKey.sharedSecretFromKeyAgreement(with: peerPrivateKey.publicKey)
                let peerSharedSecret = peerPrivateKey.sharedSecretFromKeyAgreement(with: privateKey.publicKey)
                let uncompressed = privateKey.sharedSecretFromKeyAgreement(
                    with: peerPrivateKey.publicKey,
                    format: .uncompressed
                )
                let sharedX = Data(sharedSecret.byteArray.dropFirst())
                let inputKeyMaterial = sharedSecret.withUnsafeBytes { bytes in
                    SymmetricKey(data: bytes.dropFirst())
                }
                let peerInputKeyMaterial = peerSharedSecret.withUnsafeBytes { bytes in
                    SymmetricKey(data: bytes.dropFirst())
                }

                // NIP-44 v2's conversation key:
                // HKDF-extract(sha256, ikm = shared_x, salt = utf8("nip44-v2")).
                let conversationKey = HKDF<CryptoKit.SHA256>.extract(
                    inputKeyMaterial: inputKeyMaterial,
                    salt: Data("nip44-v2".utf8)
                )
                let peerConversationKey = HKDF<CryptoKit.SHA256>.extract(
                    inputKeyMaterial: peerInputKeyMaterial,
                    salt: Data("nip44-v2".utf8)
                )
                #expect(
                    conversationKey.withUnsafeBytes { Array($0) }
                        == peerConversationKey.withUnsafeBytes { Array($0) }
                )

                // Fixture-free known-answer pin: RFC 5869 HKDF-Extract(salt, IKM)
                // is exactly HMAC(key: salt, msg: IKM) — a swapped ikm/salt or a
                // wrong salt string fails this even when both sides agree.
                let hmacKey = HMAC<CryptoKit.SHA256>.authenticationCode(
                    for: sharedX,
                    using: SymmetricKey(data: Data("nip44-v2".utf8))
                )
                #expect(
                    conversationKey.withUnsafeBytes { Array($0) }
                        == hmacKey.withUnsafeBytes { Array($0) }
                )

                // The uncompressed layout produces the same input key material.
                let uncompressedInputKeyMaterial = uncompressed.withUnsafeBytes { bytes in
                    SymmetricKey(data: bytes.dropFirst().prefix(32))
                }
                #expect(
                    uncompressedInputKeyMaterial.withUnsafeBytes { Array($0) }
                        == inputKeyMaterial.withUnsafeBytes { Array($0) }
                )

                // The article's extract+expand convenience form.
                let sessionKey = HKDF<CryptoKit.SHA256>.deriveKey(
                    inputKeyMaterial: inputKeyMaterial,
                    salt: Data("my-protocol-v1".utf8),
                    info: Data("session".utf8),
                    outputByteCount: 32
                )
                #expect(sessionKey.bitCount == 256)
            }
        #endif
    #endif
}
