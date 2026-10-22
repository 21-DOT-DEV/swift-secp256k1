//
//  InvariantTests.swift
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

struct InvariantTestSuite {
    // Exit tests require Swift 6.2 (`#expect(processExitsWith:)` — ST-0008) and
    // are unavailable on iOS/tvOS/watchOS/visionOS; the SessionSecretRand test
    // below stays unguarded so these platforms still cover it.
    #if compiler(>=6.2) && (os(macOS) || os(Linux) || os(Windows) || os(FreeBSD) || os(OpenBSD))
        /// An installed reporter must observe the invariant violation before the
        /// process terminates. `invariantFailure` ends in `fatalError`, so the
        /// check runs in a child process: the reporter writes a marker to stderr,
        /// the parent asserts the child died *and* emitted the marker.
        @Test("Invariant failure notifies the installed handler before terminating")
        func invariantHandlerRunsBeforeTermination() async {
            let result = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                P256K.setInvariantViolationHandler { text in
                    FileHandle.standardError.write(Data("HANDLER OBSERVED: \(text)".utf8))
                }
                P256K.invariantFailure("test-only invariant violation")
            }
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains("HANDLER OBSERVED: test-only invariant violation"))
        }

        /// Upstream `ARG_CHECK` failures route through the same channel:
        /// `secp256k1_ec_pubkey_combine` with an empty input trips
        /// `ARG_CHECK(n >= 1)`, whose installed callback must notify the
        /// handler before the process terminates.
        @Test("Upstream illegal-argument callback notifies the handler before terminating")
        func upstreamIllegalCallbackRunsHandler() async {
            let result = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                P256K.setInvariantViolationHandler { text in
                    FileHandle.standardError.write(Data("HANDLER OBSERVED: \(text)".utf8))
                }
                var combined = secp256k1_pubkey()
                var pubkey = secp256k1_pubkey()
                withUnsafePointer(to: &pubkey) { pubkeyPtr in
                    var ins: UnsafePointer<secp256k1_pubkey>? = pubkeyPtr
                    withUnsafePointer(to: &ins) { insPtr in
                        _ = secp256k1_ec_pubkey_combine(P256K.Context.rawRepresentation, &combined, insPtr, 0)
                    }
                }
            }
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains("HANDLER OBSERVED: libsecp256k1 argument check failed"))
            #expect(stderr.contains("n >= 1"))
        }

        /// A violation on another thread while the handler is mid-report must
        /// wait in `lock()` until the first report completes and the process
        /// dies — the first report always lands and no second `fatalError`
        /// preempts it.
        @Test("Concurrent violation waits for the first report to complete")
        func concurrentViolationWaitsForFirstReport() async {
            let result = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) {
                P256K.setInvariantViolationHandler { _ in
                    FileHandle.standardError.write(Data("HANDLER-START ".utf8))
                    let thread = Thread {
                        P256K.invariantFailure("second violation")
                    }
                    thread.start()
                    Thread.sleep(forTimeInterval: 0.2)
                    FileHandle.standardError.write(Data("HANDLER-END ".utf8))
                }
                P256K.invariantFailure("first violation")
            }
            let stderr = String(bytes: result?.standardErrorContent ?? [], encoding: .utf8) ?? ""
            #expect(stderr.contains("HANDLER-START"))
            #expect(stderr.contains("HANDLER-END"))
            #expect(!stderr.contains("second violation"))
        }
    #endif

    /// `secp256k1_musig_nonce_gen` rejects an all-zero `session_secrand32` as a
    /// faulty-RNG defense; the validating initializer must reject it first so
    /// the upstream call's failure is unreachable.
    @Test("SessionSecretRand rejects an all-zero seed")
    func sessionSecretRandRejectsZeroSeed() throws {
        #expect(throws: secp256k1Error.underlyingCryptoError) {
            _ = try P256K.MuSig.SessionSecretRand(bytes: [UInt8](repeating: 0, count: P256K.MuSig.SessionSecretRand.byteCount))
        }
    }
}
