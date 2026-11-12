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
import libsecp256k1
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

        // Verify the signature — the envelope carries the signer's public key
        // and public nonce, so the verifier needs only the declared session.
        #expect(
            try aggregate.isValidSignature(
                firstPartialSignature,
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

    /// GHSA-7g3x-fj89-693j: `add(_:format:)` once fed the *output* format's
    /// length into `secp256k1_ec_pubkey_parse` as `inputlen` while parsing
    /// the key's *stored* serialization — always 33-byte compressed on
    /// cache-carrying keys — so `.uncompressed` rejected a valid key and the
    /// wrapper escalated the rejection to `invariantFailure`, terminating
    /// the process. The reparse is deleted outright: the tweak writes the
    /// output key purely from the key-aggregation cache, so the parse's
    /// result was never consumed; `format` sizes the output buffer only.
    @Test("MuSig tweak honors an uncompressed output format")
    func musigTweakUncompressedOutput() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let tweak = [UInt8](repeating: 0x01, count: P256K.ByteLength.dimension)

        let compressed = try aggregate.add(tweak)
        let uncompressed = try aggregate.add(tweak, format: .uncompressed)

        #expect(uncompressed.format == .uncompressed)
        #expect(uncompressed.dataRepresentation.count == P256K.Format.uncompressed.length)
        // Same point as the compressed-format result — upstream's
        // serialize-both-ways oracle.
        #expect(uncompressed.xonly == compressed.xonly)
        #expect(uncompressed.xonly.parity == compressed.xonly.parity)
    }

    /// The reverse direction of the same mismatch: a tweak that stores
    /// `.uncompressed` bytes — now reachable for the first time — must still
    /// tweak correctly with the default `.compressed` output, proving the
    /// stored format never leaks into the next call either.
    @Test("MuSig tweak on an uncompressed-stored key stays tweakable")
    func musigTweakChainedFormats() throws {
        let aggregate = try P256K.MuSig.aggregate([P256K.Schnorr.PrivateKey().publicKey])
        let firstTweak = [UInt8](repeating: 0x01, count: P256K.ByteLength.dimension)
        let secondTweak = [UInt8](repeating: 0x02, count: P256K.ByteLength.dimension)

        let uncompressed = try aggregate.add(firstTweak, format: .uncompressed)
        let rechained = try uncompressed.add(secondTweak)

        #expect(rechained.format == .compressed)
        #expect(rechained.dataRepresentation.count == P256K.Format.compressed.length)
        // The intermediate wire format must not change the point: the chain
        // equals a compressed-store first tweak followed by the same second.
        let expected = try aggregate.add(firstTweak).add(secondTweak)
        #expect(rechained.xonly == expected.xonly)
        #expect(rechained.xonly.parity == expected.xonly.parity)
    }

    /// The format oracles above prove both outputs describe *a* shared
    /// point — this proves it is the *right* point: `add` must produce
    /// `agg_pk + tweak·G`, the same result the independent
    /// `secp256k1_ec_pubkey_tweak_add` path (`Signing.PublicKey.add`)
    /// yields on the same aggregate point.
    @Test("MuSig EC tweak agrees with the plain public-key tweak oracle")
    func musigTweakMatchesPublicKeyOracle() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let tweak = [UInt8](repeating: 0x01, count: P256K.ByteLength.dimension)

        let oracle = try P256K.Signing.PublicKey(
            dataRepresentation: aggregate.dataRepresentation,
            format: .compressed
        ).add(tweak)

        #expect(try aggregate.add(tweak).dataRepresentation == oracle.dataRepresentation)
        #expect(try aggregate.add(tweak, format: .uncompressed).dataRepresentation == oracle.uncompressedRepresentation)
    }

    /// A `MuSig.PublicKey` rebuilt via `init(dataRepresentation:format:)`
    /// carries no key-aggregation cache — the opaque upstream struct has no
    /// blessed serialization (`MuSig.swift`), so the key is verification-only.
    /// `add` must throw before the missing cache reaches
    /// `secp256k1_musig_keyagg_cache_load`, whose `ARG_CHECK` would abort the
    /// process — the same reachable-crash class as GHSA-7g3x-fj89-693j.
    @Test("MuSig tweak on a cache-less key throws instead of aborting")
    func musigTweakOnCachelessKeyThrows() throws {
        let aggregate = try P256K.MuSig.aggregate([P256K.Schnorr.PrivateKey().publicKey])
        let rebuilt = try P256K.MuSig.PublicKey(
            dataRepresentation: aggregate.dataRepresentation,
            format: .compressed
        )

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try rebuilt.add([UInt8](repeating: 0x01, count: P256K.ByteLength.dimension))
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
        let xonly = try P256K.MuSig.XonlyKey(dataRepresentation: privateKey.xonly.dataRepresentation)
        let aggregateSignature = try P256K.MuSig.AggregateSignature(dataRepresentation: signature.dataRepresentation)

        #expect(xonly.isValidSignature(aggregateSignature, for: TestDigest(message)))

        // The message's first 32 bytes — what a reducing verifier would have
        // checked — must NOT verify: all 38 bytes are committed.
        #expect(!xonly.isValidSignature(aggregateSignature, for: TestDigest(Array(message.prefix(32)))))
    }

    @Test("MuSig partial signature rejects malformed wire input")
    func musigPartialSignatureRejectsMalformedWire() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey,
            publicKey: privateKey.publicKey,
            msg32: nil
        )

        // Wrong wire size must throw before reaching `partial_sig_parse`.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.Schnorr.PartialSignature(
                dataRepresentation: [UInt8](repeating: 0x01, count: 36),
                publicKey: privateKey.publicKey,
                nonce: nonce.pubnonce
            )
        }

        // A 32-byte blob that isn't a valid scalar fails `partial_sig_parse`.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.Schnorr.PartialSignature(
                dataRepresentation: [UInt8](repeating: 0xFF, count: 32),
                publicKey: privateKey.publicKey,
                nonce: nonce.pubnonce
            )
        }

        // The bundled signer identity and public nonce are typed values — the
        // envelope no longer accepts raw opaque blobs for either.
        let partial = try P256K.Schnorr.PartialSignature(
            dataRepresentation: [UInt8](repeating: 0x01, count: 32),
            publicKey: privateKey.publicKey,
            nonce: nonce.pubnonce
        )
        #expect(partial.publicKey.musigIdentity == privateKey.publicKey.musigIdentity)
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
            _ = try XonlyKeyImplementation(dataRepresentation: coordinate, keyParity: 0, cache: [UInt8](repeating: 0, count: 64))
        }

        // Right-size blob without the keyagg magic prefix must throw, not reach
        // `secp256k1_musig_keyagg_cache_load` → upstream ARG_CHECK.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try XonlyKeyImplementation(dataRepresentation: coordinate, keyParity: 0, cache: [UInt8](repeating: 0, count: 197))
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
        // nonce is bound to a different rebuilt session and must be rejected
        // rather than silently aggregated under session A's state. The signer
        // is a genuine participant so the failure lands in per-partial
        // verification — attributed to its submission index.
        let foreignNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let secondForeignNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1], publicKey: privateKeys[1].publicKey, msg32: Array(messageHash)
        )
        let sessionB = try P256K.MuSig.Nonce(aggregating: [foreignNonce.pubnonce, secondForeignNonce.pubnonce])
        let foreignPartial = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondForeignNonce.pubnonce,
            secureNonce: secondForeignNonce.secnonce,
            publicNonceAggregate: sessionB,
            publicKeyAggregate: aggregate
        )

        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 1)) {
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
    /// disagrees with what the signature was bound to fails per-partial
    /// verification with the contributor's index rather than silently
    /// substituting.
    @Test("MuSig aggregation rejects declared inputs that disagree with the bound session")
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
        // honest signature no longer verifies under it.
        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 0)) {
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
        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 0)) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: messageHash,
                publicNonceAggregate: foreignAggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        // A different declared key aggregate carries a different participant
        // list — this signer's key isn't a member of it, so the multiset check
        // rejects the contribution before any cryptographic work.
        let otherAggregate = try P256K.MuSig.aggregate([P256K.Schnorr.PrivateKey().publicKey])
        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 0)) {
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

    /// A persisted-and-reloaded aggregate key — `XonlyKey.init(dataRepresentation:…)`
    /// takes no cache, so a key rebuilt from serialized bytes is intrinsically
    /// cacheless (the verification-only form) — cannot rebuild the session: the
    /// canonical `partialSignature` and `aggregateSignatures` both throw
    /// `underlyingCryptoError` on the cache guard instead of reaching
    /// upstream's aborting `keyagg_cache_load` `ARG_CHECK`.
    @Test("MuSig signing paths reject a cacheless aggregate key")
    func musigSigningRejectsCachelessAggregate() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let cacheless = try P256K.MuSig.XonlyKey(
            dataRepresentation: aggregate.xonly.dataRepresentation,
            keyParity: aggregate.xonly.parity
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

    /// `partialSignature` gates the signing key on the aggregate's retained
    /// participant list before any nonce check — BIP-327's `Sign` raises when
    /// `GetSessionKeyAggCoeff` cannot find the key, and upstream's `keyaggcoef`
    /// would otherwise produce a partial that verifies yet can never join the
    /// aggregate. A signer whose key is absent from `aggregate(_:)`'s list
    /// throws `underlyingCryptoError` instead of signing.
    @Test("MuSig partial signing rejects a key outside the participant list")
    func musigPartialSignatureRejectsNonParticipantSigner() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let outsider = try P256K.Schnorr.PrivateKey()
        // The aggregate's participant list contains only `privateKey` — the
        // outsider's key has a `keyaggcoef` but no session slot.
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let messageHash = SHA256.hash(data: Data("non-participant signer".utf8))

        // The outsider generates a well-formed nonce pair — the membership
        // guard, not nonce validity, is what must throw.
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: outsider, publicKey: outsider.publicKey, msg32: Array(messageHash)
            )
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
            _ = try outsider.partialSignature(
                for: messageHash,
                pubnonce: nonce.pubnonce,
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
            forward.xonly.dataRepresentation != reversed.xonly.dataRepresentation,
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
            canonical.xonly.dataRepresentation == permuted.xonly.dataRepresentation,
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
            [publicKey.xonly.parity ? 0x03 : 0x02] + publicKey.xonly.dataRepresentation
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

/// `aggregateSignatures` requires the submitted signer identities to equal the
/// session's participant list as a *multiset* — BIP-327's `pk 1..u` with
/// duplicates legal. A missing member fails the count check; a stranger, an
/// over-contributing duplicate, or a mislabeled envelope throws
/// `invalidMuSigContribution` naming the position.
struct MuSigContributionSetTestSuite {
    /// A two-signer session receiving only one contribution fails the count
    /// check before any signer identity is examined — the failure is a wrong
    /// parameter size, not an attributed contribution.
    @Test("MuSig aggregation rejects an incomplete signer set")
    func musigAggregateRejectsIncompleteSignerSet() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let messageHash = SHA256.hash(data: Data("incomplete set".utf8))

        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let otherNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1], publicKey: privateKeys[1].publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce, otherNonce.pubnonce])
        let partial = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // One honest contribution for a two-participant session — the missing
        // signer is a count failure, not an attributed bad contribution.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// `partial_sig_verify` alone proves only algebraic consistency —
    /// `keyaggcoef` assigns a coefficient to *any* public key, so a stranger's
    /// valid partial would verify per-signature yet corrupt the aggregate. The
    /// multiset gate rejects the bundled non-participant identity first.
    @Test("MuSig aggregation rejects a non-participant contribution")
    func musigAggregateRejectsNonParticipant() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let stranger = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let messageHash = SHA256.hash(data: Data("non-participant".utf8))

        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])

        // A stranger's *algebraically valid* partial for this session —
        // produced through the same C calls a raw-libsecp256k1 attacker uses,
        // since the public `partialSignature` refuses a non-participant at
        // signing — can only be rejected by the membership gate, not by
        // `partial_sig_verify` (`keyaggcoef` gives the stranger a coefficient).
        let foreignPartial = try foreignMuSigPartialSignature(
            for: messageHash,
            signer: stranger,
            keyAggregate: aggregate,
            publicNonceAggregate: aggregateNonce
        )
        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 0)) {
            _ = try P256K.MuSig.aggregateSignatures(
                [foreignPartial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// One signer submitting both slots consumes the other's participant
    /// allowance — the first duplicate passes membership, the second finds the
    /// tally depleted and is attributed by index.
    @Test("MuSig aggregation rejects a duplicated contribution")
    func musigAggregateRejectsDuplicatedContribution() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let messageHash = SHA256.hash(data: Data("duplicated contribution".utf8))

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

        // The same envelope twice: index 0 consumes the key's only allowance,
        // index 1 over-contributes.
        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 1)) {
            _ = try P256K.MuSig.aggregateSignatures(
                [firstPartial, firstPartial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// BIP-327 permits the same public key at multiple participant positions —
    /// each occurrence gets its own key-aggregation coefficient and signs its
    /// own nonce. Two envelopes bundling the same key are legal exactly when
    /// the participant list contains the key twice.
    @Test("MuSig aggregation accepts legal duplicate participant keys")
    func musigAggregateAcceptsDuplicateParticipantKeys() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey, privateKey.publicKey])
        let messageHash = SHA256.hash(data: Data("duplicate participant".utf8))

        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

        let firstPartial = try privateKey.partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        let secondPartial = try privateKey.partialSignature(
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
        #expect(aggregate.xonly.isValidSignature(signature, for: messageHash))
    }

    /// A participant who signs under the declared session but with an
    /// *uncontributed* nonce pair defeats every per-partial check —
    /// `partial_sig_verify` cannot prove the bundled nonce entered the
    /// aggregate — and previously reached the final `schnorrsig_verify`
    /// failure, terminating the process. Re-aggregating the bundled nonces
    /// and comparing against the declared aggregate closes the path; the
    /// mismatch is a set property, so the throw is unattributed.
    @Test("MuSig aggregation rejects a participant's uncontributed nonce")
    func musigAggregateRejectsUncontributedNonce() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let messageHash = SHA256.hash(data: Data("uncontributed nonce".utf8))

        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[1], publicKey: privateKeys[1].publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

        // The first signer contributes `firstNonce` to the aggregate but signs
        // with a second, unpublished nonce pair — the bundled pubnonce was
        // never part of `aggregateNonce`.
        let rogueNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKeys[0], publicKey: privateKeys[0].publicKey, msg32: Array(messageHash)
        )
        let roguePartial = try privateKeys[0].partialSignature(
            for: messageHash,
            pubnonce: rogueNonce.pubnonce,
            secureNonce: rogueNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        let honestPartial = try privateKeys[1].partialSignature(
            for: messageHash,
            pubnonce: secondNonce.pubnonce,
            secureNonce: secondNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        // The standalone verifier cannot detect the shape: the signature is
        // algebraically consistent and the signer is a participant.
        #expect(try aggregate.isValidSignature(
            roguePartial,
            for: messageHash,
            publicNonceAggregate: aggregateNonce
        ) == true)

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [roguePartial, honestPartial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// Resubmitting the same partial for both slots of a duplicated
    /// participant key passes the membership tally (the key legitimately
    /// occupies two positions) but bundles only one nonce — the nonce-set
    /// check rejects it where key identity alone could not.
    @Test("MuSig aggregation rejects a resubmitted partial under duplicate keys")
    func musigAggregateRejectsResubmissionUnderDuplicateKeys() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey, privateKey.publicKey])
        let messageHash = SHA256.hash(data: Data("duplicate key resubmission".utf8))

        let firstNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let secondNonce = try P256K.MuSig.Nonce.generate(
            secretKey: privateKey, publicKey: privateKey.publicKey, msg32: Array(messageHash)
        )
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])
        let firstPartial = try privateKey.partialSignature(
            for: messageHash,
            pubnonce: firstNonce.pubnonce,
            secureNonce: firstNonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [firstPartial, firstPartial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// Cross-wiring two honest contributions' bundled nonces preserves the
    /// nonce *set* — aggregation is commutative — so the envelopes reach
    /// per-partial verification, where each signature fails under the other
    /// signer's nonce and is attributed by index.
    @Test("MuSig aggregation attributes a mislabeled envelope")
    func musigAggregateAttributesCrossWiredEnvelopes() throws {
        let privateKeys = try [
            P256K.Schnorr.PrivateKey(),
            P256K.Schnorr.PrivateKey()
        ]
        let aggregate = try P256K.MuSig.aggregate(privateKeys.map(\.publicKey))
        let messageHash = SHA256.hash(data: Data("cross-wired envelopes".utf8))

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

        // First signer's bytes bundled with the second signer's nonce — the
        // nonce set is unchanged, so the failure is attributed by index.
        let mislabeled = try P256K.Schnorr.PartialSignature(
            dataRepresentation: firstPartial.dataRepresentation,
            publicKey: privateKeys[0].publicKey,
            nonce: secondNonce.pubnonce
        )
        #expect(throws: secp256k1Error.invalidMuSigContribution(index: 0)) {
            _ = try P256K.MuSig.aggregateSignatures(
                [mislabeled, secondPartial],
                for: messageHash,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }
    }

    /// A key rebuilt from serialized bytes carries no participant list and no
    /// key-aggregation cache — `aggregateSignatures` hits the cache guard
    /// before the membership check and throws `underlyingCryptoError`, while
    /// `isValidSignature`'s unusable-input contract reports the same condition
    /// as `false` rather than answering from an empty participant set.
    @Test("MuSig session APIs reject a key rebuilt without participant provenance")
    func musigSessionRejectsReconstructedKey() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let reconstructed = try P256K.MuSig.PublicKey(
            dataRepresentation: aggregate.dataRepresentation,
            format: aggregate.format
        )
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

        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.aggregateSignatures(
                [partial],
                for: message,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: reconstructed
            )
        }

        // The verifier's contract is `false` for any unusable input — the
        // missing cache makes the honest contribution unverifiable, not an error.
        #expect(try reconstructed.isValidSignature(
            partial,
            for: message,
            publicNonceAggregate: aggregateNonce
        ) == false)
    }
}

