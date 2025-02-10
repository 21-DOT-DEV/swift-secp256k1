//
//  SHA256Tests.swift
//  swift-secp256k1
//
//  Created by csjones on 2/10/25.
//

#if canImport(ZKP)
@testable import ZKP
#else
@testable import P256K
#endif

import Testing

struct SHA256TestSuite {

    @Test("SHA256 test")
    func sha256Test() {
        let expectedHashDigest = "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342"
        let data = "For this sample, this 63-byte string will be used as input data".data(using: .utf8)!

        let digest = SHA256.hash(data: data)

        #expect(String(bytes: Array(digest)) == expectedHashDigest)
    }

    @Test("SHA256 hash digest consistency test")
    func shaHashDigestTest() {
        let expectedHash = try! "f08a78cbbaee082b052ae0708f32fa1e50c5c421aa772ba5dbb406a2ea6be342".bytes
        let data = "For this sample, this 63-byte string will be used as input data".data(using: .utf8)!

        let digest = SHA256.hash(data: data)

        let constructedDigest = HashDigest(expectedHash)

        // Verify the generated hash digest matches the manual constructed hash digest
        #expect(String(bytes: Array(digest)) == String(bytes: Array(constructedDigest)))
    }
}
