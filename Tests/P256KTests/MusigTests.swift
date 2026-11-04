//
//  MusigTests.swift
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

struct MuSigTestSuite {
    /// Plain point combination with a key's own negation cancels to the point
    /// at infinity — a reachable `secp256k1_ec_pubkey_combine` failure that must
    /// throw rather than return a bogus key. (MuSig aggregation can't reach
    /// this: its per-key coefficients make a cancelling pair require a hash
    /// relation.)
    @Test("Public key combination rejects a key plus its negation")
    func combineRejectsInfinitySum() throws {
        let publicKey = try P256K.Signing.PrivateKey().publicKey
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try publicKey.combine([publicKey.negation])
        }
    }

    /// BIP-327 binds the signer's public key into the secret nonce; upstream
    /// detects a nonce/signing-key mismatch only in `secp256k1_musig_partial_sign`
    /// via an aborting `ARG_CHECK`. P256K checks the binding itself and throws —
    /// once at `generate` when `secretKey` disagrees with `publicKey`, and again
    /// at `partialSignature` when the consumed nonce was bound to another key.
    @Test("MuSig nonce/key mismatch throws instead of aborting")
    func nonceKeyMismatchThrows() throws {
        let privateKeyA = try P256K.Schnorr.PrivateKey()
        let privateKeyB = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKeyA.publicKey, privateKeyB.publicKey])
        let messageHash = SHA256.hash(data: Data("mismatch".utf8))

        // Generate-time check: a provided secretKey must equal publicKey.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKeyA,
                publicKey: privateKeyB.publicKey,
                msg32: Array(messageHash)
            )
        }

        // Signing-time check: a nonce generated for A's key (here with
        // `secretKey: nil`, which skips the generate-time check) cannot sign
        // under B's key.
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: nil,
            publicKey: privateKeyA.publicKey,
            msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        do {
            // `secureNonce` is `~Copyable` — it cannot be consumed inside a
            // `#expect` closure, so this checks the thrown error explicitly.
            _ = try privateKeyB.partialSignature(
                for: messageHash,
                pubnonce: nonce.pubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
            Issue.record("partialSignature with a mismatched nonce/key should throw")
        } catch {
            #expect(error as? secp256k1Error == .underlyingCryptoError)
        }
    }

    /// The bound-key comparison must ignore the key's serialization `Format`:
    /// the same point parsed from uncompressed bytes is the same key — upstream
    /// binds the parsed point, not the wire form — so `generate` must accept it,
    /// and `partialSignature` must accept a nonce bound to the same point in the
    /// other format.
    @Test("MuSig nonce key binding ignores the key's serialization format")
    func nonceKeyMatchIsFormatAgnostic() throws {
        let secretKey = try P256K.Schnorr.PrivateKey()
        let uncompressedPub = try P256K.Schnorr.PublicKey(
            dataRepresentation: secretKey.publicKey.baseKey.uncompressedRepresentation,
            format: .uncompressed
        )

        // Same point, different stored format — `generate` must not throw.
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: secretKey,
            publicKey: uncompressedPub,
            msg32: nil
        )

        // ...and the consumed nonce (bound to the uncompressed-form key) must
        // sign under the compressed-form key.
        let aggregate = try P256K.MuSig.aggregate([secretKey.publicKey])
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        let messageHash = SHA256.hash(data: Data("format".utf8))
        _ = try secretKey.partialSignature(
            for: messageHash,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
    }

    @Test("MuSig Signing and Verification")
    func musig() throws {
        // Test MuSig aggregate
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try P256K.MuSig.aggregate(publicKeys)

        // Create a message to sign
        let message = try #require("Hello, MuSig!".data(using: .utf8))
        let messageHash = SHA256.hash(data: message)

        // Generate nonces for each signer
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: Array(messageHash)
        )

        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: Array(messageHash)
        )

        let thirdNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[2],
            publicKey: privateKeys[2].publicKey,
            msg32: Array(messageHash)
        )

        // Extract public nonces
        let publicNonces = [firstNonce.pubnonce, secondNonce.pubnonce, thirdNonce.pubnonce]

        // Aggregate public nonces
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: publicNonces)

        // Create partial signatures
        let firstPartialSignature = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            xonlyKeyAggregate: aggregate.xonly
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

        // Uncomment to see expected error
