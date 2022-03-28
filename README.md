[![Build Status](https://app.bitrise.io/app/18c18db60fc4fddf/status.svg?token=nczB4mTPCrlTfDQnXH_8Pw&branch=main)](https://app.bitrise.io/app/18c18db60fc4fddf) [![Build Status](https://app.bitrise.io/app/f1bbbdfeff08cd5c/status.svg?token=ONB3exCALsB-_ayi6KsXFQ&branch=main)](https://app.bitrise.io/app/f1bbbdfeff08cd5c) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift)

# 🔐 secp256k1.swift
Swift package with elliptic curve public key, ECDSA, Schnorr Signatures for Bitcoin and bindings from [libsecp256k1](https://github.com/bitcoin-core/secp256k1).


# Objectives

Long-term goals are:
 - Lightweight ECDSA & Schnorr Signatures functionality
 - Built for simple or advance usage with things like BIP340
 - Exposed C bindings to take full control of the secp256k1 implementation
 - Familiar API design by modeling after [Swift Crypto](https://github.com/apple/swift-crypto)
 - Automatic updates for Swift and libsecp256k1
 - Availability for Linux and Apple platform ecosystems


# Example Usage

## ECDSA

```swift
import secp256k1

//  Private key
let privateBytes = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".bytes
let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateBytes)

//  Public key
print(String(byteArray: privateKey.publicKey.rawRepresentation))

// ECDSA
let messageData = "We're all Satoshi.".data(using: .utf8)!
let signature = try! privateKey.ecdsa.signature(for: messageData)

//  DER signature
print(try! signature.derRepresentation.base64EncodedString())
```

## Schnorr

```swift
let privateKeyBytes = try! "C90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B14E5C9".byteArray()
let privateKey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)

// Extra params for custom signing
var auxRand = try! "C87AA53824B4D7AE2EB035A2B5BBBCCC080E76CDC6D1692C4B0B62D798E6D906".byteArray()
var messageDigest = try! "7E2D58D8B3BCDF1ABADEC7829054F90DDA9805AAB56C77333024B9D0A508B75C".byteArray()

// API allows for signing variable length messages
let signature = try! privateKey.schnorr.signature(message: &messageDigest, auxiliaryRand: &auxRand)
```


# Getting Started

In your `Package.swift`:

```swift
.package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", .upToNextMajor(from: "0.5.0"))
```

Try in a [playground](spi-playgrounds://open?dependencies=GigaBitcoin/secp256k1.swift) using the [SPI Playgrounds app](https://swiftpackageindex.com/try-in-a-playground) or 🏟 [Arena](https://github.com/finestructure/arena)

```swift
arena GigaBitcoin/secp256k1.swift
```


# Danger
These APIs should not be considered stable and may change at any time, libsecp256k1 is still experimental and has not been formally released.

