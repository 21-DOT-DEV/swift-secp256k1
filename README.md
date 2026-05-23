[![Latest Release](https://github.com/21-DOT-DEV/swift-secp256k1/actions/workflows/xcframework-release.yml/badge.svg)](https://github.com/21-DOT-DEV/swift-secp256k1/actions/workflows/xcframework-release.yml) [![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE) [![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F21-DOT-DEV%2Fswift-secp256k1%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/21-DOT-DEV/swift-secp256k1) [![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F21-DOT-DEV%2Fswift-secp256k1%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/21-DOT-DEV/swift-secp256k1)

# 🔐 swift-secp256k1

*Previously known as `GigaBitcoin/secp256k1.swift` (module renamed to `P256K`).*

Swift cryptography library for Bitcoin and Nostr. ECDSA, Schnorr Signatures, Elliptic Curve Diffie-Hellman (ECDH), and zero-knowledge proofs on **secp256k1**, Bitcoin's elliptic curve. The `P256K` module wraps [libsecp256k1](https://github.com/bitcoin-core/secp256k1) from Bitcoin Core.

🌐 [Project page](https://21.dev/packages/p256k/) · 📚 [Documentation](https://docs.21.dev/documentation/p256k/)

> [!IMPORTANT]
> **`secp256k1` is not Apple's `P256` curve.** CryptoKit's `P256` is NIST `secp256r1` (the `r` is for random); this library's `P256K` is `secp256k1` (the `k` is for Koblitz). Keys and signatures don't interoperate between the two. **CryptoSwift** and Apple's **CommonCrypto** also do not implement secp256k1. See [Why CryptoKit's P256 can't sign Bitcoin or Nostr](https://docs.21.dev/documentation/p256k/cryptokitp256andsecp256k1).

## Contents

- [Features](#features)
- [Installation](#installation)
- [Package Traits](#package-traits)
- [Swift Versions](#swift-versions)
- [Usage Examples](#usage-examples)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## Features

- Provide lightweight ECDSA & Schnorr Signatures functionality
- Support simple and advanced usage, including BIP-327 and BIP-340
- Expose libsecp256k1 bindings for full control of the implementation
- Offer a familiar API design inspired by [Swift Crypto](https://github.com/apple/swift-crypto)
- Maintain automatic updates for Swift and libsecp256k1
- Ensure availability for Linux and Apple platform ecosystems

## Installation

Add `swift-secp256k1` to your `Package.swift`:

```swift
.package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.23.0"),
```

Then include `P256K` as a target dependency:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "P256K", package: "swift-secp256k1")
]),
```

Using CocoaPods, evaluating in a playground first, or want the full Xcode + plugin-trust walkthrough? See [Getting Started](https://docs.21.dev/documentation/p256k/gettingstarted#Alternative-installation-methods).

## Package Traits

This package uses [SE-0450 Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) (Swift 6.1+) for module selection. The defaults — `ecdh`, `musig`, `recovery`, `schnorrsig` — cover most use cases. To opt into other modules (ZKP bundle, `uint256`, etc.), see [Choosing modules with package traits](https://docs.21.dev/documentation/p256k/gettingstarted#Choosing-modules-with-package-traits) in Getting Started.

## Swift Versions

| swift-secp256k1       | Minimum Swift Version | Minimum Xcode Version |
|-----------------------|-----------------------|-----------------------|
| `0.1.0 ..< 0.4.0`     | 5.0                   | 10.2                  |
| `0.4.0 ..< 0.5.0`     | 5.1                   | 11.0                  |
| `0.5.0 ..< 0.8.0`     | 5.5                   | 13.0                  |
| `0.8.0 ..< 0.14.0`    | 5.6                   | 13.3                  |
| `0.14.0 ..< 0.18.0`   | 5.8                   | 14.3                  |
| `0.18.0 ..< 0.22.0`   | 6.0                   | 16.0                  |
| `0.22.0 ...`          | 6.1                   | 16.3                  |

## Usage Examples

### ECDSA
```swift
import P256K

// Private key
let privateBytes = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes
let privateKey = try! P256K.Signing.PrivateKey(dataRepresentation: privateBytes)

// Public key
print(String(bytes: privateKey.publicKey.dataRepresentation))

// ECDSA signature
let messageData = "We're all Satoshi.".data(using: .utf8)!
let signature = privateKey.signature(for: messageData)

// DER signature
print(signature.derRepresentation.base64EncodedString())
```

*→ Full API: [docs.21.dev/documentation/p256k/p256k/signing](https://docs.21.dev/documentation/p256k/p256k/signing)*

### Schnorr
```swift
// Strict BIP340 mode is disabled by default for Schnorr signatures with variable length messages
let privateKey = try! P256K.Schnorr.PrivateKey()

// Extra params for custom signing
var auxRand = try! "C87AA53824B4D7AE2EB035A2B5BBBCCC080E76CDC6D1692C4B0B62D798E6D906".bytes
var messageDigest = try! "7E2D58D8B3BCDF1ABADEC7829054F90DDA9805AAB56C77333024B9D0A508B75C".bytes

// API allows for signing variable length messages
let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)
```

*→ Full API: [docs.21.dev/documentation/p256k/p256k/schnorr](https://docs.21.dev/documentation/p256k/p256k/schnorr)*

### Tweak

```swift
let privateKey = try! P256K.Signing.PrivateKey()

// Adding a tweak to the private key and public key
let tweak = try! "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6".bytes
let tweakedPrivateKey = try! privateKey.add(tweak)
let tweakedPublicKeyKey = try! privateKey.publicKey.add(tweak)
```

*→ Full API: [docs.21.dev/documentation/p256k/tweakingkeys](https://docs.21.dev/documentation/p256k/tweakingkeys)*

### Elliptic Curve Diffie Hellman

```swift
let privateKey = try! P256K.KeyAgreement.PrivateKey()
let publicKey = try! P256K.KeyAgreement.PrivateKey().publicKey

// Create a compressed shared secret with a private key from only a public key
let sharedSecret = privateKey.sharedSecretFromKeyAgreement(with: publicKey, format: .compressed)

// By default, libsecp256k1 hashes the x-coordinate with version information.
let symmetricKey = SHA256.hash(data: sharedSecret.bytes)
```

*→ Full guide: [docs.21.dev/documentation/p256k/ellipticcurvediffiehellman](https://docs.21.dev/documentation/p256k/ellipticcurvediffiehellman)*

### Silent Payments Scheme

```swift
let privateSign1 = try! P256K.Signing.PrivateKey()
let privateSign2 = try! P256K.Signing.PrivateKey()

let privateKey1 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign1.dataRepresentation)
let privateKey2 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign2.dataRepresentation)

let sharedSecret1 = privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
let sharedSecret2 = privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey)

let symmetricKey1 = SHA256.hash(data: sharedSecret1.bytes)
let symmetricKey2 = SHA256.hash(data: sharedSecret2.bytes)

let sharedSecretSign1 = try! P256K.Signing.PrivateKey(dataRepresentation: symmetricKey1.bytes)
let sharedSecretSign2 = try! P256K.Signing.PrivateKey(dataRepresentation: symmetricKey2.bytes)

// Spendable Silent Payment private key
let privateTweak1 = try! sharedSecretSign1.add(privateSign1.publicKey.xonly.bytes)
let publicTweak2 = try! sharedSecretSign2.publicKey.add(privateSign1.publicKey.xonly.bytes)

let schnorrPrivate = try! P256K.Schnorr.PrivateKey(dataRepresentation: sharedSecretSign2.dataRepresentation)
// Payable Silent Payment public key
let xonlyTweak2 = try! schnorrPrivate.xonly.add(privateSign1.publicKey.xonly.bytes)
```

*→ Full guide: [docs.21.dev/documentation/p256k/silentpayments](https://docs.21.dev/documentation/p256k/silentpayments)* — BIP-352 walkthrough with sender derivation, receiver scanning, scan/spend key separation, and tagged-hash specifics.

### Recovery

```swift
let privateKey = try! P256K.Recovery.PrivateKey()
let messageData = "We're all Satoshi.".data(using: .utf8)!

// Create a recoverable ECDSA signature
let recoverySignature = privateKey.signature(for: messageData)

// Recover an ECDSA public key from a signature
let publicKey = P256K.Recovery.PublicKey(messageData, signature: recoverySignature)

// Convert a recoverable signature into a normal signature
let signature = recoverySignature.normalize
```

*→ Full API: [docs.21.dev/documentation/p256k/p256k/recovery](https://docs.21.dev/documentation/p256k/p256k/recovery)*

### Combine Public Keys

```swift
let privateKey = try! P256K.Signing.PrivateKey()
let publicKey = try! P256K.Signing.PrivateKey().publicKey

// The Combine API arguments are an array of PublicKey objects and an optional format 
publicKey.combine([privateKey.publicKey], format: .uncompressed)
```

*→ Full API: [docs.21.dev/documentation/p256k/p256k/signing/publickey](https://docs.21.dev/documentation/p256k/p256k/signing/publickey)*

### PEM Key Format

```swift
let privateKeyString = """
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
-----END EC PRIVATE KEY-----
"""

// Import keys generated from OpenSSL
let privateKey = try! P256K.Signing.PrivateKey(pemRepresentation: privateKeyString)
```

*→ Full API: [docs.21.dev/documentation/p256k/serializingkeys](https://docs.21.dev/documentation/p256k/serializingkeys)*

### MuSig2

```swift
// Initialize private keys for two signers
let firstPrivateKey = try! P256K.Schnorr.PrivateKey()
let secondPrivateKey = try! P256K.Schnorr.PrivateKey()

// Aggregate the public keys using MuSig
let aggregateKey = try! P256K.MuSig.aggregate([firstPrivateKey.publicKey, secondPrivateKey.publicKey])

// Message to be signed
let message = "Vires in Numeris.".data(using: .utf8)!
let messageHash = SHA256.hash(data: message)

// Generate nonces for each signer
let firstNonce = try! P256K.MuSig.Nonce.generate(
    secretKey: firstPrivateKey,
    publicKey: firstPrivateKey.publicKey,
    msg32: Array(messageHash)
)

let secondNonce = try! P256K.MuSig.Nonce.generate(
    secretKey: secondPrivateKey,
    publicKey: secondPrivateKey.publicKey,
    msg32: Array(messageHash)
)

// Aggregate nonces
let aggregateNonce = try! P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

// Create partial signatures
let firstPartialSignature = try! firstPrivateKey.partialSignature(
    for: messageHash,
    pubnonce: firstNonce.pubnonce,
    secureNonce: firstNonce.secnonce,
    publicNonceAggregate: aggregateNonce,
    publicKeyAggregate: aggregateKey
)

let secondPartialSignature = try! secondPrivateKey.partialSignature(
    for: messageHash,
    pubnonce: secondNonce.pubnonce,
    secureNonce: secondNonce.secnonce,
    publicNonceAggregate: aggregateNonce,
    publicKeyAggregate: aggregateKey
)

// Aggregate partial signatures into a full signature
let aggregateSignature = try! P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature])

// Verify the aggregate signature
let isValid = aggregateKey.isValidSignature(
    firstPartialSignature,
    publicKey: firstPrivateKey.publicKey,
    nonce: firstNonce.pubnonce,
    for: messageHash
)

print("Is valid MuSig signature: \(isValid)")
```

*→ Full API: [docs.21.dev/documentation/p256k/musig2multisignatures](https://docs.21.dev/documentation/p256k/musig2multisignatures)*

## Security

For information on reporting security vulnerabilities, see [SECURITY.md](SECURITY.md).

## Contributing

Contributions are welcome. Please read the [21-DOT-DEV contributing guidelines](https://github.com/21-DOT-DEV/.github/blob/main/CONTRIBUTING.md) for general workflow, and [AGENTS.md](AGENTS.md) for project-specific code style (SwiftFormat, SwiftLint, Lefthook) and AI-assisted development guidance.

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
