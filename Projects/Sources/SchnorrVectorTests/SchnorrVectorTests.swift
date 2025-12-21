//
//  SchnorrVectorTests.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2025 21-DOT-DEV
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation
import P256K
import Testing

/// BIP-340 Schnorr signature test vectors
@Suite("BIP-340 Schnorr Signatures")
struct SchnorrVectorTests {
    /// Loaded test vectors
    let vectors: [BIP340Vector]

    init() throws {
        let loader = TestVectorLoader<BIP340TestVectors>(bundle: Bundle.module)
        let container = try loader.load(from: "bip340-vectors")
        self.vectors = container.vectors
    }

    @Test("All BIP-340 vectors pass verification")
    func allBIP340Vectors() throws {
        #expect(!vectors.isEmpty, "No BIP-340 vectors loaded")

        for vector in vectors {
            let result = verifyVector(vector)
            #expect(
                result == vector.verificationResult,
                "Vector \(vector.index) failed: expected \(vector.verificationResult), got \(result). \(vector.comment ?? "")"
            )
        }
    }

    @Test("Verification-only vectors pass")
    func verificationOnlyVectors() throws {
        let verificationOnlyVectors = vectors.filter { $0.secretKey == nil }
        #expect(!verificationOnlyVectors.isEmpty, "No verification-only vectors found")

        for vector in verificationOnlyVectors {
            let result = verifyVector(vector)
            #expect(
                result == vector.verificationResult,
                "Verification-only vector \(vector.index) failed: \(vector.comment ?? "")"
            )
        }
    }

    @Test("Signing vectors produce correct signatures")
    func signingVectors() throws {
        let signingVectors = vectors.filter { $0.secretKey != nil && $0.verificationResult == true }
        #expect(!signingVectors.isEmpty, "No signing vectors found")

        for vector in signingVectors {
            guard let secretKeyHex = vector.secretKey,
                  let auxRandHex = vector.auxRand else {
                continue
            }

            let privateKeyBytes = try secretKeyHex.bytes
            let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)

            var messageArray: [UInt8] = vector.message.isEmpty ? [] : try vector.message.bytes
            var auxRandArray = try auxRandHex.bytes

            let signature = try privateKey.signature(
                message: &messageArray,
                auxiliaryRand: &auxRandArray
            )

            #expect(
                String(bytes: signature.dataRepresentation.bytes).uppercased() == vector.signature.uppercased(),
                "Signing vector \(vector.index) produced wrong signature"
            )
        }
    }

    // MARK: - Private Helpers

    private func verifyVector(_ vector: BIP340Vector) -> Bool {
        do {
            let publicKeyBytes = try vector.publicKey.bytes
            let xonlyKey = P256K.Schnorr.XonlyKey(dataRepresentation: publicKeyBytes)

            let signatureBytes = try vector.signature.bytes
            let signature = try P256K.Schnorr.SchnorrSignature(dataRepresentation: signatureBytes)

            var messageArray: [UInt8] = vector.message.isEmpty ? [] : try vector.message.bytes

            return xonlyKey.isValid(signature, for: &messageArray)
        } catch {
            return false
        }
    }
}
