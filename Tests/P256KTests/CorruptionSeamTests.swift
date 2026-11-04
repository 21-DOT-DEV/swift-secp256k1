//
//  CorruptionSeamTests.swift
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

/// Marker prefix the canned invariant handler writes to stderr inside the exit
/// test's child process so the parent can confirm the corrupt → invariant
/// pipeline fired — the same observable-channel technique `InvariantTests`
/// uses for `P256K.invariantFailure`.
private let kCorruptionMarker: String = "CORRUPTION OBSERVED"

/// Marker the inert-arm corruptor writes to stderr to prove the signing
/// path actually consulted the seam — without it, a deleted consult would
/// leave the control arm passing vacuously.
private let kSeamConsultedMarker: String = "SEAM CONSULTED"

/// A corruptor recipe: XORs the produced byte at `index` with `mask`. The
/// fault model is a byte glitch — mutation in place with no layout knowledge
/// beyond an offset — mirroring what a real fault-injection attack does to
/// produced signature material.
private func flipByte(
    at index: Int,
    mask: UInt8 = 0xFF
) -> @Sendable (UnsafeMutableRawBufferPointer) -> Void {
    { bytes in bytes[index] ^= mask }
}

#if compiler(>=6.2) && (os(macOS) || os(Linux) || os(Windows) || os(FreeBSD) || os(OpenBSD))
    /// The fault-injection scenarios ``runCorruptionCase(_:)`` executes in an
    /// exit-test child process — gains one or more corruption arms plus an
    /// inert control per signing path as T009–T012 wire each path's seam
    /// consult (the recoverable path's artifact carries a recovery-ID byte
    /// with its own failure surface, hence three corruption arms).
    private enum CorruptionCase {
        /// Simulates the corrupt → self-verify → crash pipeline without a real
        /// signing path: corrupt produced bytes, detect the mutation, fire
        /// `invariantFailure`.
        case canned

        /// A real `P256K.Schnorr.PrivateKey.signature(message:)` call under a
        /// bound corruptor that flips the last byte of the signature's `s`
        /// half (bytes 32–63). An `s`-half mutation is mathematically
        /// guaranteed to fail `secp256k1_schnorrsig_verify` — the only curve
        /// point sharing `R`'s x coordinate is `-R`, which fails BIP-340's
        /// even-y requirement — so the child can only exit through the
        /// invariant channel.
        case schnorr

        /// Control arm: a bound corruptor that proves it was consulted —
        /// it writes a stderr marker — but mutates nothing. The child must
        /// still sign and exit cleanly: a bound seam can never
        /// false-positive the self-check.
        case schnorrInert

        /// A real `P256K.Signing.PrivateKey.signature(for:)` call under a
        /// bound corruptor that flips the last byte of the produced
        /// `secp256k1_ecdsa_signature` — inside the `s` scalar's half of
        /// the 64-byte opaque struct (`r` occupies data[0..32), `s`
        /// data[32..64)). For a fixed `r` the ECDSA equation admits only
        /// `s` and `n − s` as solutions; `n − s` fails
        /// `secp256k1_ecdsa_verify`'s lower-S requirement, an out-of-range
        /// result fails it the same way, and any other mutated `s` fails
        /// the curve equation — so the child can only exit through the
        /// invariant channel. The guarantee assumes no `-DVERIFY` upstream
        /// build define (none exists in the package today): under one, a
        /// corrupted `s` ≥ the curve order could abort inside scalar
        /// `VERIFY` checks instead, with a different stderr message.
        case ecdsa

        /// Control arm: a bound corruptor that proves it was consulted —
        /// it writes a stderr marker — but mutates nothing. The child must
        /// still sign and exit cleanly: a bound seam can never
        /// false-positive the self-check.
        case ecdsaInert

        /// A real `P256K.Recovery.PrivateKey.signature(for:)` call under a
        /// bound corruptor that flips the last byte of the produced
        /// `secp256k1_ecdsa_recoverable_signature`'s `s` half — the 65-byte
        /// struct is r ‖ s ‖ recovery ID. For a fixed `r` and recovery ID
        /// the recovered point is `r⁻¹(s·R − e·G)`, injective in `s`: a
        /// mutated `s′` either fails `secp256k1_ecdsa_recover` outright or
        /// recovers a different point that `secp256k1_ec_pubkey_cmp`
        /// rejects — so the child can only exit through the invariant
        /// channel. The guarantee assumes no `-DVERIFY` upstream build
        /// define (none exists in the package today): under one, a
        /// corrupted `s` ≥ the curve order could abort inside scalar
        /// `VERIFY` checks instead, with a different stderr message.
        case recovery

        /// A real `signature(for:)` call under a bound corruptor that flips
        /// the produced struct's recovery-ID byte (`data[64]`) with mask
        /// 0x01 — always a different *in-range* ID (0↔1, 2↔3), which selects
        /// a different nonce point and recovers a different public key, so
        /// the compare fails and the child exits through the invariant
        /// channel.
        case recoveryRecid

        /// A real `signature(for:)` call under a bound corruptor that flips
        /// the recovery-ID byte (`data[64]`) with mask 0x04 — always out of
        /// range (a produced 0–3 becomes 4–7). Inside the opaque struct the
        /// ID is masked `recid & 3` in non-VERIFY builds, so a struct-level
        /// self-check could alias it to a valid ID and recover the same
        /// key; the serialized wire form is verified instead, and its
        /// re-parse runs `parse_compact`'s `ARG_CHECK` — the child dies on
        /// upstream's argument check, not the compare path.
        case recoveryRecidOverflow

        /// Control arm: a bound corruptor that proves it was consulted —
        /// it writes a stderr marker — but mutates nothing. The child must
        /// still sign and exit cleanly: a bound seam can never
        /// false-positive the self-check.
        case recoveryInert
    }

    /// Executes one fault-injection scenario inside an exit-test child
    /// process.
    ///
    /// Exit-test bodies must be capture-free literal code under ST-0008, so
    /// the scenario reaches the child as a literal enum argument inside each
    /// test's `#expect` body — the `TestHelperProcess` env-var discriminator
    /// Go uses for death tests, translated to the only channel Swift Testing
    /// bodies allow.
    private func runCorruptionCase(_ path: CorruptionCase) throws {
        P256K.setInvariantViolationHandler { text in
            FileHandle.standardError.write(Data("\(kCorruptionMarker): \(text)".utf8))
        }
        switch path {
        case .canned:
            let produced: [UInt8] = [0x01, 0x02, 0x03, 0x04]
            var bytes = produced
            P256K.$signatureCorruptor.withValue(flipByte(at: 0)) {
                bytes.withUnsafeMutableBytes(P256K.corruptProducedSignature)
            }
            guard bytes != produced else {
                return
            }
            P256K.invariantFailure("corrupted produced signature")

        case .schnorr:
            let privateKey: P256K.Schnorr.PrivateKey = try P256K.Schnorr.PrivateKey()
            let message: [UInt8] = .init(repeating: 0xAB, count: 32)
            try P256K.$signatureCorruptor.withValue(flipByte(at: 63)) {
                _ = try privateKey.signature(message: message)
            }

        case .schnorrInert:
            let privateKey: P256K.Schnorr.PrivateKey = try P256K.Schnorr.PrivateKey()
            let message: [UInt8] = .init(repeating: 0xAB, count: 32)
            let consulted: @Sendable (UnsafeMutableRawBufferPointer) -> Void = { _ in
                FileHandle.standardError.write(Data("\(kSeamConsultedMarker)".utf8))
            }
            try P256K.$signatureCorruptor.withValue(consulted) {
                _ = try privateKey.signature(message: message)
            }

        case .ecdsa:
            let privateKey = try P256K.Signing.PrivateKey()
            let digest = SHA256.hash(data: [UInt8](repeating: 0xAB, count: 32))
            P256K.$signatureCorruptor.withValue(flipByte(at: 63)) {
                _ = privateKey.signature(for: digest)
            }

        case .ecdsaInert:
            let privateKey = try P256K.Signing.PrivateKey()
            let digest = SHA256.hash(data: [UInt8](repeating: 0xAB, count: 32))
            let consulted: @Sendable (UnsafeMutableRawBufferPointer) -> Void = { _ in
                FileHandle.standardError.write(Data("\(kSeamConsultedMarker)".utf8))
            }
            P256K.$signatureCorruptor.withValue(consulted) {
                _ = privateKey.signature(for: digest)
            }

        case .recovery:
            let privateKey = try P256K.Recovery.PrivateKey()
            let digest = SHA256.hash(data: [UInt8](repeating: 0xAB, count: 32))
            P256K.$signatureCorruptor.withValue(flipByte(at: 63)) {
                _ = privateKey.signature(for: digest)
            }

        case .recoveryRecid:
            let privateKey = try P256K.Recovery.PrivateKey()
            let digest = SHA256.hash(data: [UInt8](repeating: 0xAB, count: 32))
            P256K.$signatureCorruptor.withValue(flipByte(at: 64, mask: 0x01)) {
                _ = privateKey.signature(for: digest)
            }

        case .recoveryRecidOverflow:
            let privateKey = try P256K.Recovery.PrivateKey()
            let digest = SHA256.hash(data: [UInt8](repeating: 0xAB, count: 32))
            P256K.$signatureCorruptor.withValue(flipByte(at: 64, mask: 0x04)) {
                _ = privateKey.signature(for: digest)
            }

        case .recoveryInert:
            let privateKey = try P256K.Recovery.PrivateKey()
            let digest = SHA256.hash(data: [UInt8](repeating: 0xAB, count: 32))
            let consulted: @Sendable (UnsafeMutableRawBufferPointer) -> Void = { _ in
                FileHandle.standardError.write(Data("\(kSeamConsultedMarker)".utf8))
            }
            P256K.$signatureCorruptor.withValue(consulted) {
                _ = privateKey.signature(for: digest)
            }
        }
    }

    /// The shared parent half of every fault-injection exit test: the child
    /// died (a `.failure` exit test returns a non-nil result) and its stderr
    /// carries the marker proving the invariant handler ran before the
    /// process terminated.
    private func expectCrashReport(_ result: ExitTest.Result?, contains substring: String) {
        let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
        #expect(stderr.contains("\(kCorruptionMarker): \(substring)"))
    }
