//
//  Invariant.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
public extension P256K {
    /// Installs (or clears, by passing `nil`) the reporter invoked when the
    /// library detects a state that the libsecp256k1 API contract makes
    /// unreachable.
    ///
    /// Every value crossing a public boundary is validated at construction —
    /// keys are parse-verified, signatures parsed, fixed-size buffers
    /// length-checked — so a violation can only indicate memory corruption or a
    /// defect in this library, never malformed caller input. The library follows
    /// libsodium's `sodium_misuse()` model for such states: fail-stop
    /// termination rather than continuing with undefined cryptographic state.
    ///
    /// The handler is for observability only (logging, metrics, crash
    /// artifacts). The process still terminates via `fatalError` after it
    /// returns — there is no safe continuation past an impossible state —
    /// matching `sodium_misuse`, which aborts even if a custom handler returns.
    /// The handler is invoked at most once per process, from the thread that
    /// first trips the invariant.
    ///
    /// Installs are serialized under an internal lock and may happen at any
    /// time, though installing before spawning concurrent work is recommended.
    /// The application process owns this hook — libraries that merely depend on
    /// `P256K` should not install a handler, so a consumer's reporter is not
    /// silently replaced.
    ///
    /// The handler receives a description of the violated invariant — the
    /// upstream call that failed and why it is provably unreachable. Contexts
    /// created by ``Context/create()`` additionally route libsecp256k1's own
    /// illegal-argument (`ARG_CHECK`) and internal-error callbacks through the
    /// same reporter, so those are observed identically rather than aborting
    /// anonymously — including violations triggered by C calls a consumer makes
    /// directly on ``Context/rawRepresentation``. (`VERIFY_CHECK` is
    /// compile-time debug machinery — it does not invoke either callback.)
    ///
    /// The handler runs on the first thread to trip an invariant; concurrent
    /// violations block until the first report completes and the process
    /// terminates, so the first report always lands — keep the handler minimal
    /// and async-signal-safety aware, and never let it block indefinitely.
    ///
    /// - Parameter handler: The reporter to install, or `nil` to clear a
    ///   previously installed reporter.
    static func setInvariantViolationHandler(_ handler: (@Sendable (String) -> Void)?) {
        invariantHandlerLock.lock()
        defer { invariantHandlerLock.unlock() }
        invariantViolationHandler = handler
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K {
    /// Serializes installs and the dispatch of the invariant-violation handler —
    /// the analogue of libsodium's `sodium_crit` lock around `_misuse_handler`.
    /// `NSRecursiveLock` rather than `Synchronization.Mutex` because the
    /// package's declared deployment floors predate `Mutex` availability, and
    /// recursive so that a nested invariant failure on the dispatching thread
    /// re-enters instead of deadlocking.
    private static let invariantHandlerLock: NSRecursiveLock = .init()

    /// The installed invariant-violation reporter; read and written only while
    /// holding ``invariantHandlerLock``.
    nonisolated(unsafe) private static var invariantViolationHandler: (@Sendable (String) -> Void)?

    /// Whether the installed handler has already been invoked. A nested
    /// invariant failure — e.g. the handler itself calling back into `P256K` —
    /// skips a second invocation so the process still terminates promptly,
    /// matching Rust's abort-on-nested-panic behavior.
    nonisolated(unsafe) private static var invariantHandlerDispatched = false

    /// Reports a violated internal invariant to the installed handler (if any),
    /// then terminates via `fatalError`.
    ///
    /// Used only for states the libsecp256k1 contract and this library's
    /// construction-time validation make unreachable — e.g. `secp256k1_ecdsa_sign`
    /// failing on an already-validated key. Reachable failure modes throw instead.
    ///
    /// ``invariantHandlerLock`` is acquired before the once-check and is
    /// deliberately never released: the process terminates while the dispatching
    /// thread still holds it. A violation on another thread therefore waits in
    /// `lock()` until the first report completes and the process dies — the
    /// crash log always records the original fault — while a nested failure on
    /// the dispatching thread itself re-enters the recursive lock, sees
    /// ``invariantHandlerDispatched`` set, and terminates without re-invoking
    /// the handler or deadlocking.
    static func invariantFailure(
        _ message: @autoclosure () -> String,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> Never {
        let text = message()

        invariantHandlerLock.lock()
        let handler = invariantHandlerDispatched ? nil : invariantViolationHandler
        invariantHandlerDispatched = true

        handler?(text)
        fatalError(text, file: file, line: line)
    }
}