/// Signs one partial signature for a single-signer MuSig session — the envelope
/// carries the signer's public key and pubnonce, so the return value is all the
/// verifier needs (each call site rebuilds the aggregate nonce, mirroring the
/// verifier's own reconstruction).
private func muSigPartialSignature(
    for message: some ContiguousBytes,
    privateKey: P256K.Schnorr.PrivateKey,
    aggregate: P256K.MuSig.PublicKey
) throws -> P256K.Schnorr.PartialSignature {
    let nonce = try P256K.MuSig.Nonce.generate(
        secretKey: privateKey,
        publicKey: privateKey.publicKey,
        msg32: nil
    )
    let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
    return try privateKey.partialSignature(
        for: message,
        pubnonce: nonce.pubnonce,
        secureNonce: nonce.secnonce,
        publicNonceAggregate: aggregateNonce,
        publicKeyAggregate: aggregate
    )
}

/// Produces a partial signature the public signing API refuses to make: a
/// *non-participant's* signature under the session — the shape upstream's
/// `keyaggcoef` permits (it assigns a coefficient to any public key), so the
/// result verifies algebraically and only the participant gates reject it.
/// Built through the same public C calls a raw-libsecp256k1 attacker uses;
/// the helper re-verifies the signature under the session before returning so
/// callers know the rejection can only come from membership checks.
private func foreignMuSigPartialSignature(
    for message: some ContiguousBytes,
    signer: P256K.Schnorr.PrivateKey,
    keyAggregate: P256K.MuSig.PublicKey,
    publicNonceAggregate: P256K.MuSig.Nonce
) throws -> P256K.Schnorr.PartialSignature {
    let context = P256K.Context.rawRepresentation
    var session = secp256k1_musig_session()
    var cache = secp256k1_musig_keyagg_cache()
    var aggnonce = secp256k1_musig_aggnonce()
    var keypair = secp256k1_keypair()
    var partialSig = secp256k1_musig_partial_sig()
    var secnonce = secp256k1_musig_secnonce()
    var signature = [UInt8](repeating: 0, count: P256K.ByteLength.dimension)
    // `secp256k1_keypair` and the copied secnonce embed secret material —
    // scrub both after their last use, matching `partialSignature`'s cleanup.
    defer {
        Swift.withUnsafeMutableBytes(of: &keypair) { buffer in
            _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
        }
        Swift.withUnsafeMutableBytes(of: &secnonce) { buffer in
            _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
        }
    }

    let messageBytes = try message.exactMsg32Bytes
    keyAggregate.keyAggregationCache.copyToUnsafeMutableBytes(of: &cache.data)
    publicNonceAggregate.aggregatedNonce.copyToUnsafeMutableBytes(of: &aggnonce.data)

    // The stranger's nonce pair — never contributed to `publicNonceAggregate`.
    // `NonceResult.secnonce` is `let`, so its bytes are read out and bound
    // into a local struct for upstream to consume — the same shape the
    // vector driver uses for spec secnonces.
    let nonce = try P256K.MuSig.Nonce.generate(
        secretKey: signer, publicKey: signer.publicKey, msg32: nil
    )
    var secnonceBytes = nonce.secnonce.data.withUnsafeBytePointer { pointer in
        Array(UnsafeBufferPointer(start: pointer, count: MemoryLayout<secp256k1_musig_secnonce>.size))
    }
    defer {
        secnonceBytes.withUnsafeMutableBufferPointer { buffer in
            _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
        }
    }
    // Copy the array straight into the struct — no `Data` temporary (which
    // would be an unscrubbed secret-bearing heap copy).
    secnonceBytes.withUnsafeBufferPointer { source in
        _ = Swift.withUnsafeMutableBytes(of: &secnonce.data) { $0.copyBytes(from: source) }
    }

    try #require(secp256k1_musig_nonce_process(context, &session, &aggnonce, messageBytes, &cache).boolValue)
    let keypairCreated = signer.key.withUnsafeBytePointer { keyPtr in
        secp256k1_keypair_create(context, &keypair, keyPtr).boolValue
    }
    try #require(keypairCreated)
    try #require(
        secp256k1_musig_partial_sign(context, &partialSig, &secnonce, &keypair, &cache, &session).boolValue,
        "keyaggcoef must accept the non-participant key — the attack premise"
    )
    try #require(secp256k1_musig_partial_sig_serialize(context, &signature, &partialSig).boolValue)

    // Prove the partial is algebraically valid under this session — without
    // this check a broken harness could make the membership assertions below
    // pass for the wrong reason (a signature that simply fails to verify).
    var parsedSig = secp256k1_musig_partial_sig()
    var pubnonce = secp256k1_musig_pubnonce()
    var signerPublicKey = signer.publicKey.baseKey.rawRepresentation
    nonce.pubnonce.pubnonce.copyToUnsafeMutableBytes(of: &pubnonce.data)
    try #require(secp256k1_musig_partial_sig_parse(context, &parsedSig, signature).boolValue)
    try #require(
        secp256k1_musig_partial_sig_verify(context, &parsedSig, &pubnonce, &signerPublicKey, &cache, &session).boolValue,
        "foreign partial must verify algebraically — only the membership gate can reject it"
    )

    return try P256K.Schnorr.PartialSignature(
        dataRepresentation: signature,
        publicKey: signer.publicKey,
        nonce: nonce.pubnonce
    )
}