#endif

struct CorruptionSeamTestSuite {
    /// The production case: no corruptor bound, so consulting the seam leaves
    /// produced bytes untouched.
    @Test("Unbound seam leaves produced bytes untouched")
    func unboundConsultIsNoOp() {
        let produced: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        var bytes = produced
        bytes.withUnsafeMutableBytes(P256K.corruptProducedSignature)
        #expect(bytes == produced)
    }

    /// A bound corruptor mutates the produced bytes in place — the fault the
    /// verify-after-sign self-checks exist to catch.
    @Test("Bound corruptor mutates produced bytes")
    func boundCorruptorMutatesBytes() {
        var bytes: [UInt8] = [0x00, 0x01, 0x02, 0x03]
        P256K.$signatureCorruptor.withValue(flipByte(at: 1)) {
            bytes.withUnsafeMutableBytes(P256K.corruptProducedSignature)
        }
        #expect(bytes == [0x00, 0xFE, 0x02, 0x03])
        #expect(P256K.signatureCorruptor == nil)
    }

    /// An inner `withValue` shadows the outer binding for its scope only;
    /// leaving the scope restores the outer — the task-local analogue of
    /// upstream libsecp256k1's set / run / restore counting-callback pattern.
    @Test("Inner binding shadows the outer for its scope only")
    func nestedBindingShadowsThenRestores() {
        var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00]
        P256K.$signatureCorruptor.withValue(flipByte(at: 0, mask: 0x01)) {
            P256K.$signatureCorruptor.withValue(flipByte(at: 2, mask: 0x02)) {
                bytes.withUnsafeMutableBytes(P256K.corruptProducedSignature)
            }
            bytes.withUnsafeMutableBytes(P256K.corruptProducedSignature)
        }
        #expect(bytes == [0x01, 0x00, 0x02, 0x00])
    }

    /// The binding is task-local, not global: a detached task — which does not
    /// inherit task-local values — inside the bound scope sees the unbound
    /// default, so a corruptor can never leak into an unrelated test.
    @Test("Binding does not cross task boundaries")
    func bindingDoesNotCrossTaskBoundaries() async {
        let detachedBytes = await P256K.$signatureCorruptor.withValue(flipByte(at: 0)) {
            await Task.detached {
                var bytes: [UInt8] = [0xAA]
                bytes.withUnsafeMutableBytes(P256K.corruptProducedSignature)
                return bytes
            }.value
        }
        #expect(detachedBytes == [0xAA])
    }

    // Exit tests require Swift 6.2 (`#expect(processExitsWith:)` — ST-0008)
    // and are unavailable on iOS/tvOS/watchOS/visionOS; the in-process seam
    // tests above stay unguarded so those platforms still exercise the seam.
    #if compiler(>=6.2) && (os(macOS) || os(Linux) || os(Windows) || os(FreeBSD) || os(OpenBSD))
        /// Proves the whole pipeline in one child process before any signing
        /// path consults the seam: bind → consult → mutation observed →
        /// `invariantFailure`. If the corruptor failed to fire, the child
        /// exits cleanly and `.failure` is not observed.
        @Test("Corrupted produced signature terminates via the invariant channel")
        func cannedCorruptionTerminates() async {
            let result = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.canned)
            }
            expectCrashReport(result, contains: "corrupted produced signature")
        }

        /// The real pipeline on the Schnorr signing path (T009): the bound
        /// corruptor mutates the produced signature between `sign_custom`
        /// and the self-check, the mutation is guaranteed-invalid, and the
        /// only remaining exit is `invariantFailure`. If the consult never
        /// reached the signing path, the child would sign cleanly and
        /// `.failure` would go unobserved.
        @Test("Corrupted Schnorr signature terminates via the invariant channel")
        func schnorrCorruptionTerminates() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.schnorr)
            }
            expectCrashReport(result, contains: "produced Schnorr signature failed verification against xonly")
        }

        /// Control arm: a bound corruptor that mutates nothing must not
        /// false-positive the self-check — the child signs successfully and
        /// exits cleanly — and the stderr marker proves the signing path
        /// actually consulted the seam (a deleted consult fails this arm
        /// outright rather than passing vacuously).
        @Test("Bound-but-inert corruptor lets Schnorr signing complete")
        func schnorrInertCorruptorSigns() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .success,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.schnorrInert)
            }
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains(kSeamConsultedMarker))
        }

        /// The real pipeline on the ECDSA signing path (T010): the bound
        /// corruptor mutates the produced `secp256k1_ecdsa_signature`
        /// struct between `secp256k1_ecdsa_sign` and the self-check — a
        /// mutation guaranteed-invalid by the lower-S/curve-equation
        /// argument on `.ecdsa` — and the only remaining exit is
        /// `invariantFailure`. If the consult never reached the signing
        /// path, the child would sign cleanly and `.failure` would go
        /// unobserved.
        @Test("Corrupted ECDSA signature terminates via the invariant channel")
        func ecdsaCorruptionTerminates() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.ecdsa)
            }
            expectCrashReport(result, contains: "produced ECDSA signature failed verification against public key")
        }

        /// Control arm: a bound corruptor that mutates nothing must not
        /// false-positive the self-check — the child signs successfully and
        /// exits cleanly — and the stderr marker proves the signing path
        /// actually consulted the seam (a deleted consult fails this arm
        /// outright rather than passing vacuously).
        @Test("Bound-but-inert corruptor lets ECDSA signing complete")
        func ecdsaInertCorruptorSigns() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .success,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.ecdsaInert)
            }
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains(kSeamConsultedMarker))
        }

        /// The real pipeline on the recoverable-ECDSA signing path (T011):
        /// the bound corruptor mutates the `s` half of the produced
        /// `secp256k1_ecdsa_recoverable_signature` between
        /// `secp256k1_ecdsa_sign_recoverable` and the self-check — for a
        /// fixed `r` and recovery ID the recovered point is injective in
        /// `s`, so the wire-form re-parse + recover + `ec_pubkey_cmp`
        /// self-check cannot pass — and the only remaining exit is
        /// `invariantFailure`. If the consult never reached the signing
        /// path, the child would sign cleanly and `.failure` would go
        /// unobserved.
        @Test("Corrupted recoverable signature terminates via the invariant channel")
        func recoveryCorruptionTerminates() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.recovery)
            }
            expectCrashReport(result, contains: "produced recoverable signature failed key recovery")
        }

        /// A different *in-range* recovery ID selects a different nonce
        /// point, so `secp256k1_ecdsa_recover` still succeeds but recovers
        /// the wrong public key — the compare is what catches it.
        @Test("Corrupted recovery ID terminates via the invariant channel")
        func recoveryRecidCorruptionTerminates() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.recoveryRecid)
            }
            expectCrashReport(result, contains: "produced recoverable signature failed key recovery")
        }

        /// The discriminating arm for the wire-form self-check: an
        /// out-of-range recovery ID (≥4) would alias a valid ID inside the
        /// opaque struct — `ecdsa_recover` masks `recid & 3` in non-VERIFY
        /// builds — so a struct-level check could pass the corrupted byte.
        /// Verifying the serialized form instead makes the re-parse hit
        /// `parse_compact`'s `ARG_CHECK`, and the child dies on upstream's
        /// argument check routed through the same invariant channel.
        @Test("Out-of-range recovery ID terminates via the argument check")
        func recoveryRecidOverflowTerminates() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.recoveryRecidOverflow)
            }
            expectCrashReport(result, contains: "libsecp256k1 argument check failed")
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains("recid >= 0 && recid <= 3"))
        }

        /// Control arm: a bound corruptor that mutates nothing must not
        /// false-positive the self-check — the child signs successfully and
        /// exits cleanly — and the stderr marker proves the signing path
        /// actually consulted the seam (a deleted consult fails this arm
        /// outright rather than passing vacuously).
        @Test("Bound-but-inert corruptor lets recoverable signing complete")
        func recoveryInertCorruptorSigns() async {
            let result: ExitTest.Result? = await #expect(
                processExitsWith: .success,
                observing: [\.standardErrorContent]
            ) {
                try runCorruptionCase(.recoveryInert)
            }
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains(kSeamConsultedMarker))
        }
    #endif
}
