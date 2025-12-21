import Foundation

/// BIP-340 Schnorr test vector container
struct BIP340TestVectors: Codable {
    let vectors: [BIP340Vector]
}

/// Individual BIP-340 test vector
struct BIP340Vector: Codable {
    /// Test vector index (0-based)
    let index: Int

    /// Private key (hex, 64 chars) - nil for verification-only vectors
    let secretKey: String?

    /// Public key x-coordinate (hex, 64 chars)
    let publicKey: String

    /// Auxiliary randomness for signing (hex, 64 chars) - nil for verification-only
    let auxRand: String?

    /// Message to sign/verify (hex, variable length)
    let message: String

    /// Schnorr signature (hex, 128 chars = 64 bytes)
    let signature: String

    /// Expected verification result
    let verificationResult: Bool

    /// Optional comment describing the test case
    let comment: String?
}
