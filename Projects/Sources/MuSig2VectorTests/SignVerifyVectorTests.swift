//
//  SignVerifyVectorTests.swift
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

/// BIP-0327 Sign/Verify test vectors
///
/// Every case in the official file is either executed or skipped with a stated
/// reason, following the `NonceGenVectorTests` pattern. Coverage notes:
/// - Valid cases sign via the real `partialSignature` → partial-verify path —
///   the vector's 97-byte spec secret nonce is materialized into the internal
///   132-byte `secp256k1_musig_secnonce` layout that `NonceGenVectorTests.swift`
///   documents (magic ‖ k1 ‖ k2 ‖ parsed-pubkey storage).
/// - BIP-327 allows variable-length messages, but `secp256k1_musig_nonce_process`
///   binds a fixed `msg32`, so the empty and 38-byte valid cases stated-skip.
/// - Error cases whose offending input is malformed are rejected where the
///   wrapper constructs it — `Schnorr.PublicKey.init`, `MuSig.Nonce.init`,
///   `Schnorr.Nonce.init`, `PartialSignature.init` — the same pipeline stage
///   upstream's C driver attributes the error to, one API boundary earlier.
/// - The zeroed-secnonce sign-error case reaches an upstream `ARG_CHECK` that
///   terminates the process under the shared context; it is verified by porting
///   upstream's own `CHECK_ILLEGAL` mechanism onto a private context.
@Suite("BIP-0327 Sign/Verify")
struct SignVerifyVectorTests {
    /// Loaded test vectors
    let vectors: SignVerifyVectors

    /// The signer's private key — `pubkeys[0]`, per the vector's own cross-check.
    let secretKey: P256K.Schnorr.PrivateKey

