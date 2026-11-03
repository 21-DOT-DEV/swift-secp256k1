//
//  Corruption.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension P256K {
    /// The byte-level corruptor bound to the current task, if any.
    ///
    /// Internal test seam for the verify-after-sign self-checks (spec 004,
    /// Group E): each signing method consults ``corruptProducedSignature(_:)``
    /// between producing a signature and self-verifying it, so a
    /// fault-injection test can prove a corrupted output terminates via
    /// ``invariantFailure(_:file:line:)`` instead of escaping. Bound only from
    /// `@testable` test code via `P256K.$signatureCorruptor.withValue(...)`;
    /// the unbound default is `nil` — production consults are no-ops.
    ///
    /// A `@TaskLocal` rather than mutable global state so a bound corruptor
    /// cannot leak into unrelated tests running on other tasks and restores
    /// itself when the `withValue` scope exits — the same install / run /
    /// restore discipline upstream libsecp256k1's counting-callback test
    /// macros apply to their global test hooks (a hook left installed once
    /// masked real test failures upstream, bitcoin-core/secp256k1#1167).
    ///
    /// The corruptor mutates an already-produced signature object through a
    /// raw mutable view so a single shape covers every produced artifact —
    /// serialized arrays via `withUnsafeMutableBytes`, opaque libsecp256k1
    /// structs via `withUnsafeMutableBytes(of:)` — without copying opaque
    /// structs or inventing serialization formats upstream deliberately
    /// withholds. In-place byte mutation is also the faithful fault model:
    /// a real fault-injection attack flips bytes without regard to the type
    /// or layout of the object it corrupts.
    @TaskLocal static var signatureCorruptor: (@Sendable (UnsafeMutableRawBufferPointer) -> Void)?

    /// Consults the task-local test seam on freshly produced signature bytes.
    ///
    /// Signing methods call this once between producing the signature object
    /// and self-verifying it; a no-op unless test code has bound
    /// ``signatureCorruptor`` on the current task.
    ///
    /// - Parameter bytes: A mutable view of the produced object — array or
    ///   `Data` storage via `withUnsafeMutableBytes`, opaque C structs via
    ///   `withUnsafeMutableBytes(of:)`.
    static func corruptProducedSignature(_ bytes: UnsafeMutableRawBufferPointer) {
        signatureCorruptor?(bytes)
    }
}
