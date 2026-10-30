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
        _ = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature, thirdPartialSignature])

        // Verify the signature
        let firstKey = try #require(publicKeys.first)
        let firstPubnonce = try #require(publicNonces.first)
        #expect(
            aggregate.isValidSignature(firstPartialSignature, publicKey: firstKey, nonce: firstPubnonce, for: messageHash),
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

        let signature = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature])

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

        let signature = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature])

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

    @Test("MuSig partial signing normalizes non-32-byte digests")
    func musigPartialSignatureNormalizesShortDigest() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let shortDigest: ShortDigest = .init([UInt8](repeating: 0x01, count: 16))

        // secp256k1_musig_nonce_process reads exactly 32 bytes of msg32 — the
        // digest is reduced to its SEC1 integer value instead of throwing.
        // The ~Copyable NonceResult is created inside the flow so nothing
        // noncopyable is captured.
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0],
            publicKey: privateKeys[0].publicKey,
            msg32: nil
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        let partialSignature = try privateKeys[0].partialSignature(
            for: shortDigest,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // The same normalized digest verifies against the partial signature.
        #expect(aggregate.isValidSignature(
            partialSignature,
            publicKey: privateKeys[0].publicKey,
            nonce: nonce.pubnonce,
            for: shortDigest
        ))
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
    func musigAggregateRejectsEmpty() {
        // `secp256k1_musig_partial_sig_agg` requires at least one signature —
        // the guard must run before the pointer reaches C.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.aggregateSignatures([])
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

        _ = try P256K.MuSig.aggregateSignatures([firstPartial, secondPartial])

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
            _ = try P256K.MuSig.aggregateSignatures([firstPartial, foreignPartial])
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
        let signature = try P256K.MuSig.aggregateSignatures([firstPartial, secondPartial])
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

/// A 16-byte digest stub used to verify `partialSignature` normalizes non-32-byte
/// digests before the bytes reach `secp256k1_musig_nonce_process`.
private struct ShortDigest: Digest {
    static var byteCount: Int {
        16
    }

    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    var description: String {
        "ShortDigest: \(bytes.map { String(format: "%02x", $0) }.joined())"
    }

    func makeIterator() -> IndexingIterator<[UInt8]> {
        bytes.makeIterator()
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try bytes.withUnsafeBytes(body)
    }
}