    init() throws {
        let loader = TestVectorLoader<SignVerifyVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "sign_verify_vectors")
        self.secretKey = try P256K.Schnorr.PrivateKey(dataRepresentation: vectors.sk.bytes)
    }

    /// The secp256k1 group order n — a scalar at or above it fails upstream's
    /// `partial_sig_parse` (`scalar_set_b32`'s overflow check).
    private static let groupOrder: [UInt8] = [
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
        0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
        0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
    ]

    @Test("Vectors file loads with the full official counts")
    func vectorsLoadCorrectly() throws {
        #expect(vectors.pubkeys.count == 4, "Should have 4 public keys")
        #expect(vectors.secnonces.count == 2, "Should have 2 secret nonces")
        #expect(vectors.pnonces.count == 5, "Should have 5 public nonces")
        #expect(vectors.aggnonces.count == 5, "Should have 5 aggregated nonces")
        #expect(vectors.msgs.count == 3, "Should have 3 messages")
        #expect(vectors.valid_test_cases.count == 6, "Should have 6 valid test cases")
        #expect(vectors.sign_error_test_cases.count == 6, "Should have 6 sign error cases")
        #expect(vectors.verify_fail_test_cases.count == 3, "Should have 3 verify fail cases")
        #expect(vectors.verify_error_test_cases.count == 2, "Should have 2 verify error cases")

        // The suite presupposes `sk` derives `pubkeys[0]` — the membership
        // skip, the forged secnonce's signer binding, and `keypair_create` all
        // rely on it. Compare the parsed-key storage, not a serialization, so
        // the assertion is independent of encoding format.
        var derivedStorage = secretKey.publicKey.baseKey.rawRepresentation
        var vectorStorage = try publicKey(at: 0).baseKey.rawRepresentation
        #expect(
            Swift.withUnsafeBytes(of: &derivedStorage) { Array($0) }
                == Swift.withUnsafeBytes(of: &vectorStorage) { Array($0) },
            "sk must derive pubkeys[0]"
        )
    }

    @Test("Valid sign/verify cases execute end to end")
    func validCases() throws {
        var verified = 0
        var skipped: [String] = []

        for (index, testCase) in vectors.valid_test_cases.enumerated() {
            if let reason = validSkipReason(for: testCase, index: index) {
                skipped.append(reason)
                continue
            }
            try verifyValidCase(testCase)
            verified += 1
        }

        #expect(verified == 4, "4 of 6 valid cases carry a 32-byte message and execute")
        #expect(
            skipped.count == 2,
            "Skipped cases with stated reasons: \(skipped.joined(separator: " — "))"
        )
    }

    @Test("Sign error cases reject the offending contribution")
    func signErrorCases() throws {
        var verified = 0
        var skipped: [String] = []

        for (index, testCase) in vectors.sign_error_test_cases.enumerated() {
            if let reason = signErrorSkipReason(for: testCase, index: index) {
                skipped.append(reason)
                continue
            }
            try verifySignErrorCase(testCase)
            verified += 1
        }

        #expect(verified == 5, "5 of 6 sign error cases assert rejection")
        #expect(
            skipped.count == 1,
            "Skipped cases with stated reasons: \(skipped.joined(separator: " — "))"
        )
    }

    @Test("Verify fail cases return false")
    func verifyFailCases() throws {
        // The vector's cases share session inputs; the harvested session is a
        // pure function of them, so cache by inputs and sign once per distinct
        // session rather than once per case.
        var sessions: [String: Data] = [:]

        for (index, testCase) in vectors.verify_fail_test_cases.enumerated() {
            let sessionKey = "\(testCase.key_indices)|\(testCase.nonce_indices)|\(testCase.msg_index)"
            let session: Data
            if let cached = sessions[sessionKey] {
                session = cached
            } else {
                // The session the vector's signature was produced under —
                // built the way a real signer would carry it (see `sessionBytes`).
                session = try sessionBytes(
                    keyIndices: testCase.key_indices,
                    nonceIndices: testCase.nonce_indices,
                    msgIndex: testCase.msg_index
                )
                sessions[sessionKey] = session
            }
            try verifyFailCase(testCase, index: index, session: session)
        }
    }

    @Test("Verify error cases reject the offending contribution")
    func verifyErrorCases() throws {
        for (index, testCase) in vectors.verify_error_test_cases.enumerated() {
            try verifyErrorCase(testCase, index: index)
        }
    }

    /// BIP-327 permits variable-length messages, but libsecp256k1's MuSig API
    /// reads a fixed 32-byte `msg32` at nonce generation and session binding —
    /// the vector file's empty (`msgs[1]`) and 38-byte (`msgs[2]`) payloads must
    /// throw on the signing inputs rather than silently commit to the first 32
    /// bytes. This probe pins the exact behavior the stated skips cite.
    @Test("Non-32-byte vector messages throw on the signing inputs")
    func nonMsg32VectorMessagesThrow() throws {
        let signer = try P256K.Schnorr.PrivateKey()
        let aggregate = try P256K.MuSig.aggregate([signer.publicKey])
        // `msgs[1]` is the BIP-327 empty message — `String.bytes` (the strict
        // hex decoder) rejects an empty string, so decode it as `[]` directly.
        let messages = try vectors.msgs.map { $0.isEmpty ? [] : try $0.bytes }

        // The probes below are only meaningful if the fixture actually carries
        // both shapes — pin that expectation so a future vector edit can't
        // silently vacate either loop.
        #expect(messages.contains { $0.count == P256K.ByteLength.dimension }, "fixture must carry a 32-byte message")
        #expect(messages.contains { $0.count != P256K.ByteLength.dimension }, "fixture must carry a non-32-byte message")

        for message in messages where message.count == P256K.ByteLength.dimension {
            // Expressible — both signing inputs accept the 32-byte message.
            let nonce = try P256K.MuSig.Nonce.generate(
                secretKey: signer,
                publicKey: signer.publicKey,
                msg32: message
            )
            let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
            _ = try signer.partialSignature(
                for: message,
                pubnonce: nonce.pubnonce,
                secureNonce: nonce.secnonce,
                publicNonceAggregate: aggregateNonce,
                publicKeyAggregate: aggregate
            )
        }

        for message in messages where message.count != P256K.ByteLength.dimension {
            #expect(throws: secp256k1Error.incorrectParameterSize) {
                _ = try P256K.MuSig.Nonce.generate(
                    secretKey: signer,
                    publicKey: signer.publicKey,
                    msg32: message
                )
            }

            // `partialSignature` consumes the nonce it receives — a fresh one
            // per probe, so this checks the thrown error explicitly.
            do {
                let nonce = try P256K.MuSig.Nonce.generate(
                    secretKey: signer,
                    publicKey: signer.publicKey,
                    msg32: nil
                )
                let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [nonce.pubnonce])
                _ = try signer.partialSignature(
                    for: message,
                    pubnonce: nonce.pubnonce,
                    secureNonce: nonce.secnonce,
                    publicNonceAggregate: aggregateNonce,
                    publicKeyAggregate: aggregate
                )
                Issue.record("partialSignature must reject a \(message.count)-byte message")
            } catch {
                #expect(error as? secp256k1Error == .incorrectParameterSize)
            }
        }
    }

    // MARK: - Valid case driver

    /// Returns the stated skip reason for a valid case the wrapper cannot
    /// express, or `nil` when the case is expressible.
    private func validSkipReason(for testCase: SignVerifyValidCase, index: Int) -> String? {
        let messageByteCount = vectors.msgs[testCase.msg_index].count / 2
        guard messageByteCount == P256K.ByteLength.dimension else {
            return "case \(index + 1) (\(messageByteCount)-byte message): not representable in msg32 — `secp256k1_musig_nonce_process` binds a fixed 32-byte message (unsupported by libsecp256k1)"
        }
        return nil
    }

    /// Executes one valid case: ordered key aggregation, declared aggregate
    /// nonce, materialized spec secnonce, `partialSignature` byte-compared to
    /// `expected`, then partial verification through the aggregate key.
    private func verifyValidCase(_ testCase: SignVerifyValidCase) throws {
        let keyList = try testCase.key_indices.map { try publicKey(at: $0) }
        let aggregate = try P256K.MuSig.aggregate(keyList)
        let pubnonces = try testCase.nonce_indices.map { try publicNonce(at: $0) }
        let aggregateNonce = try P256K.MuSig.Nonce(dataRepresentation: vectors.aggnonces[testCase.aggnonce_index].bytes)
        let message = try vectors.msgs[testCase.msg_index].bytes
        // `signer_index` is a position inside `key_indices`/`nonce_indices`, so
        // the signer's key and nonce are selected from the case's lists.
        let signerPublicKey = keyList[testCase.signer_index]
        let signerPubnonce = pubnonces[testCase.signer_index]

        // Upstream asserts `nonce_agg(pubnonces) == aggnonce` — pin the same
        // consistency between the declared and reconstructed aggregate nonces.
        #expect(
            try P256K.MuSig.Nonce(aggregating: pubnonces).dataRepresentation == aggregateNonce.dataRepresentation,
            "aggregated pubnonces must equal the declared aggnonce"
        )

        // The vector's only spec secnonce (`secnonces[0]`) is bound to
        // `pubkeys[0]` — the signer in every expressible case.
        let partial = try secretKey.partialSignature(
            for: message,
            pubnonce: signerPubnonce,
            secureNonce: secureNonce(secnonceIndex: 0, publicKey: signerPublicKey),
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        #expect(
            try Array(partial.dataRepresentation) == testCase.expected.bytes,
            "partial signature must equal the vector's expected signature"
        )
        #expect(
            try aggregate.isValidSignature(
                partial,
                publicKey: signerPublicKey,
                nonce: signerPubnonce,
                for: message,
                publicNonceAggregate: aggregateNonce
            ),
            "partial signature must verify under the aggregate key"
        )
    }

    // MARK: - Sign error driver

    /// Returns the stated skip reason for a sign-error case, or `nil` when the
    /// case's expected rejection is assertable.
    private func signErrorSkipReason(for testCase: SignVerifyErrorCase, index: Int) -> String? {
        // The vector's own comment marks the signer-membership check optional,
        // and upstream's C driver skips the case identically: this wrapper does
        // not check that the signer's public key is in the list either — the
        // call succeeds (producing a wrong signature) rather than erroring, so
        // there is no rejection to assert. The structural marker is the case's
        // own semantics: the signer's pubkey — `pubkeys[0]`, the public key of
        // `sk` — is absent from `key_indices`. (No prose matching on the error
        // message; `signer_index` is no marker either — the invalid-
        // contribution cases omit it too.)
        if !testCase.key_indices.contains(0) {
            return "case \(index + 1): optional signer-membership check — the vector marks it skippable and neither upstream's driver nor this API performs it, so no error exists to assert"
        }
        return nil
    }

    /// Asserts a sign-error case's expected rejection, dispatched by the
    /// contribution the vector attributes the error to.
    private func verifySignErrorCase(_ testCase: SignVerifyErrorCase) throws {
        switch testCase.error.contrib {
        case "pubkey":
            // `key_agg` stage — an invalid public key must fail `Schnorr.PublicKey.init`.
            #expect(throws: secp256k1Error.underlyingCryptoError) {
                _ = try testCase.key_indices.map { try publicKey(at: $0) }
            }
        case "aggnonce":
            // `nonce_process` stage — a malformed aggregate nonce must fail
            // `MuSig.Nonce.init`.
            #expect(throws: secp256k1Error.underlyingCryptoError) {
                _ = try P256K.MuSig.Nonce(dataRepresentation: vectors.aggnonces[testCase.aggnonce_index].bytes)
            }
        default:
            // Only the zeroed-secnonce case takes the C-level `ARG_CHECK`
            // path — a `type:"value"` error attributing nothing, bound to
            // `secnonces[1]` (the entry with zeroed scalar halves). Anything
            // else landing here is a misrouted vector, not a driver call.
            guard testCase.error.type == "value", testCase.secnonce_index == 1 else {
                Issue.record(
                    "sign_error case routed to the consumed-nonce driver unexpectedly (contrib: \(testCase.error.contrib ?? "nil"))"
                )
                return
            }
            try assertConsumedNonceRejected(testCase)
        }
    }

    /// Ports upstream's `CHECK_ILLEGAL(CTX, secp256k1_musig_partial_sign(...))`
    /// for the zeroed-secnonce case. Under the shared `P256K.Context`, the
    /// `ARG_CHECK` on a zero-scalar secnonce routes to `fatalError` — a
    /// deliberate fail-stop, not a catchable error. A private context with a
    /// counting illegal-argument callback captures the same rejection upstream
    /// asserts: the callback fires exactly once and signing refuses (returns 0).
    private func assertConsumedNonceRejected(_ testCase: SignVerifyErrorCase) throws {
        var illegalCalls = Int32(0)
        let context = try #require(secp256k1_context_create(UInt32(SECP256K1_CONTEXT_NONE)))
        defer { secp256k1_context_destroy(context) }

        var session = secp256k1_musig_session()
        var keypair = secp256k1_keypair()
        var secnonce = secp256k1_musig_secnonce()
        var partialSignature = secp256k1_musig_partial_sig()
        // The forged secnonce and keypair hold secret scalars in plain stack
        // memory — scrub both after use, matching `partialSignature`'s cleanup.
        defer {
            Swift.withUnsafeMutableBytes(of: &secnonce) { buffer in
                _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
            }
            Swift.withUnsafeMutableBytes(of: &keypair) { buffer in
                _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
            }
        }

        // Build the session inputs through the same public C calls the wrapper
        // uses — every case arriving here has valid keys and aggnonce.
        let publicKeyBytes = try testCase.key_indices.map { try vectors.pubkeys[$0].bytes }
        let pubkeys = publicKeyBytes.map { bytes -> secp256k1_pubkey in
            var pubkey = secp256k1_pubkey()
            #expect(secp256k1_ec_pubkey_parse(context, &pubkey, bytes, bytes.count).boolValue)
            return pubkey
        }
        var cache = secp256k1_musig_keyagg_cache()
        PointerArrayUtility.withUnsafePointerArray(pubkeys) { pointers in
            #expect(secp256k1_musig_pubkey_agg(context, nil, &cache, pointers, pointers.count).boolValue)
        }
        var aggregateNonce = secp256k1_musig_aggnonce()
        let aggregateNonceBytes = try vectors.aggnonces[testCase.aggnonce_index].bytes
        #expect(secp256k1_musig_aggnonce_parse(context, &aggregateNonce, aggregateNonceBytes).boolValue)
        let message = try vectors.msgs[testCase.msg_index].bytes
        #expect(secp256k1_musig_nonce_process(context, &session, &aggregateNonce, message, &cache).boolValue)

        let secretKeyBytes = try vectors.sk.bytes
        #expect(secp256k1_keypair_create(context, &keypair, secretKeyBytes).boolValue)

        // Write the forged 132-byte blob into the opaque struct — magic,
        // zeroed k1‖k2 scalars, and the signer's parsed-pubkey storage.
        let secnonceIndex = try #require(
            testCase.secnonce_index,
            "consumed-nonce case must specify secnonce_index"
        )
        try Data(secureNonceBlob(secnonceIndex: secnonceIndex, publicKey: secretKey.publicKey))
            .copyToUnsafeMutableBytes(of: &secnonce.data)

        // The callback's `data` pointer must outlive the call that stores it:
        // `secp256k1_context_set_illegal_callback` keeps it inside the context
        // and `partial_sign` dereferences it when `ARG_CHECK` fires, so
        // everything that can trigger the callback runs inside the inout
        // scope. Read back through `counter.pointee` — `illegalCalls` itself is
        // under an exclusive inout access for the closure's duration.
        withUnsafeMutablePointer(to: &illegalCalls) { counter in
            secp256k1_context_set_illegal_callback(context, { _, data in
                data?.assumingMemoryBound(to: Int32.self).pointee += 1
            }, UnsafeMutableRawPointer(counter))
            let signed = secp256k1_musig_partial_sign(context, &partialSignature, &secnonce, &keypair, &cache, &session)
            #expect(signed == 0, "partial_sign must refuse a zero-scalar secnonce")
            #expect(counter.pointee == 1, "the illegal-argument callback must fire exactly once")
        }
    }

    // MARK: - Verify drivers

    /// Asserts a verify-fail case's outcome: if the 32-byte signature scalar is
    /// malformed it is rejected inside `PartialSignature.init` (upstream's
    /// `partial_sig_parse` stage); otherwise the verifier must return `false`.
    /// Asserts a verify-fail case's outcome: an in-range scalar must return
    /// `false` from the verifier; an out-of-range scalar is rejected inside
    /// `PartialSignature.init` (upstream's `partial_sig_parse` stage). Which
    /// outcome a case expects is decided structurally — comparing the scalar
    /// against the group order — never by which call happens to throw, so an
    /// unexpected throw propagates and fails the test instead of passing
    /// inside a catch.
    private func verifyFailCase(_ testCase: VerifyFailCase, index: Int, session: Data) throws {
        let keyList = try testCase.key_indices.map { try publicKey(at: $0) }
        let aggregate = try P256K.MuSig.aggregate(keyList)
        let pubnonces = try testCase.nonce_indices.map { try publicNonce(at: $0) }
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: pubnonces)
        let message = try vectors.msgs[testCase.msg_index].bytes
        let signatureBytes = try #require(
            try testCase.sig.bytes,
            "verify_fail sig must decode to bytes"
        )
        try #require(signatureBytes.count == 32, "verify_fail sig must be a 32-byte scalar")

        if signatureBytes.lexicographicallyPrecedes(Self.groupOrder) {
            let partial = try P256K.Schnorr.PartialSignature(
                dataRepresentation: signatureBytes,
                session: session
            )
            let verified = try aggregate.isValidSignature(
                partial,
                publicKey: keyList[testCase.signer_index],
                nonce: pubnonces[testCase.signer_index],
                for: message,
                publicNonceAggregate: aggregateNonce
            )
            #expect(verified == false, "case \(index + 1) must fail verification — \(testCase.comment ?? "")")
        } else {
            #expect(throws: secp256k1Error.underlyingCryptoError) {
                _ = try P256K.Schnorr.PartialSignature(
                    dataRepresentation: signatureBytes,
                    session: session
                )
            }
        }
    }

    /// Asserts a verify-error case's expected rejection at the construction
    /// stage matching the contribution the vector attributes it to.
    private func verifyErrorCase(_ testCase: VerifyErrorCase, index: Int) throws {
        switch testCase.error.contrib {
        case "pubkey":
            // `key_agg` stage — the key list contains an invalid public key.
            #expect(throws: secp256k1Error.underlyingCryptoError) {
                _ = try testCase.key_indices.map { try publicKey(at: $0) }
            }
        case "pubnonce":
            // `pubnonce_parse` stage — the signer's public nonce is malformed;
            // upstream's driver parses only the declared signer's nonce.
            #expect(throws: secp256k1Error.underlyingCryptoError) {
                _ = try publicNonce(at: testCase.nonce_indices[testCase.signer_index])
            }
        default:
            Issue.record("verify_error case \(index + 1): unhandled contrib \(testCase.error.contrib ?? "nil")")
        }
    }

    // MARK: - Fixture helpers

    /// The vector's public key at `pubkeys[index]` — throws
    /// `underlyingCryptoError` for the malformed entries the error cases carry.
    private func publicKey(at index: Int) throws -> P256K.Schnorr.PublicKey {
        try P256K.Schnorr.PublicKey(
            dataRepresentation: vectors.pubkeys[index].bytes,
            format: .compressed
        )
    }

    /// The vector's public nonce at `pnonces[index]` — throws
    /// `underlyingCryptoError` for the malformed entries the error cases carry.
    private func publicNonce(at index: Int) throws -> P256K.Schnorr.Nonce {
        try P256K.Schnorr.Nonce(dataRepresentation: vectors.pnonces[index].bytes)
    }

    /// The 132-byte `secp256k1_musig_secnonce` for a 97-byte BIP-327 spec
    /// secret nonce — the exact bytes upstream's own vector harness builds in
    /// `musig_test_set_secnonce` (`tests_impl.h`): the 4-byte magic, then
    /// k1‖k2 verbatim (upstream stores canonical scalar encodings), then the
    /// 64-byte `ge_to_bytes` parsed-pubkey storage — the same encoding
    /// `secp256k1_pubkey` carries, exposed through `baseKey.rawRepresentation`.
    /// Upstream binds the signer's own public key here, not the vector's
    /// embedded pubkey field.
    private func secureNonceBlob(secnonceIndex: Int, publicKey: P256K.Schnorr.PublicKey) throws -> [UInt8] {
        let spec = try vectors.secnonces[secnonceIndex].bytes
        try #require(spec.count == 97, "spec secnonce must be 97 bytes (k1‖k2‖compressed pubkey)")
        // `secp256k1_musig_secnonce_magic` — vendored session_impl.h.
        let magic: [UInt8] = [0x22, 0x0E, 0xDC, 0xF1]
        let publicKeyStorage = Swift.withUnsafeBytes(of: publicKey.baseKey.rawRepresentation) { [UInt8]($0) }
        let blob = magic + Array(spec[0..<64]) + publicKeyStorage
        // `copyToUnsafeMutableBytes` truncates silently — pin the full struct
        // size here so a drifted pubkey encoding fails as a test precondition
        // rather than inside libsecp256k1's `fe_equal` ARG_CHECK (a process
        // abort under the shared context).
        try #require(blob.count == MemoryLayout<secp256k1_musig_secnonce>.size)
        return blob
    }

    /// Materializes a spec secret nonce as a consumable ``SecureNonce``.
    private func secureNonce(secnonceIndex: Int, publicKey: P256K.Schnorr.PublicKey) throws -> P256K.Schnorr.SecureNonce {
        try P256K.Schnorr.SecureNonce(
            SecureBytes(bytes: secureNonceBlob(secnonceIndex: secnonceIndex, publicKey: publicKey)),
            publicKey: publicKey
        )
    }

    /// Produces the 133-byte `secp256k1_musig_session` a real signer would carry
    /// for the given session inputs. The session binds `(aggregate nonce,
    /// msg32, key-aggregation cache)` only — the signer is irrelevant — so
    /// signing once as the vector's secret key and reading the carried
    /// ``PartialSignature/session`` yields byte-for-byte the session the
    /// post-T028 verifier rebuilds.
    private func sessionBytes(keyIndices: [Int], nonceIndices: [Int], msgIndex: Int) throws -> Data {
        let aggregate = try P256K.MuSig.aggregate(keyIndices.map { try publicKey(at: $0) })
        let aggregateNonce = try P256K.MuSig.Nonce(aggregating: nonceIndices.map { try publicNonce(at: $0) })
        let message = try vectors.msgs[msgIndex].bytes
        let nonce = try P256K.MuSig.Nonce.generate(
            secretKey: secretKey,
            publicKey: secretKey.publicKey,
            msg32: message
        )
        // The produced signature is discarded — only the carried session is
        // harvested. `partialSignature` does not check that our public nonce
        // contributed to the declared aggregate nonce, so the sign itself is
        // well-formed even though the resulting signature is meaningless.
        let partial = try secretKey.partialSignature(
            for: message,
            pubnonce: nonce.pubnonce,
            secureNonce: nonce.secnonce,
            publicNonceAggregate: aggregateNonce,
            publicKeyAggregate: aggregate
        )
        return partial.session
    }
}
