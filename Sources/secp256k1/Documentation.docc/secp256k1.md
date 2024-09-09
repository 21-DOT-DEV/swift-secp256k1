# ``secp256k1``

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

For detailed usage instructions and examples, check out the <doc:User-Guide>.

Incorporating the key agreement APIs, `secp256k1.KeyAgreement` and `P256.KeyAgreement`, into the comparison alongside the signing APIs enhances the overview of cryptographic operations these libraries facilitate. The key agreement process allows two parties to securely establish a shared secret over an insecure channel, which is a fundamental operation in many cryptographic protocols.

Below is an extended hypothetical comparison, including both the signing and key agreement functionalities of the `secp256k1` and `P256` APIs. This table is constructed based on common cryptographic API patterns in Swift, aiming to showcase a typical usage scenario for both signing and key agreement operations.


### Key Generation (ECDSA)

```swift
// secp256k1 Signing Key Generation
let privateP256K = secp256k1.Signing.PrivateKey()
let publicP256K = privateP256K.publicKey

// P256 Signing Key Generation
let privateP256 = P256.Signing.PrivateKey()
let publicP256 = privateP256.publicKey
```

### Signature Generation & Verification (ECDSA)

```swift
// Prepare the message
let message = "Hello, world!".data(using: .utf8)!

// secp256k1 Signing & Verification
let signatureP256K = try! privateP256K.signature(for: message)
let isValidP256K = try! publicP256K.isValidSignature(signatureP256K, for: message)

// P256 Signing
let signatureP256 = try! privateP256.signature(for: message)
let isValidP256 = try! publicP256.isValidSignature(signatureP256, for: message)
```

### Key Agreement (ECDH)

```swift
// secp256k1 Key Agreement
let privateP256K = secp256k1.KeyAgreement.PrivateKey()
let publicP256K = privateP256K.publicKey
let sharedSecretP256K = try! privateP256K.sharedSecret(from: publicP256K)

// P256 Key Agreement
let privateP256 = P256.KeyAgreement.PrivateKey()
let publicP256 = privateP256.publicKey
let sharedSecretP256 = try! privateP256.sharedSecret(from: publicP256)
```



### Notes on the Extended Table

- **Key Generation (Key Agreement)**: Similar to signing, key agreement operations start with generating a pair of private and public keys. These keys are specifically used for the key agreement process to ensure a separate cryptographic operation domain from signing.
  
- **Key Agreement**: The key agreement examples illustrate how two parties can generate a shared secret using their private keys and the other party's public key. This shared secret can then be used to derive encryption keys or as a part of other cryptographic protocols. The method names and exact parameters for initiating key agreement might differ between libraries, reflecting the unique design decisions made by the library authors.

### Considerations

- This hypothetical code-level comparison is based on standard cryptographic API patterns and might not directly reflect the specific API designs of `secp256k1` and `P256`. Always refer to the official documentation for accurate and detailed information.

- Cryptographic operations, especially key agreement and signing, are complex and sensitive. Proper error handling, secure key storage, and a thorough understanding of the cryptographic principles involved are essential for safe implementation.

- The table simplifies the key agreement process to fit the comparison format. In practice, establishing a shared secret securely involves additional steps, such as validating public keys and possibly using ephemeral keys to protect against future compromises (forward secrecy).

Developers should delve into the specifics of each library when choosing between them, considering factors like the cryptographic needs of their application, the level of community and developer support for the library, and the security implications of the cryptographic primitives offered.