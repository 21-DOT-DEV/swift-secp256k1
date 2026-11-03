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
    /// exit-test child process — gains one arm per signing path as T009–T012
    /// wire each path's seam consult.
    private enum CorruptionCase {
        /// Simulates the corrupt → self-verify → crash pipeline without a real
        /// signing path: corrupt produced bytes, detect the mutation, fire
        /// `invariantFailure`.
        case canned
    }

    /// Executes one fault-injection scenario inside an exit-test child
    /// process.
    ///
    /// Exit-test bodies must be capture-free literal code under ST-0008, so
    /// the scenario reaches the child as a literal enum argument inside each
    /// test's `#expect` body — the `TestHelperProcess` env-var discriminator
    /// Go uses for death tests, translated to the only channel Swift Testing
    /// bodies allow.
    private func runCorruptionCase(_ path: CorruptionCase) {
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
                runCorruptionCase(.canned)
            }
            expectCrashReport(result, contains: "corrupted produced signature")
        }
    #endif
}
