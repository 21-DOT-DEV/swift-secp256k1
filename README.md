# 🔐 secp256k1.swift
Swift bindings library for ECDSA signatures and secret/public key operations using the [libsecp256k1](https://github.com/bitcoin-core/secp256k1) C library.

# Objective
This library aims to be a lightweight dependency for clients and wrapper libraries to include ECDSA functionality.

This package targets the default git branch of secp256k1 and aims to stay up-to-date without using a mirrored repository.

# Getting Started

In your `Package.swift`:

```swift
dependencies: [
    .package(name: "secp256k1", url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.0.1"),
]
```

Currently, this Swift package only provides a single product library built using the `libsecp256k1` [basic config](https://github.com/bitcoin-core/secp256k1/blob/master/src/basic-config.h).

# Usage

```swift
import secp256k1

// Initialize context
let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!

// Setup private and public key variables
var pubkeyLen = 65
var cPubkey = secp256k1_pubkey()
var pubkey = [UInt8](repeating: 0, count: pubkeyLen)
let privkey: [UInt8] = [0,1,0,0,1,0,1,0,1,0,1,0,1,0,0,1,1,1,0,0,1,0,0,1,1,0,0,1,0,0,32,0]

// Verify the context and keys are setup correctly
guard secp256k1_context_randomize(context, privkey) == 1,
    secp256k1_ec_pubkey_create(context, &cPubkey, privkey) == 1,
    secp256k1_ec_pubkey_serialize(context, &pubkey, &pubkeyLen, &cPubkey, UInt32(SECP256K1_EC_UNCOMPRESSED)) == 1 else {
    // Destory context after creation
    secp256k1_context_destroy(context)
    return
}

print(pubkey) //  [4,96,104, 212, 128, 165, 213, 207, 134, 132, 22, 247, 38, 114, 82, 108, 77, 43, 6, 56, ... ]

// Destory context after creation
secp256k1_context_destroy(context)
```

# Contributing

To start developing, clone the package from github, and from the root directory, run the following commands:

```shell
git submodule update --init
swift build
```

Tests can be run by calling `swift test`

# Danger
These APIs should not be considered stable and may change at any time. libsecp256k1 is still experimental and has not been formally released.