//        let forthPartialSignature = try privateKeys[1].partialSignature(
//            for: messageHash,
//            pubnonce: thirdNonce.pubnonce,
//            secureNonce: thirdNonce.secnonce,
//            publicNonceAggregate: aggregateNonce,
//            publicKeyAggregate: aggregate
//        )

        // Aggregate partial signatures
        _ = try P256K.MuSig.aggregateSignatures(
            [firstPartialSignature, secondPartialSignature, thirdPartialSignature],
            for: messageHash,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // Verify the signature
        let firstKey = try #require(publicKeys.first)
        let firstPubnonce = try #require(publicNonces.first)
        #expect(
            try aggregate.isValidSignature(
                firstPartialSignature,
                publicKey: firstKey,
                nonce: firstPubnonce,
                for: messageHash,
                publicNonceAggregate: aggregateNonce
            ),
            "MuSig signature verification failed."
        )
    }

    @Test("MuSig nonce generated without a secret key still signs")
    func musigNonceWithoutSecretKey() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try P256K.MuSig.aggregate(publicKeys)

        let message = try #require("Hello, keyless MuSig nonce!".data(using: .utf8))
        let messageHash = SHA256.hash(data: message)

        // secp256k1_musig_nonce_gen accepts a NULL secret key — passing nil
        // must reach the C layer as NULL, not crash.
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: nil,
            publicKey: privateKeys[0].publicKey,
            msg32: Array(messageHash)
        )

        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: Array(messageHash)
        )

        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

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

        let signature = try P256K.MuSig.aggregateSignatures(
            [firstPartialSignature, secondPartialSignature],
            for: messageHash,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        #expect(aggregate.xonly.isValidSignature(signature, for: messageHash), "MuSig signature from a nil-secret-key nonce failed to verify.")
    }

    @Test("MuSig nonce generation rejects malformed input sizes")
    func musigNonceGenerationRejectsBadSizes() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()

        // A present-but-short extraInput32 must throw, not reach C as a truncated 32-byte read.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: nil,
                extraInput32: [UInt8](repeating: 0xAA, count: 16)
            )
        }

        // A present-but-non-32-byte msg32 must throw too — `secp256k1_musig_nonce_gen`
        // reads a fixed 32 bytes; reducing would silently bind the nonce to the
        // wrong message. `nil` remains legal (message not yet known).
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: [UInt8](repeating: 0xBB, count: 16)
            )
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: [UInt8](repeating: 0xBB, count: 38)
            )
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: [UInt8]()
            )
        }

        // SessionSecretRand enforces the exact 32-byte session_secrand32 contract at construction.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.SessionSecretRand(bytes: [UInt8](repeating: 0x01, count: 16))
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.SessionSecretRand(bytes: [UInt8](repeating: 0x01, count: 33))
        }
    }

    @Test("MuSig nonce generated without a message still signs")
    func musigNonceWithoutMessage() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]

        let publicKeys = privateKeys.map(\.publicKey)
        let aggregate = try P256K.MuSig.aggregate(publicKeys)

        let message = try #require("Hello, messageless MuSig nonce!".data(using: .utf8))
        let messageHash = SHA256.hash(data: message)

        // secp256k1_musig_nonce_gen accepts NULL msg32 — the message binds
        // later at secp256k1_musig_nonce_process inside partialSignature.
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: nil
        )

        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1],
            publicKey: privateKeys[1].publicKey,
            msg32: nil
        )

        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

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

        let signature = try P256K.MuSig.aggregateSignatures(
            [firstPartialSignature, secondPartialSignature],
            for: messageHash,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        #expect(
            aggregate.xonly.isValidSignature(signature, for: messageHash),
            "MuSig signature from message-free nonces failed to verify."
        )
    }

    @Test("Caller-supplied session randomness produces a deterministic public nonce")
    func musigDeterministicPubnonce() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let sessionRandBytes = [UInt8](repeating: 0x42, count: P256K.MuSig.SessionSecretRand.byteCount)
        let messageHash = SHA256.hash(data: Data())

        let first = try P256K.MuSig.Nonce.generate(
            sessionSecretRand: P256K.MuSig.SessionSecretRand(bytes: sessionRandBytes),
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: Array(messageHash),
            extraInput32: nil
        )

        let second = try P256K.MuSig.Nonce.generate(
            sessionSecretRand: P256K.MuSig.SessionSecretRand(bytes: sessionRandBytes),
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: Array(messageHash),
            extraInput32: nil
        )

        #expect(first.pubnonce.dataRepresentation == second.pubnonce.dataRepresentation)
    }

    @Test("MuSig tweaks reject non-32-byte tweaks")
    func musigTweaksRejectBadSizes() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let shortTweak = [UInt8](repeating: 0x01, count: 16)

        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try aggregate.add(shortTweak)
        }
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try aggregate.xonly.add(shortTweak)
        }
    }

    @Test("MuSig x-only key rejects a malformed-length coordinate at construction")
    func musigXonlyKeyRejectsShortCoordinate() throws {
        // `secp256k1_xonly_pubkey_parse` reads a fixed 32 bytes — malformed input
        // is rejected at construction so no downstream path can observe an
        // invalid key.
        #expect(throws: secp256k1Error.incorrectKeySize) {
            _ = try P256K.MuSig.XonlyKey(dataRepresentation: [UInt8](repeating: 2, count: 16))
        }
    }

    /// `secp256k1_musig_nonce_process` binds a fixed 32-byte `msg32` into the
    /// session — the SEC1 digest reduction `partialSignature` applied previously
    /// signed the first 32 bytes of a longer message (or the left-padded value
    /// of a shorter one) without telling the caller. The input is now
    /// `some ContiguousBytes` and requires exactly 32 bytes.
    @Test("MuSig partial signing requires a 32-byte message")
    func musigPartialSignatureRejectsNon32ByteMessages() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])

        // Each `partialSignature` call consumes its `secureNonce`, so every
        // probe signs under a fresh nonce bound to the signer's key.
        func partialSignature(for message: some ContiguousBytes) throws -> (P256K.Schnorr.PartialSignature, P256K.Schnorr.Nonce) {
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey,
                publicKey: privateKey.publicKey,
                msg32: nil
            )
            let pubnonce = nonce.pubnonce
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [pubnonce])
            return try (privateKey.partialSignature(
                for: message,
                pubnonce: pubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            ), pubnonce)
        }

        // 16 bytes, empty, and 38 bytes all throw — a `Digest` conformer cannot
        // bypass the gate either.
        for message in [[UInt8](repeating: 0x01, count: 16), [], [UInt8](repeating: 0xAB, count: 38)] {
            do {
                _ = try partialSignature(for: message)
                Issue.record("partialSignature must reject a \(message.count)-byte message")
            } catch {
                #expect(error as? secp256k1Error == .incorrectParameterSize)
            }
        }

        do {
            _ = try partialSignature(for: TestDigest([UInt8](repeating: 0x01, count: 16)))
            Issue.record("partialSignature must reject a non-32-byte digest")
        } catch {
            #expect(error as? secp256k1Error == .incorrectParameterSize)
        }

        // Exactly 32 bytes — raw bytes, not a `Digest` — signs; aggregating
        // and verifying at natural length proves the session bound them (the
        // partial verifier's own `for:` path is exercised in
        // `MuSigPartialVerifyTestSuite` below).
        let messageBytes = Array(SHA256.hash(data: Data("musig msg32".utf8)))
        let (partial, pubnonce) = try partialSignature(for: messageBytes)
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [pubnonce])
        let signature = try P256K.MuSig.aggregateSignatures(
            [partial],
            for: messageBytes,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        #expect(aggregate.xonly.isValid(signature, for: messageBytes))
    }

    /// The aggregate digest verifier hands the digest's bytes to
    /// `secp256k1_schnorrsig_verify` at their natural length — a >32-byte input
    /// verifies instead of truncating to its leftmost 32 bytes.
    @Test("MuSig aggregate signature verifies the digest at natural length")
    func musigVerifyNaturalLengthDigest() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let message = [UInt8](repeating: 0xCD, count: 38)

        // The package's Schnorr path signs arbitrary-length messages — a
        // reducing verifier would check only the leftmost 32 bytes and fail.
        let signature = try privateKey.signature(customMessage: message)
        let xonly = try P256K.MuSig.XonlyKey(dataRepresentation: privateKey.xonly.bytes)
        let aggregateSignature = try P256K.MuSig.AggregateSignature(dataRepresentation: signature.dataRepresentation)

        #expect(xonly.isValidSignature(aggregateSignature, for: TestDigest(message)))

        // The message's first 32 bytes — what a reducing verifier would have
        // checked — must NOT verify: all 38 bytes are committed.
        #expect(!xonly.isValidSignature(aggregateSignature, for: TestDigest(Array(message.prefix(32)))))
    }

    @Test("MuSig partial signature rejects malformed wire input")
    func musigPartialSignatureRejectsMalformedWire() throws {
        let sessionBytes: [UInt8] = .init(repeating: 0, count: 133)
        let validSessionPrefix: [UInt8] = [0x9D, 0xED, 0xE9, 0x17]
        let session: [UInt8] = validSessionPrefix + [UInt8](repeating: 0, count: 129)

        // Wrong wire size must throw before reaching `partial_sig_parse`.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Schnorr.PartialSignature(
                dataRepresentation: [UInt8](repeating: 0x01, count: 36),
                session: session
            )
        }

        // A session of the wrong size must throw before reaching `session_load`.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Schnorr.PartialSignature(
                dataRepresentation: [UInt8](repeating: 0x01, count: 32),
                session: [UInt8](repeating: 0, count: 64)
            )
        }

        // A right-size session without the upstream magic prefix must throw.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Schnorr.PartialSignature(
                dataRepresentation: [UInt8](repeating: 0x01, count: 32),
                session: sessionBytes
            )
        }

        // A 32-byte blob that isn't a valid scalar fails `partial_sig_parse`.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Schnorr.PartialSignature(
                dataRepresentation: [UInt8](repeating: 0xFF, count: 32),
                session: session
            )
        }
    }

    @Test("MuSig x-only key rejects a malformed cache at construction")
    func musigXonlyKeyRejectsMalformedCache() throws {
        // secp256k1 generator point's X coordinate — a coordinate guaranteed to
        // lift to a curve point so the checks exercise the cache, not the key.
        let coordinate: [UInt8] = [
            0x79, 0xBE, 0x66, 0x7E, 0xF9, 0xDC, 0xBB, 0xAC,
            0x55, 0xA0, 0x62, 0x95, 0xCE, 0x87, 0x0B, 0x07,
            0x02, 0x9B, 0xFC, 0xDB, 0x2D, 0xCE, 0x28, 0xD9,
            0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98
        ]

        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.XonlyKey(dataRepresentation: coordinate, cache: [UInt8](repeating: 0, count: 64))
        }

        // Right-size blob without the keyagg magic prefix must throw, not reach
        // `secp256k1_musig_keyagg_cache_load` → upstream ARG_CHECK.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.XonlyKey(dataRepresentation: coordinate, cache: [UInt8](repeating: 0, count: 197))
        }
    }

    @Test("MuSig signature aggregation rejects an empty collection")
    func musigAggregateRejectsEmpty() throws {
        // `secp256k1_musig_partial_sig_agg` requires at least one signature —
        // the guard must run before the pointer reaches C. The declared
        // session inputs are never reached but must still type-check.
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: nil
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])

        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.aggregateSignatures(
                [],
                for: [UInt8](repeating: 0xAB, count: 32),
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    @Test("MuSig nonce aggregation rejects an empty collection")
    func musigNonceAggregateRejectsEmpty() {
        // `secp256k1_musig_nonce_agg` `ARG_CHECK`s `n_pubnonces > 0`, which
        // aborts the process — the guard must run before the pointer reaches C.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.Nonce(aggregating: [])
        }
    }

    @Test("MuSig aggregation rejects partial signatures from different sessions")
    func musigAggregateRejectsMixedSessions() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let messageHash = try SHA256.hash(data: #require("mixed sessions".data(using: .utf8)))

        // Session A: both signers under one aggregated nonce — sanity check
        // that same-session aggregation succeeds.
        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1], publicKey: privateKeys[1].publicKey, msg32: Array(messageHash)
        )
        let sessionA = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

        let firstPartial = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: sessionA,
            publicKeyAggregate: aggregate
        )
        let secondPartial = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: sessionA,
            publicKeyAggregate: aggregate
        )

        _ = try P256K.MuSig.aggregateSignatures(
            [firstPartial, secondPartial],
            for: messageHash,
            publicNonceAggregate: sessionA,
            publicKeyAggregate: aggregate
        )

        // Session B: a partial signature produced under a different aggregated
        // nonce carries a different session blob and must be rejected rather
        // than silently aggregated under session A's state.
        let foreignNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let secondForeignNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1], publicKey: privateKeys[1].publicKey, msg32: Array(messageHash)
        )
        let sessionB = try P256K.MuSig.Nonce(aggregating: [foreignNonce.pubnonce, secondForeignNonce.pubnonce])
        let foreignPartial = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: foreignNonce.pubnonce,
            secureNonce: foreignNonce.secnonce,
            publicNonceAggregate: sessionB,
            publicKeyAggregate: aggregate
        )

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [firstPartial, foreignPartial],
                for: messageHash,
                publicNonceAggregate: sessionA,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// The aggregate nonce, message, and key aggregate re-declared to
    /// `aggregateSignatures` rebuild the session locally — a declaration that
    /// disagrees with the carried session pairs the signature with a session
    /// it was never bound to and throws rather than silently substituting.
    @Test("MuSig aggregation rejects declared inputs that disagree with the carried session")
    func musigAggregateRejectsMismatchedDeclaredInputs() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let messageHash = SHA256.hash(data: Data("declared session".utf8))
        let otherMessage = Array(SHA256.hash(data: Data("a different message".utf8)))

        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        let partial = try privateKey.partialSignature(
            for: messageHash,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // A different declared message rebuilds a different session — the
        // carried blob can't match it even though the signature is honest.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: otherMessage,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        // A different declared aggregate nonce rebuilds a different session.
        let foreignNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let foreignAggregateNonce = try P256K.MuSig.Nonce(aggregating: [foreignNonce.pubnonce])
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: messageHash,
                publicNonceAggregate: foreignAggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        // A different declared key aggregate rebuilds a different session —
        // the key aggregation cache feeds `nonce_process` directly.
        let otherAggregate = try P256K.MuSig.aggregate([P256K.Schnorr.PrivateKey().publicKey])
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: otherAggregate
            )
        }
    }

    /// A BIP-341-tweaked session's aggregate signature verifies through the
    /// tweaked cache — `pubkey_get` inside `aggregateSignatures` yields the
    /// tweaked point automatically, so the declared tweaked key is what the
    /// final `schnorrsig_verify` checks against.
    @Test("MuSig aggregate signature verifies under a tweaked aggregate key")
    func musigAggregateVerifiesTweakedSession() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let tweak = Array(SHA256.hash(data: Data("taptweak".utf8)))
        let tweakedXonly = try aggregate.xonly.add(tweak)
        let tweakedAggregate = P256K.MuSig.PublicKey(xonlyKey: tweakedXonly)
        let messageHash = SHA256.hash(data: Data("tweaked aggregate".utf8))

        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        let partial = try privateKey.partialSignature(
            for: messageHash,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            xonlyKeyAggregate: tweakedXonly
        )

        let signature = try P256K.MuSig.aggregateSignatures(
            [partial],
            for: messageHash,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: tweakedAggregate
        )
        #expect(tweakedAggregate.xonly.isValidSignature(signature, for: messageHash))

        // The untweaked aggregate key must not verify the tweaked signature.
        #expect(!aggregate.xonly.isValidSignature(signature, for: messageHash))
    }

    /// `aggregateSignatures`'s `for:` is the session's `msg32` — a non-32-byte
    /// input throws `incorrectParameterSize` before the session rebuild,
    /// mirroring the same guard on `partialSignature`.
    @Test("MuSig aggregation requires a 32-byte message")
    func musigAggregateRejectsNon32ByteMessages() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let message: [UInt8] = .init(repeating: 0xAB, count: 32)
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: message
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        let partial = try privateKey.partialSignature(
            for: message,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // 16 bytes, empty, and 38 bytes all throw before the session rebuild.
        for badMessage in [[UInt8](repeating: 0x01, count: 16), [], [UInt8](repeating: 0xAB, count: 38)] {
            #expect(throws: secp256k1Error.incorrectParameterSize) {
                _ = try P256K.MuSig.aggregateSignatures(
                    [partial],
                    for: badMessage,
                    publicNonceAggregate: aggregateNonce,
                    xonlyKeyAggregate: aggregate.xonly
                )
            }
        }
    }

    /// A persisted-and-reloaded aggregate key missing its 197-byte keyagg
    /// cache (`XonlyKey.init(dataRepresentation:…)`'s `cache: []` default —
    /// the verification-only form) cannot rebuild the session: the canonical
    /// `partialSignature` and `aggregateSignatures` both throw
    /// `underlyingCryptoError` on the cache guard instead of reaching
    /// upstream's aborting `keyagg_cache_load` `ARG_CHECK`.
    @Test("MuSig signing paths reject a cacheless aggregate key")
    func musigSigningRejectsCachelessAggregate() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let cacheless = try P256K.MuSig.XonlyKey(
            dataRepresentation: aggregate.xonly.bytes,
            keyParity: aggregate.xonly.parity ? 1 : 0
        )
        let message: [UInt8] = .init(repeating: 0xAB, count: 32)

        // The canonical `partialSignature`'s cache guard fires before any other
        // nonce/key check — the fresh nonce generated inside the probe is a
        // throwaway either way.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey, publicKey: privateKey.publicKey, msg32: message
            )
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
            _ = try privateKey.partialSignature(
                for: message,
                pubnonce: nonce.pubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                xonlyKeyAggregate: cacheless
            )
        }

        // An honest partial (produced under the real cache-carrying key) lets
        // the aggregation probe isolate the cacheless-key guard.
        let signNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: message
        )
        let signAggregateNonce = try P256K.MuSig.Nonce(aggregating: [signNonce.pubnonce])
        let partial = try privateKey.partialSignature(
            for: message,
            pubnonce: signNonce.pubnonce,
            secureNonce: signNonce.secnonce,
            publicNonceAggregate: signAggregateNonce,
            publicKeyAggregate: aggregate
        )
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: message,
                publicNonceAggregate: signAggregateNonce,
                xonlyKeyAggregate: cacheless
            )
        }
    }

    /// `partialSignature`'s `pubnonce:` must equal the companion public nonce
    /// `Nonce.generate` bound inside the secure nonce — the declared value
    /// byte-compares against the stored companion before the first C call, so
    /// a caller with confused nonce bookkeeping throws here instead of
    /// producing a partial that fails an unattributed session check later.
    @Test("MuSig partial signing rejects a pubnonce that differs from the secure nonce's companion")
    func musigPartialSignatureRejectsMismatchedPubnonce() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let messageHash = SHA256.hash(data: Data("pubnonce mismatch".utf8))

        let foreignNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let foreignPubnonce = foreignNonce.pubnonce

        // The declared `pubnonce` belongs to a different nonce pair than
        // `secureNonce` — the byte-compare against the companion stored at
        // generation throws before the nonce is consumed upstream. The
        // `~Copyable` nonce is generated inside the `#expect` closure so its
        // `secnonce` can be consumed there (captured noncopyables cannot be).
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
            )
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
            _ = try privateKey.partialSignature(
                for: messageHash,
                pubnonce: foreignPubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    @Test("MuSig public nonce accessors expose the 66-byte wire form")
    func musigNonceAccessorsYieldWireBytes() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: nil
        )

        // Public accessors expose the stable 66-byte BIP-327 wire form, not the
        // platform-dependent 132-byte internal struct.
        #expect(Array(nonce.pubnonce).count == P256K.Schnorr.publicNonceByteCount)
        #expect(nonce.pubnonce.withUnsafeBytes { Data($0) } == nonce.pubnonce.dataRepresentation)
    }

    /// The multi-party verifier borrows the caller's contiguous storage — any
    /// `ContiguousBytes` conformer must reach `secp256k1_schnorrsig_verify`
    /// correctly: `Data` and `Digest` storage, an `ArraySlice`'s rebased
    /// region, and an empty input failing closed rather than crashing.
    @Test("MuSig aggregate signature verifies across byte-container shapes")
    func musigVerifyAcceptsContiguousByteShapes() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let messageHash = SHA256.hash(data: Data("container shapes".utf8))

        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1], publicKey: privateKeys[1].publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

        let firstPartial = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        let secondPartial = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        let signature = try P256K.MuSig.aggregateSignatures(
            [firstPartial, secondPartial],
            for: messageHash,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        let messageBytes = Array(messageHash)

        // `Data`, `Digest`, a whole array, and an `ArraySlice`'s rebased
        // region all borrow the same 32 message bytes — every shape verifies.
        #expect(aggregate.xonly.isValid(signature, for: messageBytes))
        #expect(aggregate.xonly.isValid(signature, for: Data(messageBytes)))
        #expect(aggregate.xonly.isValid(signature, for: messageHash))
        #expect(aggregate.xonly.isValid(signature, for: ([0xFF] + messageBytes)[1...]))

        // An empty input reaches upstream as `msglen = 0` with a possibly-NULL
        // `msg` — it must fail closed, not crash.
        #expect(aggregate.xonly.isValid(signature, for: [UInt8]()) == false)
    }
}