/// Session-provenance coverage: `MuSig.PublicKey.isValidSignature` verifies the
/// envelope's bundled identity against a session rebuilt from the caller's
/// declared (message, aggregate nonce) — and rejects contributions whose signer
/// is not a recorded participant.
struct MuSigPartialVerifyTestSuite {
    /// The partial verifier rebuilds the session locally from the caller's
    /// `publicNonceAggregate`, a 32-byte `for:` message, and the key aggregation
    /// cache — upstream's documented verifier flow — verifies the bundled
    /// identity against that session, and throws on a non-32-byte message.
    @Test("MuSig partial signature verification consults the declared message")
    func musigPartialSignatureVerifyConsultsMessage() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let message = Array(SHA256.hash(data: Data("partial verify".utf8)))
        let otherMessage = Array(SHA256.hash(data: Data("other".utf8)))

        let partial = try muSigPartialSignature(for: message, privateKey: privateKey, aggregate: aggregate)
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [partial.nonce])

        // Honest inputs verify — the rebuilt session matches what the signer
        // bound, and the bundled signer is the session's only participant.
        #expect(try aggregate.isValidSignature(
            partial,
            for: message,
            publicNonceAggregate: aggregateNonce
        ))

        // A signature produced over a DIFFERENT message must not verify for the
        // declared message. It verifies once the caller declares the message
        // actually signed.
        let otherPartial = try muSigPartialSignature(for: otherMessage, privateKey: privateKey, aggregate: aggregate)
        let otherAggregateNonce = try P256K.MuSig.Nonce(aggregating: [otherPartial.nonce])
        #expect(try aggregate.isValidSignature(
            otherPartial,
            for: message,
            publicNonceAggregate: otherAggregateNonce
        ) == false)
        #expect(try aggregate.isValidSignature(
            otherPartial,
            for: otherMessage,
            publicNonceAggregate: otherAggregateNonce
        ))

        // The message feeds `secp256k1_musig_nonce_process`'s fixed `msg32` — a
        // non-32-byte input throws like the package's other `msg32` gates.
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            _ = try aggregate.isValidSignature(
                partial,
                for: [UInt8](repeating: 0xAB, count: 38),
                publicNonceAggregate: aggregateNonce
            )
        }
    }

    /// A `PartialSignature` is a compound — signature bytes plus the signer's
    /// public key and public nonce — and the compound is dishonest when the
    /// bundled identity doesn't match what the signature was produced under.
    /// A non-participant identity fails the membership gate; a mismatched
    /// nonce fails cryptographic verification — both before the contribution
    /// can reach `aggregateSignatures`.
    @Test("MuSig partial signature verification rejects a mismatched envelope")
    func musigPartialSignatureVerifyRejectsMismatchedEnvelope() throws {
        let privateKey = try P256K.Schnorr.PrivateKey()
        let stranger = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([privateKey.publicKey])
        let message = Array(SHA256.hash(data: Data("mismatched envelope".utf8)))

        let partial = try muSigPartialSignature(for: message, privateKey: privateKey, aggregate: aggregate)
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [partial.nonce])
        let otherPartial = try muSigPartialSignature(for: message, privateKey: privateKey, aggregate: aggregate)
        let otherAggregateNonce = try P256K.MuSig.Nonce(aggregating: [otherPartial.nonce])

        // A stranger's partial that is *algebraically valid for this session*
        // — produced through the same C calls a raw-libsecp256k1 attacker
        // uses — proves the membership gate, not `partial_sig_verify`, is what
        // rejects a non-participant: the helper asserts the signature verifies
        // before handing it back.
        let foreignSigner = try foreignMuSigPartialSignature(
            for: message,
            signer: stranger,
            keyAggregate: aggregate,
            publicNonceAggregate: aggregateNonce
        )
        #expect(try aggregate.isValidSignature(
            foreignSigner,
            for: message,
            publicNonceAggregate: aggregateNonce
        ) == false)

        // A member key bundled with a different nonce pair fails cryptographic
        // verification: the signature was bound to the envelope's session, not
        // this one.
        let mismatchedNonce = try P256K.Schnorr.PartialSignature(
            dataRepresentation: partial.dataRepresentation,
            publicKey: privateKey.publicKey,
            nonce: otherPartial.nonce
        )
        #expect(try aggregate.isValidSignature(
            mismatchedNonce,
            for: message,
            publicNonceAggregate: aggregateNonce
        ) == false)

        // The declared aggregate nonce drives the rebuilt session — the honest
        // signature declared under a different session fails too.
        #expect(try aggregate.isValidSignature(
            partial,
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
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
        let partial = try privateKey.partialSignature(
            for: message,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            xonlyKeyAggregate: tweakedXonly
        )

        // Verifying through the tweaked cache rebuilds the tweaked session —
        // the bundled identity is a participant and the signature verifies.
        #expect(try tweakedAggregate.isValidSignature(
            partial,
            for: message,
            publicNonceAggregate: aggregateNonce
        ))

        // The untweaked aggregate rebuilds a different session — the bundled
        // signature can't verify under it even though the signature itself is
        // honest.
        #expect(try aggregate.isValidSignature(
            partial,
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
