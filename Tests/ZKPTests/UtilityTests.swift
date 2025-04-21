//
//  UtilityTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

#if canImport(ZKP)
    @testable import ZKP
#else
    @testable import P256K
#endif

import Foundation
import Testing

struct UtilityTestSuite {
    @Test("Verify keypair equality checks work correctly")
    func testKeypairSafeCompare() {
        let expectedPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888ed"
        var privateKeyBytes = try! expectedPrivateKey.bytes
        let privateKey0 = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
        let privateKey1 = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

        // Verify the keys match
        #expect(privateKey0 == privateKey1)

        let expectedFailingPrivateKey = "7da12cc39bb4189ac72d34fc2225df5cf36aaacdcac7e5a43963299bc8d888dd"
        privateKeyBytes = try! expectedFailingPrivateKey.bytes
        let privateKey2 = try! P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)

        #expect(privateKey0 != privateKey2)
    }

    @Test("Verify memory zeroization works correctly")
    func testZeroization() {
        var array: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8, 9]

        memset_s(&array, array.capacity, 0, array.capacity)

        let set0 = Set(array)

        array = [UInt8](repeating: 1, count: Int.random(in: 10...100000))

        #expect(array.count > 9)

        memset_s(&array, array.capacity, 0, array.capacity)

        let set1 = Set(array)

        #expect(set0.first == 0)
        #expect(set0.count == 1)
        #expect(set0 == set1)
    }

    @Test("Test Compact Size Prefix")
    func testCompactSizePrefix() {
        let bytes = try! "c15bf08d58a430f8c222bffaf9127249c5cdff70a2d68b2b45637eb662b6b88eb5c81451874bd9ebd4b6fd4bba1f84cdfb533c532365d22a0a702205ff658b17c9".bytes
        let compactBytes = "41c15bf08d58a430f8c222bffaf9127249c5cdff70a2d68b2b45637eb662b6b88eb5c81451874bd9ebd4b6fd4bba1f84cdfb533c532365d22a0a702205ff658b17c9"
        #expect(compactBytes == String(bytes: Array(Data(bytes).compactSizePrefix)), "Compact size prefix encoding is incorrect.")
    }
}
