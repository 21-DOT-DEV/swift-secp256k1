# 🔐 secp256k1.swift [![Build Status](https://app.bitrise.io/app/ef44aebd8443b33b/status.svg?token=oDGzN3bMEwseXF_5MQUsTg&branch=main)](https://app.bitrise.io/app/ef44aebd8443b33b) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FGigaBitcoin%2Fsecp256k1.swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/GigaBitcoin/secp256k1.swift)
Swift bindings library for ECDSA signatures and secret/public key operations using [libsecp256k1](https://github.com/bitcoin-core/secp256k1).

# Objective
This library aims to be a lightweight dependency for clients and wrapper libraries to include ECDSA functionality.

This package is set to the default git branch of secp256k1 and aims to stay up-to-date without using a mirrored repository. An extra module is available for convenience functionality.

# Getting Started

In your `Package.swift`:

```swift
dependencies: [
    .package(
        name: "secp256k1",
        url: "https://github.com/GigaBitcoin/secp256k1.swift.git",
        from: "0.1.0"
    ),
]
```

Currently, this Swift package only provides a single product library built using the `libsecp256k1` [basic config](https://github.com/bitcoin-core/secp256k1/blob/master/src/basic-config.h).

# Usage

```swift
import secp256k1
import secp256k1_utils

// Initialize context
let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

// Setup private and public key variables
var pubkeyLen = 33
var cPubkey = secp256k1_pubkey()
var pubkey = [UInt8](repeating: 0, count: pubkeyLen)
let privkey = try! "14E4A74438858920D8A35FB2D88677580B6A2EE9BE4E711AE34EC6B396D87B5C".byteArray()

// Verify the context and keys are setup correctly
guard secp256k1_context_randomize(context, privkey) == 1,
    secp256k1_ec_pubkey_create(context, &cPubkey, privkey) == 1,
    secp256k1_ec_pubkey_serialize(context, &pubkey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_COMPRESSED)) == 1 else {
    // Destory context after creation
    secp256k1_context_destroy(context)
    return
}

print(String(byteArray: pubKey)) //  02734b3511150a60fc8cac329cd5ff804555728740f2f2e98bc4242135ef5d5e4e

// Destory context after creation
secp256k1_context_destroy(context)
```

# Contributing

To start developing, clone the package from github, and from the root directory, run the following commands:

```shell
git clone --recurse-submodules https://github.com/GigaBitcoin/secp256k1.swift
cd secp256k1.swift
swift build
```

Tests can be run by calling `swift test`

# Danger
These APIs should not be considered stable and may change at any time. libsecp256k1 is still experimental and has not been formally released.

