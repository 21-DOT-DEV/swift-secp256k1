# ``zkp``

A Swift package wrapping libsecp256k1, providing high-performance, high-assurance cryptographic operations on the secp256k1 elliptic curve.

## Overview

swift-secp256k1 is a Swift wrapper around libsecp256k1, a C library for digital signatures and other cryptographic primitives on the secp256k1 elliptic curve. This package brings the power and efficiency of libsecp256k1 to Swift projects, making it ideal for use in iOS, macOS, tvOS, watchOS, visionOS, and Linux applications.

Key features include:

- secp256k1 ECDSA signing/verification and key generation
- Schnorr signatures (BIP-340)
- Public key recovery
- ECDH key exchange
- Constant-time, constant-memory access operations
- No runtime dependencies
- Optimized for performance and security

swift-secp256k1 is particularly well-suited for blockchain and cryptocurrency applications, especially those involving Bitcoin, but can be used in any project requiring secure elliptic curve cryptography.

For detailed usage instructions and examples, check out the <doc:User-Guide>.