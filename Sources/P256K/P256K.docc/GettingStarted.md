# Getting Started with secp256k1 in Swift

@Metadata {
    @TitleHeading("Article")
}

Learn how to generate keys, create ECDSA and Schnorr signatures, and perform ECDH key agreement using the P256K Swift library for the secp256k1 elliptic curve.

## Adding P256K to Your Project

Add `swift-secp256k1` as a Swift Package Manager dependency in your `Package.swift`:

```swift
// Package.swift
dependencies: [
    // Pin with exact: because the API is pre-1.0 and not yet stable.
    .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1.git", exact: "0.18.0"),
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "P256K", package: "swift-secp256k1"),
        ]
    ),
]
```

Then import the module in your Swift files:

```swift
import P256K
```

## Understanding the Context

Every cryptographic operation in P256K depends on a secp256k1 context object managed by ``P256K/Context``. The library provides a shared context via `P256K.Context.rawRepresentation` that is created and randomized automatically at process startup. You do not need to create or manage a context for standard use — the library handles this internally for every signing, verification, and key generation call.

Context randomization seeds a blinding factor that protects ECDSA signing, Schnorr signing, and public key generation against timing and power analysis attacks. ECDH key agreement uses a different kind of elliptic curve point multiplication and does not currently benefit from context randomization.

## Generating Key Pairs

To create an ECDSA key pair, initialize a ``P256K/Signing/PrivateKey``. The private key generates the associated public key on demand:

```swift
// Generate a random ECDSA key pair
let privateKey = try P256K.Signing.PrivateKey()
let publicKey = privateKey.publicKey

// Serialize the private key for storage
let privateKeyBytes = privateKey.dataRepresentation
```

To create a Schnorr key pair for BIP-340 compatible signatures, initialize a ``P256K/Schnorr/PrivateKey``. Schnorr verification uses an x-only public key:

```swift
// Generate a random Schnorr key pair (BIP-340)
let schnorrPrivateKey = try P256K.Schnorr.PrivateKey()
let xonlyPublicKey = schnorrPrivateKey.xonly
```

## Signing and Verifying with ECDSA

``P256K/Signing/PrivateKey`` signs arbitrary data directly. SHA-256 is applied internally before calling `secp256k1_ecdsa_sign`. The resulting 64-byte signature is in normalized lower-S form, which is the only form accepted by `secp256k1_ecdsa_verify`:

```swift
import Foundation

let privateKey = try P256K.Signing.PrivateKey()
let message = "Hello, secp256k1!".data(using: .utf8)!

// Sign — SHA-256 is applied internally; no try required
let signature = privateKey.signature(for: message)

// Verify — returns true if the signature is valid
let isValid = privateKey.publicKey.isValidSignature(signature, for: message)
print(isValid) // true
```

To serialize or parse a signature in DER or compact (64-byte) format:

```swift
// DER-encoded signature (variable length, ~70 bytes)
let derSignature = signature.derRepresentation

// Compact signature (always exactly 64 bytes: r || s)
let compactSignature = signature.compactRepresentation

// Round-trip from compact bytes
let parsed = try P256K.Signing.ECDSASignature(compactRepresentation: compactSignature)
```

## Signing and Verifying with Schnorr

``P256K/Schnorr/PrivateKey`` signs hash digests and produces 64-byte Schnorr signatures as defined by BIP-340. Schnorr signatures are verified using an ``P256K/Schnorr/XonlyKey``, which contains only the x-coordinate of the public key:

```swift
let schnorrKey = try P256K.Schnorr.PrivateKey()
let message = "Hello, secp256k1!".data(using: .utf8)!

// Hash the message before signing (BIP-340 uses tagged hashes in practice)
let digest = SHA256.hash(data: message)

// Sign the digest — throws on failure
let schnorrSignature = try schnorrKey.signature(for: digest)

// Verify using the x-only public key
let isValid = schnorrKey.xonly.isValidSignature(schnorrSignature, for: digest)
print(isValid) // true
```

## Performing ECDH Key Agreement

``P256K/KeyAgreement/PrivateKey`` performs Elliptic Curve Diffie-Hellman (ECDH) key agreement using `secp256k1_ecdh`. Both parties derive an identical ``SharedSecret`` from their own private key and the other party's public key, without transmitting the secret:

```swift
// Alice and Bob each generate a key pair
let alicePrivateKey = try P256K.KeyAgreement.PrivateKey()
let bobPrivateKey = try P256K.KeyAgreement.PrivateKey()

// Exchange public keys (these are safe to transmit publicly)
let alicePublicKey = alicePrivateKey.publicKey
let bobPublicKey = bobPrivateKey.publicKey

// Each party computes the same shared secret independently
let aliceSharedSecret = alicePrivateKey.sharedSecretFromKeyAgreement(with: bobPublicKey)
let bobSharedSecret = bobPrivateKey.sharedSecretFromKeyAgreement(with: alicePublicKey)

// aliceSharedSecret == bobSharedSecret
```

> Note: Context randomization does not provide side-channel protection for ECDH. The ECDH module uses a different kind of elliptic curve point multiplication that does not currently benefit from base point blinding.

## Next Steps

- **MuSig2 multi-signatures**: Use ``P256K/MuSig`` to aggregate public keys and produce a single Schnorr signature from multiple independent signers, as defined by BIP-327.
- **ECDSA key recovery**: Use ``P256K/Recovery`` to recover a public key from a recoverable ECDSA signature and recovery ID.
- **Zero-knowledge proofs**: Import the `ZKP` module for range proofs, surjection proofs, and adaptor signatures built on the `libsecp256k1-zkp` library.
