//
//  SHA256Tests.swift
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

struct SHA256TestSuite {
    @Test("SHA256 test")
    func sha256Test() throws {
        let expectedHashDigest = "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342"
        let data = try #require("For this sample, this 63-byte string will be used as input data".data(using: .utf8))

        let digest = SHA256.hash(data: data)

        #expect(String(bytes: Array(digest)) == expectedHashDigest)
    }

    @Test("SHA256 hash digest consistency test")
    func shaHashDigestTest() throws {
        let expectedHash = try "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342".bytes
        let data = try #require("For this sample, this 63-byte string will be used as input data".data(using: .utf8))

        let digest = SHA256.hash(data: data)

        let constructedDigest = try HashDigest(expectedHash)

        // Verify the generated hash digest matches the manual constructed hash digest
        #expect(String(bytes: Array(digest)) == String(bytes: Array(constructedDigest)))
    }

    @Test("HashDigest rejects a short byte array")
    func hashDigestRejectsShortInput() {
        // 3 bytes must throw rather than trap on out-of-range slicing
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            try HashDigest([1, 2, 3])
        }
    }

    @Test("HashDigest rejects a long byte array")
    func hashDigestRejectsLongInput() {
        // 33 bytes must throw rather than silently truncate
        #expect(throws: secp256k1Error.incorrectParameterSize) {
            try HashDigest([UInt8](repeating: 0xAB, count: 33))
        }
    }

    @Test("HashDigest accepts exactly 32 bytes")
    func hashDigestAcceptsExactInput() throws {
        let digest = try HashDigest([UInt8](repeating: 0xCD, count: 32))

        #expect(Array(digest) == [UInt8](repeating: 0xCD, count: 32))
    }
}