/// Key-order semantics of `P256K.MuSig.aggregate(_:)` and the canonical
/// `P256K.MuSig.sortedPublicKeys(_:)` helper.
struct MuSigKeyOrderTestSuite {
    /// BIP-327 assigns each key's aggregation coefficient by position — the
    /// second *distinct* key takes coefficient `1` — so `aggregate(_:)`
    /// preserves caller order: `[alice, bob]` and `[bob, alice]` produce
    /// different aggregates. Order-independence is opt-in via
    /// ``P256K/MuSig/sortedPublicKeys(_:)``.
    @Test("MuSig key aggregation preserves the caller's key order")
    func musigAggregatePreservesKeyOrder() throws {
        let alicePrivateKey = try P256K.Schnorr.PrivateKey()
        let bobPrivateKey = try P256K.Schnorr.PrivateKey()

        let forward = try P256K.MuSig.aggregate([alicePrivateKey.publicKey, bobPrivateKey.publicKey])
        let reversed = try P256K.MuSig.aggregate([bobPrivateKey.publicKey, alicePrivateKey.publicKey])

        #expect(
            forward.xonly.bytes != reversed.xonly.bytes,
            "Reversing the key order must produce a different aggregate"
        )
    }

    /// Sorting first restores the canonical ordering: every assembly order of
    /// the same key multiset aggregates identically, and an empty input sorts
    /// to an empty output.
    @Test("Aggregating sortedPublicKeys output is order-invariant")
    func musigSortedPublicKeysRestoreOrderIndependence() throws {
        let keys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ].map(\.publicKey)

        let canonical = try P256K.MuSig.aggregate(P256K.MuSig.sortedPublicKeys(keys))
        let permuted = try P256K.MuSig.aggregate(P256K.MuSig.sortedPublicKeys(Array(keys.reversed())))

        #expect(
            canonical.xonly.bytes == permuted.xonly.bytes,
            "Sorting first must give every input ordering the same aggregate"
        )
        #expect(P256K.MuSig.sortedPublicKeys([]).isEmpty, "Empty input must sort to empty output")
    }

    /// Sorting compares each key's parsed *point* — not its stored wire form —
    /// against lexicographic compressed serialization order, so a point carried
    /// in both `.compressed` and `.uncompressed` form sorts as an
    /// interchangeable duplicate pair and each returned object keeps the format
    /// it arrived with.
    @Test("sortedPublicKeys orders by point and preserves each key's format")
    func musigSortedPublicKeysMixedFormats() throws {
        // `Schnorr.PrivateKey.publicKey` derives its stored form as
        // uncompressed; `PublicKey(xonlyKey:)` rebuilds the same point in
        // compressed form — giving a point-equal pair in different formats.
        let secretKey = try P256K.Schnorr.PrivateKey()
        let uncompressed = secretKey.publicKey
        let compressed = P256K.Schnorr.PublicKey(xonlyKey: secretKey.xonly)
        let other = try P256K.Schnorr.PublicKey(xonlyKey: (P256K.Schnorr.PrivateKey()).xonly)

        let sorted = P256K.MuSig.sortedPublicKeys([uncompressed, other, compressed])

        // The same point twice plus one other key — nothing dropped.
        #expect(sorted.count == 3)

        // Canonical comparison bytes independent of stored format: the
        // 0x02/0x03 prefix byte followed by the 32-byte X coordinate reproduces
        // each key's compressed serialization, which is exactly what
        // `secp256k1_ec_pubkey_sort` memcmps.
        func canonicalBytes(_ publicKey: P256K.Schnorr.PublicKey) -> [UInt8] {
            [publicKey.xonly.parity ? 0x03 : 0x02] + publicKey.xonly.bytes
        }
        let expected = [uncompressed, other, compressed]
            .sorted { canonicalBytes($0).lexicographicallyPrecedes(canonicalBytes($1)) }

        // Comparing canonical bytes rather than object identity keeps the
        // assertion correct even though the equal-point pair's relative order
        // is unspecified.
        #expect(sorted.map(canonicalBytes) == expected.map(canonicalBytes))

        // Each returned object kept the format it arrived with — sorting did
        // not normalize the uncompressed key into compressed form.
        #expect(
            sorted.contains { $0.format == .uncompressed },
            "The uncompressed-form key must keep its stored format"
        )
        #expect(
            sorted.filter { $0.format == .compressed }.count == 2,
            "The compressed-form keys must keep their stored format"
        )
    }
}

