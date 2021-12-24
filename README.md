[![Build Status](https://app.bitrise.io/app/18c18db60fc4fddf/status.svg?token=nczB4mTPCrlTfDQnXH_8Pw&branch=main)](https://app.bitrise.io/app/18c18db60fc4fddf) [![Build Status](https://app.bitrise.io/app/f1bbbdfeff08cd5c/status.svg?token=ONB3exCALsB-_ayi6KsXFQ&branch=main)](https://app.bitrise.io/app/f1bbbdfeff08cd5c) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift)

# 🔐 secp256k1.swift
Swift library plus bindings for ECDSA signatures and secret/public key operations using [libsecp256k1](https://github.com/bitcoin-core/secp256k1).


# Objectives

Long-term goals are:
 - Lightweight ECDSA functionality
 - APIs modeled after [Swift Crypto](https://github.com/apple/swift-crypto)
 - Up-to-date with future versions of Swift and libsecp256k1
 - Consistent across multiple platforms


# Usage

```swift
import secp256k1

let privateKeyBytes = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".byteArray()
let privatekey = try! secp256k1.Signing.PrivateKey(rawRepresentation: privateKeyBytes)

print(String(byteArray: privatekey.publicKey.rawRepresentation)) //  02734b3511150a60fc8cac329cd5ff804555728740f2f2e98bc4242135ef5d5e4e

let messageData = "Hello World!".data(using: .utf8)!
let signature = try! privateKey.signature(for: messageData)

print(try! signature.derRepresentation().base64EncodedString()) //  MEUCID8JELjY/ua6MSRKh/VtO7q2YAgpPOfqlwi05Lj/gC1jAiEAiJ1r82jIVc9G/2kooLnzIbg04ky/leocdLn9XE1LvwI=
```


# Getting Started

In your `Package.swift`:

```swift
    .package(
        name: "secp256k1",
        url: "https://github.com/GigaBitcoin/secp256k1.swift.git",
        .upToNextMajor(from: "0.3.4")
    )
```


# Danger
These APIs should not be considered stable and may change at any time. libsecp256k1 is still experimental and has not been formally released.

