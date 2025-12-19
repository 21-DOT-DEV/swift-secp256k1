import Foundation
import P256K
import XCTest

final class SchnorrVectorTests: XCTestCase {
    private var vectors: [BIP340Vector] = []

    override func setUp() async throws {
        try await super.setUp()
        vectors = try loadBIP340Vectors()
    }

    func testAllBIP340Vectors() throws {
        XCTAssertFalse(vectors.isEmpty, "No BIP-340 vectors loaded")

        for vector in vectors {
            let result = verifyVector(vector)
            XCTAssertEqual(
                result,
                vector.verificationResult,
                "Vector \(vector.index) failed: expected \(vector.verificationResult), got \(result). \(vector.comment ?? "")"
            )
        }
    }

    func testVerificationOnlyVectors() throws {
        let verificationOnlyVectors = vectors.filter { $0.secretKey == nil }
        XCTAssertFalse(verificationOnlyVectors.isEmpty, "No verification-only vectors found")

        for vector in verificationOnlyVectors {
            let result = verifyVector(vector)
            XCTAssertEqual(
                result,
                vector.verificationResult,
                "Verification-only vector \(vector.index) failed: \(vector.comment ?? "")"
            )
        }
    }

    func testSigningVectors() throws {
        let signingVectors = vectors.filter { $0.secretKey != nil && $0.verificationResult == true }
        XCTAssertFalse(signingVectors.isEmpty, "No signing vectors found")

        for vector in signingVectors {
            guard let secretKeyHex = vector.secretKey,
                  let auxRandHex = vector.auxRand else {
                continue
            }

            do {
                let privateKeyBytes = try secretKeyHex.bytes
                let privateKey = try P256K.Schnorr.PrivateKey(dataRepresentation: privateKeyBytes)

                var messageArray: [UInt8] = vector.message.isEmpty ? [] : try vector.message.bytes
                var auxRandArray = try auxRandHex.bytes

                let signature = try privateKey.signature(
                    message: &messageArray,
                    auxiliaryRand: &auxRandArray
                )

                XCTAssertEqual(
                    String(bytes: signature.dataRepresentation.bytes).uppercased(),
                    vector.signature.uppercased(),
                    "Signing vector \(vector.index) produced wrong signature"
                )
            } catch {
                XCTFail("Signing vector \(vector.index) threw error: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    private func loadBIP340Vectors() throws -> [BIP340Vector] {
        guard let url = Bundle(for: type(of: self)).url(
            forResource: "bip340-vectors",
            withExtension: "json"
        ) else {
            throw TestVectorError.fileNotFound(filename: "bip340-vectors")
        }

        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(BIP340TestVectors.self, from: data)
        return container.vectors
    }

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