/// Signs one partial signature for a single-signer MuSig session and returns it
/// with the signer's pubnonce — the pair `isValidSignature` needs (each call
/// site rebuilds the aggregate nonce, mirroring the verifier's own
/// reconstruction).
private func muSigPartialSignature(
    for message: some ContiguousBytes,
    privateKey: P256K.Schnorr.PrivateKey,
    aggregate: P256K.MuSig.PublicKey
) throws -> (P256K.Schnorr.PartialSignature, P256K.Schnorr.Nonce) {
    let nonce = try P256K.MuSig.Nonce.generate(
        secretKey: privateKey,
        publicKey: privateKey.publicKey,
        msg32: nil
    )
    let pubnonce = nonce.pubnonce
    let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [pubnonce])
    return try (privateKey.partialSignature(
        for: message,
        pubnonce: pubnonce,
        secureNonce: nonce.secnonce,
        publicNonceAggregate: aggregateNonce,
        publicKeyAggregate: aggregate
    ), pubnonce)
}

/// B-4 session-provenance coverage: `MuSig.PublicKey.isValidSignature` verifies
/// against a session rebuilt from the caller's declared (message, aggregate
/// nonce) — never the session blob the signature happens to carry.
struct MuSigPartialVerifyTestSuite {
    /// The partial verifier once ignored its `for:` input — it loaded whatever
    /// session blob the signature carried, so a signature produced over a
    /// different message reported "valid" for any declared digest. The verifier
    /// now rebuilds the session locally from the caller's `publicNonceAggregate`,
    /// a 32-byte `for:` message, and the key aggregation cache — upstream's
    /// documented verifier flow — requires the carried session blob to match it,
    /// and throws on a non-32-byte message.
    @Test("MuSig partial signature verification consults the declared message")
    func musigPartialSignatureVerifyConsultsMessage() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let message = Array(SHA256.hash(data: Data("partial verify".utf8)))
        let otherMessage = Array(SHA256.hash(data: Data("other".utf8)))

