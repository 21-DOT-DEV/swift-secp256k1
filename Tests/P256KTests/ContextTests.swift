//
//  ContextTests.swift
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

/// Managed-context ownership — audit finding B-6: a `Context` value owns its
/// `secp256k1_context` through reference storage, destroys it on release, and
/// exposes the raw pointer only through a scoped borrow.
struct ContextTestSuite {
    /// A valid 32-byte secret key for `secp256k1_ec_seckey_verify` probes.
    let secretKey = [UInt8](repeating: 0x01, count: 32)

    /// Creation → use → deallocation ordering: the storage object dies with the
    /// last `Context` value, which is exactly when `deinit` calls
    /// `secp256k1_context_destroy`.
    @Test("managed context: create, use, deallocate ordering")
    func managedContextLifecycle() {
        weak var storage: P256K.Context.Storage?
        do {
            var context: P256K.Context? = P256K.Context()
            storage = context?.storage
            // The borrowed pointer reaches a real const-qualified C call.
            let valid = context?.withUnsafeContextPointer { contextPointer in
                secp256k1_ec_seckey_verify(contextPointer, secretKey)
            }
            #expect(valid == 1)
            // Copies share the owner: releasing the original leaves the
            // context alive while a copy survives.
            let copy = context
            context = nil
            #expect(storage != nil)
            #expect(copy?.storage === storage)
        }
        #expect(storage == nil, "storage must deallocate — and destroy the context — with the last owner")
    }

    /// `Sendable` shared use: upstream guarantees const-qualified calls are
    /// thread-safe, so concurrent borrows need no lock. The probe signs through
    /// `ecmult_gen_ctx` — the randomized blinding state `secp256k1_context_randomize`
    /// installs — rather than a callback path that ignores the context.
    @Test("managed context: concurrent Sendable use")
    func concurrentContextUse() async throws {
        let context = P256K.Context()
        let message32 = [UInt8](repeating: 0xAB, count: 32)
        try await withThrowingTaskGroup(of: Int32.self) { group in
            for _ in 0..<64 {
                group.addTask {
                    var signature = secp256k1_ecdsa_signature()
                    return context.withUnsafeContextPointer { contextPointer in
                        secp256k1_ecdsa_sign(contextPointer, &signature, message32, self.secretKey, nil, nil)
                    }
                }
            }
            for try await valid in group {
                #expect(valid == 1)
            }
        }
    }

    /// The interop accessor exposes a context distinct from the process-global
    /// `rawRepresentation` and usable with the raw `libsecp256k1` product.
    @Test("withUnsafeContextPointer reaches the C API")
    func rawInteropAccessor() {
        let context = P256K.Context()
        let ownsDistinctContext = context.withUnsafeContextPointer { pointer in
            pointer != P256K.Context.rawRepresentation
                && secp256k1_ec_seckey_verify(pointer, secretKey) == 1
        }
        #expect(ownsDistinctContext)
    }

    /// The deprecated forwarder keeps its unmanaged contract until 1.0 — the
    /// caller still owns the `secp256k1_context_destroy` pairing.
    @available(*, deprecated)
    @Test("deprecated create() still returns a usable, destructible context")
    func deprecatedCreate() {
        let context = P256K.Context.create()
        #expect(secp256k1_ec_seckey_verify(context, secretKey) == 1)
        secp256k1_context_destroy(context)
    }
}
