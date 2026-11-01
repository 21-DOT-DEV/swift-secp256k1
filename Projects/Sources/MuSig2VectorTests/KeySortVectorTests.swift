//
//  KeySortVectorTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import P256K
import Testing

/// BIP-0327 Key Sort test vectors
@Suite("BIP-0327 Key Sort")
struct KeySortVectorTests {
    /// Loaded test vectors
    let vectors: KeySortVectors

    init() throws {
        let loader = TestVectorLoader<KeySortVectors>(bundle: Bundle.module)
        self.vectors = try loader.load(from: "key_sort_vectors")
    }

    /// Asserts `sortedPublicKeys(_:)` against the official `sorted_pubkeys`
    /// output byte-for-byte. The fixture deliberately includes a duplicate
    /// (`pubkeys[0]` == `pubkeys[5]`) and a near-duplicate pair differing only in
    /// the final byte, so a dropped element, a wrong pointer-to-object mapping,
    /// or an off-by-one in the serialized comparison all fail this check.
    @Test("sortedPublicKeys matches the official canonical ordering")
    func canonicalSortOrder() throws {
        let pubkeys = try vectors.pubkeys.map { hex -> P256K.Schnorr.PublicKey in
            try P256K.Schnorr.PublicKey(dataRepresentation: hex.bytes, format: .compressed)
        }
        let expected = try vectors.sorted_pubkeys.map { try $0.bytes }

        let sorted = P256K.MuSig.sortedPublicKeys(pubkeys)

        #expect(
            sorted.map { Array($0.dataRepresentation) } == expected,
            "sortedPublicKeys must reproduce sorted_pubkeys exactly, duplicates included"
        )
    }

    /// The helper exists to make the order-sensitive `aggregate(_:)` reach the
    /// same aggregate for every assembly order of one multiset — verify that
    /// composed behavior end-to-end on the vector's keys.
    @Test("Aggregating sorted keys is order-invariant")
    func aggregateSortedKeysOrderInvariant() throws {
        let pubkeys = try vectors.pubkeys.map { hex -> P256K.Schnorr.PublicKey in
            try P256K.Schnorr.PublicKey(dataRepresentation: hex.bytes, format: .compressed)
        }

        let canonical = try P256K.MuSig.aggregate(P256K.MuSig.sortedPublicKeys(pubkeys))
        let permuted = try P256K.MuSig.aggregate(P256K.MuSig.sortedPublicKeys(Array(pubkeys.reversed())))

        #expect(
            canonical.xonly.bytes == permuted.xonly.bytes,
            "Sorting first must give every input ordering the same aggregate"
        )
    }
}