        let (partial, pubnonce) = try muSigPartialSignature(for: message, privateKey: privateKey, aggregate: aggregate)
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [pubnonce])

        // Honest inputs verify — the carried session blob is exactly what the
        // verifier rebuilds from (aggregateNonce, message, cache).
        #expect(try aggregate.isValidSignature(
            partial,
            publicKey: privateKey.publicKey,
            nonce: pubnonce,
            for: message,
            publicNonceAggregate: aggregateNonce
        ))

        // A signature produced over a DIFFERENT message must not verify for the
        // declared message — under the old signature the unconsulted `for:` let
        // the carried session answer for itself and this returned `true`. It
        // verifies once the caller declares the message actually signed.
        let (otherPartial, otherPubnonce) = try muSigPartialSignature(for: otherMessage, privateKey: privateKey, aggregate: aggregate)
        let otherAggregateNonce = try P256K.MuSig.Nonce(aggregating: [otherPubnonce])
        #expect(try aggregate.isValidSignature(
            otherPartial,
            publicKey: privateKey.publicKey,
            nonce: otherPubnonce,
            for: message,
            publicNonceAggregate: otherAggregateNonce
        ) == false)
        #expect(try aggregate.isValidSignature(
            otherPartial,
            publicKey: privateKey.publicKey,
            nonce: otherPubnonce,
            for: otherMessage,
            publicNonceAggregate: otherAggregateNonce
        ))

        // The message feeds `secp256k1_musig_nonce_process`'s fixed `msg32` — a
        // non-32-byte input throws like the package's other `msg32` gates.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try aggregate.isValidSignature(
                partial,
                publicKey: privateKey.publicKey,
                nonce: pubnonce,
                for: [UInt8](repeating: 0xAB, count: 38),
                publicNonceAggregate: aggregateNonce
            )
        }
    }

    /// A `PartialSignature` is a compound — signature bytes plus carried session
    /// — and the compound is dishonest when its session came from elsewhere. The
    /// byte-match requirement fails the pair here, before the mismatched
    /// contribution can reach `aggregateSignatures` where the culprit is lost.
    @Test("MuSig partial signature verification rejects a foreign session blob")
    func musigPartialSignatureVerifyRejectsForeignSession() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let message = Array(SHA256.hash(data: Data("foreign session".utf8)))

        let (partial, pubnonce) = try muSigPartialSignature(for: message, privateKey: privateKey, aggregate: aggregate)
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [pubnonce])
        let (otherPartial, otherPubnonce) = try muSigPartialSignature(for: message, privateKey: privateKey, aggregate: aggregate)
        let otherAggregateNonce = try P256K.MuSig.Nonce(aggregating: [otherPubnonce])

        // A signature valid for the declared session but carrying another
        // session's blob — constructible through the public
        // `init(dataRepresentation:session:)` — fails the compound check.
        let mismatched = try P256K.Schnorr.PartialSignature(
            dataRepresentation: partial.dataRepresentation,
            session: otherPartial.session
        )
        #expect(try aggregate.isValidSignature(
            mismatched,
            publicKey: privateKey.publicKey,
            nonce: pubnonce,
            for: message,
            publicNonceAggregate: aggregateNonce
        ) == false)

        // The declared aggregate nonce drives the rebuilt session — the honest
        // signature declared under a different session fails too.
        #expect(try aggregate.isValidSignature(
            partial,
            publicKey: privateKey.publicKey,
            nonce: pubnonce,
            for: message,
            publicNonceAggregate: otherAggregateNonce
        ) == false)
    }

    /// The rebuilt session mixes `agg_pk32` and the tweak out of the key
    /// aggregation cache, so a BIP-341-tweaked session's partial signature
    /// verifies only through a `PublicKey` carrying the *tweaked* cache —
    /// `MuSig.PublicKey(xonlyKey:)` lifts the tweaked ``MuSig.XonlyKey`` for
    /// exactly that.
    @Test("MuSig partial signature verification requires the tweaked cache")
    func musigPartialSignatureVerifyTweakedSession() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let tweak = Array(SHA256.hash(data: Data("taptweak".utf8)))
        let tweakedXonly = try aggregate.xonly.add(tweak)
        let tweakedAggregate = P256K.MuSig.PublicKey(xonlyKey: tweakedXonly)
        let message = Array(SHA256.hash(data: Data("tweaked session".utf8)))

        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: nil
        )
        let pubnonce = nonce.pubnonce
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [pubnonce])
        let partial = try privateKey.partialSignature(
            for: message,
            pubnonce: pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            xonlyKeyAggregate: tweakedXonly
        )

        // Verifying through the tweaked cache rebuilds the tweaked session —
        // the carried blob matches and the signature verifies.
        #expect(try tweakedAggregate.isValidSignature(
            partial,
            publicKey: privateKey.publicKey,
            nonce: pubnonce,
            for: message,
            publicNonceAggregate: aggregateNonce
        ))

        // The untweaked aggregate rebuilds a different session — the carried
        // blob can't match it even though the signature itself is honest.
        #expect(try aggregate.isValidSignature(
            partial,
            publicKey: privateKey.publicKey,
            nonce: pubnonce,
            for: message,
            publicNonceAggregate: aggregateNonce
        ) == false)
    }
}

/// A `Digest` conformer of caller-supplied byte content — feeds non-32-byte
/// digest-shaped inputs through `Digest`-typed parameters. `byteCount` is a
/// protocol requirement these paths never consult; `withUnsafeBytes` supplies
/// the real count.
private struct TestDigest: Digest {
    static var byteCount: Int {
        0
    }

    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var description: String {
        "TestDigest: \(bytes.map { String(format: "%02x", $0) }.joined())"
    }

    func makeIterator() -> IndexingIterator<[UInt8]> {
        bytes.makeIterator()
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}
