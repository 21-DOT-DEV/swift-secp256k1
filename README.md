[![Build Status](https://app.bitrise.io/app/18c18db60fc4fddf/status.svg?token=nczB4mTPCrlTfDQnXH_8Pw&branch=main)](https://app.bitrise.io/app/18c18db60fc4fddf) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F21-DOT-DEV%2Fswift-secp256k1%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/21-DOT-DEV/swift-secp256k1) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F21-DOT-DEV%2Fswift-secp256k1%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/21-DOT-DEV/swift-secp256k1)

# 🔐 swift-secp256k1

Swift package for elliptic curve public key cryptography, ECDSA, and Schnorr Signatures for Bitcoin, with C bindings from [libsecp256k1](https://github.com/bitcoin-core/secp256k1).

## Objectives

- Provide lightweight ECDSA & Schnorr Signatures functionality
- Support simple and advanced usage, including BIP-327 and BIP-340
- Expose libsecp256k1 bindings for full control of the implementation
- Offer a familiar API design inspired by [Swift Crypto](https://github.com/apple/swift-crypto)
- Maintain automatic updates for Swift and libsecp256k1
- Ensure availability for Linux and Apple platform ecosystems

## Installation

This package uses Swift Package Manager. To add it to your project:

> [!WARNING]  
> These APIs are not considered stable and may change with any update. Specify a version using `exact:` to avoid breaking changes.

### Using Xcode

1. Go to `File > Add Packages...`
2. Enter the package URL: `https://github.com/21-DOT-DEV/swift-secp256k1`
3. Select the desired version

### Using Package.swift (Recommended)

Add the following to your `Package.swift` file:

```swift
.package(name: "swift-secp256k1", url: "https://github.com/21-DOT-DEV/swift-secp256k1", from: "0.21.1"),
```

Then, include `P256K` as a dependency in your target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "P256K", package: "swift-secp256k1")
]),
```

### Using CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'swift-secp256k1', '0.21.1'
```

### Try it out

Use [SPI Playgrounds app](https://swiftpackageindex.com/try-in-a-playground):

```swift
arena 21-DOT-DEV/swift-secp256k1
```

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
let signature = try! privateKey.signature(for: messageData)

// DER signature
print(try! signature.derRepresentation.base64EncodedString())
```

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

### Tweak

```swift
let privateKey = try! P256K.Signing.PrivateKey()

// Adding a tweak to the private key and public key
let tweak = try! "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6".bytes
let tweakedPrivateKey = try! privateKey.add(tweak)
let tweakedPublicKeyKey = try! privateKey.publicKey.add(tweak)
```

### Elliptic Curve Diffie Hellman

```swift
let privateKey = try! P256K.KeyAgreement.PrivateKey()
let publicKey = try! P256K.KeyAgreement.PrivateKey().publicKey

// Create a compressed shared secret with a private key from only a public key
let sharedSecret = try! privateKey.sharedSecretFromKeyAgreement(with: publicKey, format: .compressed)

// By default, libsecp256k1 hashes the x-coordinate with version information.
let symmetricKey = SHA256.hash(data: sharedSecret.bytes)
```

### Silent Payments Scheme

```swift
let privateSign1 = try! P256K.Signing.PrivateKey()
let privateSign2 = try! P256K.Signing.PrivateKey()

let privateKey1 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign1.dataRepresentation)
let privateKey2 = try! P256K.KeyAgreement.PrivateKey(dataRepresentation: privateSign2.dataRepresentation)

let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: publicKey1)

let symmetricKey1 = SHA256.hash(data: sharedSecret1.bytes)
let symmetricKey2 = SHA256.hash(data: sharedSecret2.bytes)

let sharedSecretSign1 = try! P256K.Signing.PrivateKey(dataRepresentation: symmetricKey1.bytes)
let sharedSecretSign2 = try! P256K.Signing.PrivateKey(dataRepresentation: symmetricKey2.bytes)

// Spendable Silent Payment private key
let privateTweak1 = try! sharedSecretSign1.add(xonly: privateSign1.publicKey.xonly.bytes)
let publicTweak2 = try! sharedSecretSign2.publicKey.add(privateSign1.publicKey.xonly.bytes)

let schnorrPrivate = try! P256K.Schnorr.PrivateKey(dataRepresentation: sharedSecretSign2.dataRepresentation)
// Payable Silent Payment public key
let xonlyTweak2 = try! schnorrPrivate.xonly.add(privateSign1.publicKey.xonly.bytes)
```

### Recovery

```swift
let privateKey = try! P256K.Recovery.PrivateKey()
let messageData = "We're all Satoshi.".data(using: .utf8)!

// Create a recoverable ECDSA signature
let recoverySignature = try! privateKey.signature(for: messageData)

// Recover an ECDSA public key from a signature
let publicKey = try! P256K.Recovery.PublicKey(messageData, signature: recoverySignature)

// Convert a recoverable signature into a normal signature
let signature = try! recoverySignature.normalize
```

### Combine Public Keys

```swift
let privateKey = try! P256K.Signing.PrivateKey()
let publicKey = try! P256K.Signing.PrivateKey().public

// The Combine API arguments are an array of PublicKey objects and an optional format 
publicKey.combine([privateKey.publicKey], format: .uncompressed)
```

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

### MuSig2

```swift
// Initialize private keys for two signers
let firstPrivateKey = try P256K.Schnorr.PrivateKey()
let secondPrivateKey = try P256K.Schnorr.PrivateKey()

// Aggregate the public keys using MuSig
let aggregateKey = try P256K.MuSig.aggregate([firstPrivateKey.publicKey, secondPrivateKey.publicKey])

// Message to be signed
let message = "Vires in Numeris.".data(using: .utf8)!
let messageHash = SHA256.hash(data: message)

// Generate nonces for each signer
let firstNonce = try P256K.MuSig.Nonce.generate(
    secretKey: firstPrivateKey,
    publicKey: firstPrivateKey.publicKey,
    msg32: Array(messageHash)
)

let secondNonce = try P256K.MuSig.Nonce.generate(
    secretKey: secondPrivateKey,
    publicKey: secondPrivateKey.publicKey,
    msg32: Array(messageHash)
)

// Aggregate nonces
let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [firstNonce.pubnonce, secondNonce.pubnonce])

// Create partial signatures
let firstPartialSignature = try firstPrivateKey.partialSignature(
    for: messageHash,
    pubnonce: firstNonce.pubnonce,
    secureNonce: firstNonce.secnonce,
    publicNonceAggregate: aggregateNonce,
    publicKeyAggregate: aggregateKey
)

let secondPartialSignature = try secondPrivateKey.partialSignature(
    for: messageHash,
    pubnonce: secondNonce.pubnonce,
    secureNonce: secondNonce.secnonce,
    publicNonceAggregate: aggregateNonce,
    publicKeyAggregate: aggregateKey
)

// Aggregate partial signatures into a full signature
let aggregateSignature = try P256K.MuSig.aggregateSignatures([firstPartialSignature, secondPartialSignature])

// Verify the aggregate signature
let isValid = aggregateKey.isValidSignature(
    firstPartialSignature,
    publicKey: firstPrivateKey.publicKey,
    nonce: firstNonce.pubnonce,
    for: messageHash
)

print("Is valid MuSig signature: \(isValid)")
```