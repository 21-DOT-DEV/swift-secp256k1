# MuSig2 Multi-Signatures

@Metadata {
    @TitleHeading("How-to Guide")
}

Create a single Schnorr signature from multiple independent signers using the BIP-327 MuSig2 protocol.

## Overview

MuSig2 allows multiple parties to produce a single compact Schnorr signature that verifies against an aggregated public key. No observer can distinguish a MuSig2 signature from a regular Schnorr signature. This guide walks through the complete signing protocol.

### Aggregating Public Keys

Each signer generates a Schnorr key pair. The public keys are then aggregated into a single ``P256K/MuSig/PublicKey``:

```swift
import P256K

let alice = try P256K.Schnorr.PrivateKey()
let bob = try P256K.Schnorr.PrivateKey()
let carol = try P256K.Schnorr.PrivateKey()

let aggregate = try P256K.MuSig.aggregate([
    alice.publicKey, bob.publicKey, carol.publicKey
])
```

Key aggregation is order-independent -- the same aggregate is produced regardless of the order the public keys are provided.

### Generating Nonces

Each signer independently generates a nonce pair. The `generate` function returns a ``P256K/Schnorr/SecureNonce`` (the secret nonce) and a public nonce:

```swift
let message = "Hello, MuSig!".data(using: .utf8)!
let messageHash = SHA256.hash(data: message)

let aliceNonce = try P256K.MuSig.Nonce.generate(
    secretKey: alice,
    publicKey: alice.publicKey,
    msg32: Array(messageHash)
)
```

> Warning: A `SecureNonce` is `~Copyable` by design. Using the same secret nonce in two different signing sessions **leaks the signing key**. The type system prevents accidental reuse.

### Aggregating Nonces

Each signer shares their public nonce. Once all public nonces are collected, aggregate them:

```swift
let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [
    aliceNonce.pubnonce, bobNonce.pubnonce, carolNonce.pubnonce
])
```

### Creating Partial Signatures

Each signer creates a partial signature using their private key, their secret nonce, and the aggregated nonce:

```swift
let alicePartial = try alice.partialSignature(
    for: messageHash,
    pubnonce: aliceNonce.pubnonce,
    secureNonce: aliceNonce.secnonce,
    publicNonceAggregate: aggregateNonce,
    publicKeyAggregate: aggregate
)
```

### Aggregating Signatures

Once all partial signatures are collected, aggregate them into the final Schnorr signature:

```swift
let finalSignature = try P256K.MuSig.aggregateSignatures([
    alicePartial, bobPartial, carolPartial
])
```

### Verification

The final signature verifies against the aggregated x-only public key, just like any BIP-340 Schnorr signature:

```swift
let isValid = aggregate.xonly.isValidSignature(finalSignature, for: messageHash)
```

You can also verify individual partial signatures before aggregation:

```swift
let isPartialValid = aggregate.isValidSignature(
    alicePartial,
    publicKey: alice.publicKey,
    nonce: aliceNonce.pubnonce,
    for: messageHash
)
```
