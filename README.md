[![Build Status](https://app.bitrise.io/app/18c18db60fc4fddf/status.svg?token=nczB4mTPCrlTfDQnXH_8Pw&branch=main)](https://app.bitrise.io/app/18c18db60fc4fddf) [![Build Status](https://app.bitrise.io/app/f1bbbdfeff08cd5c/status.svg?token=ONB3exCALsB-_ayi6KsXFQ&branch=main)](https://app.bitrise.io/app/f1bbbdfeff08cd5c) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift)

# 🔐 secp256k1.swift
Swift package with elliptic curve public key cryptography, ECDSA, Schnorr Signatures for Bitcoin and C bindings from [libsecp256k1](https://github.com/bitcoin-core/secp256k1).


# Objectives

Long-term goals are:
 - Lightweight ECDSA & Schnorr Signatures functionality
 - Built for simple or advance usage with things like BIP340
 - Exposed C bindings to take full control of the secp256k1 implementation
 - Familiar API design by modeling after [Swift Crypto](https://github.com/apple/swift-crypto)
 - Automatic updates for Swift and libsecp256k1
 - Availability for Linux and Apple platform ecosystems


# Getting Started

This repository primarily uses Swift package manager as its build tool, so we recommend using that as well. Xcode comes with [built-in support](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) for Swift packages. From the menu bar, goto: `File > Add Packages...` If you manage packages via a `Package.swift` file, simply add `secp256k1.swift` as a dependencies' clause in your Swift manifest:

```swift
.package(name: "secp256k1.swift", url: "https://github.com/GigaBitcoin/secp256k1.swift.git", exact: "0.15.0"),
```

Include `secp256k1` as a dependency for your executable target:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "secp256k1", package: "secp256k1.swift")
]),
```

Try in a [playground](spi-playgrounds://open?dependencies=GigaBitcoin/secp256k1.swift) using the [SPI Playgrounds app](https://swiftpackageindex.com/try-in-a-playground) or 🏟 [Arena](https://github.com/finestructure/arena)

```swift
arena GigaBitcoin/secp256k1.swift
```


# Example Usage

## ECDSA

```swift
import secp256k1

//  Private key
let privateBytes = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes
let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateBytes)

//  Public key
print(String(bytes: privateKey.publicKey.rawRepresentation))

// ECDSA
let messageData = "We're all Satoshi.".data(using: .utf8)!
let signature = try! privateKey.signature(for: messageData)

//  DER signature
print(try! signature.derRepresentation.base64EncodedString())
```

## Schnorr

```swift
// Strict BIP340 mode is disabled by default for Schnorr signatures with variable length messages
let privateKey = try! secp256k1.Schnorr.PrivateKey()

// Extra params for custom signing
var auxRand = try! "C87AA53824B4D7AE2EB035A2B5BBBCCC080E76CDC6D1692C4B0B62D798E6D906".bytes
var messageDigest = try! "7E2D58D8B3BCDF1ABADEC7829054F90DDA9805AAB56C77333024B9D0A508B75C".bytes

// API allows for signing variable length messages
let signature = try! privateKey.signature(message: &messageDigest, auxiliaryRand: &auxRand)
```

## Tweak

```swift
let privateKey = try! secp256k1.Signing.PrivateKey()

// Adding a tweak to the private key and public key
let tweak = try! "5f0da318c6e02f653a789950e55756ade9f194e1ec228d7f368de1bd821322b6".bytes
let tweakedPrivateKey = try! privateKey.add(tweak)
let tweakedPublicKeyKey = try! privateKey.publicKey.add(tweak)
```

## Elliptic Curve Diffie Hellman

```swift
let privateKey = try! secp256k1.KeyAgreement.PrivateKey()
let publicKey = try! secp256k1.KeyAgreement.PrivateKey().publicKey

// Create a compressed shared secret with a private key from only a public key
let sharedSecret = try! privateKey.sharedSecretFromKeyAgreement(with: publicKey, format: .compressed)

// By default, libsecp256k1 hashes the x-coordinate with version information.
let symmetricKey = SHA256.hash(data: sharedSecret.bytes)
```

## Silent Payments Scheme

```swift
let privateSign1 = try! secp256k1.Signing.PrivateKey()
let privateSign2 = try! secp256k1.Signing.PrivateKey()

let privateKey1 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateSign1.rawRepresentation)
let privateKey2 = try! secp256k1.KeyAgreement.PrivateKey(rawRepresentation: privateSign2.rawRepresentation)

let sharedSecret1 = try! privateKey1.sharedSecretFromKeyAgreement(with: privateKey2.publicKey)
let sharedSecret2 = try! privateKey2.sharedSecretFromKeyAgreement(with: privateKey1.publicKey)

let sharedSecretSign1 = try! secp256k1.Signing.PrivateKey(rawRepresentation: sharedSecret1.bytes)
let sharedSecretSign2 = try! secp256k1.Signing.PrivateKey(rawRepresentation: sharedSecret2.bytes)

// Payable Silent Payment public key
let xonlyTweak2 = try! sharedSecretSign2.publicKey.xonly.add(privateSign1.publicKey.xonly.bytes)

// Spendable Silent Payment private key
let privateTweak1 = try! sharedSecretSign1.add(xonly: privateSign1.publicKey.xonly.bytes)
```

## Recovery

```swift
let privateKey = try! secp256k1.Recovery.PrivateKey()
let messageData = "We're all Satoshi.".data(using: .utf8)!

// Create a recoverable ECDSA signature
let recoverySignature = try! privateKey.signature(for: messageData)

// Recover an ECDSA public key from a signature
let publicKey = try! secp256k1.Recovery.PublicKey(messageData, signature: recoverySignature)

// Convert a recoverable signature into a normal signature
let signature = try! recoverySignature.normalize
```

## Combine Public Keys

```swift
let privateKey = try! secp256k1.Signing.PrivateKey()
let publicKey = try! secp256k1.Signing.PrivateKey().public

// The Combine API arguments are an array of PublicKey objects and an optional format 
publicKey.combine([privateKey.publicKey], format: .uncompressed)
```

## PEM Key Format

```swift
let privateKeyString = """
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
-----END EC PRIVATE KEY-----
"""

// Import keys generated from OpenSSL
let privateKey = try! secp256k1.Signing.PrivateKey(pemRepresentation: privateKeyString)
```


# Danger
These APIs should not be considered stable and may change at any time.

