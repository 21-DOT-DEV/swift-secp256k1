# MuSig2 Multi-Signatures

@Metadata {
    @TitleHeading("How-to Guide")
}

Combine partial contributions from a fixed group of co-signers into a single Schnorr signature using the [BIP-327][bip-327] MuSig2 protocol.

## Overview

MuSig2 ([BIP-327][bip-327]; originally introduced by [Nick, Ruffing, and Seurin (CRYPTO 2021)][musig2-paper]) lets a fixed group of parties produce a single compact [BIP-340][bip-340] Schnorr signature that verifies against one aggregate group key. The result is indistinguishable on chain from a regular Schnorr signature — a Taproot spend using MuSig2 leaves the same fee footprint, the same witness size, and the same privacy properties as a single-key spend.

The protocol runs in two communication rounds. The first round exchanges fresh per-session commitments so that every participant binds themselves to a unique randomness draw before learning anyone else's contribution; the second round exchanges partial responses keyed to the agreed-upon message. The two-round split is what makes the scheme provably secure under the OMDL assumption ([Nick, Ruffing, and Seurin, §5][musig2-paper]) — even if some co-signers are dishonest, they cannot extract the others' long-term keys. The sections below walk through every step end-to-end.

### Aggregating Keys

Each party derives a Schnorr key pair. Their verifying halves combine into a single ``P256K/MuSig/PublicKey``:

```swift
import P256K

let alice = try P256K.Schnorr.PrivateKey()
let bob = try P256K.Schnorr.PrivateKey()
let carol = try P256K.Schnorr.PrivateKey()

let aggregate = try P256K.MuSig.aggregate([
    alice.publicKey, bob.publicKey, carol.publicKey
])
```

Key aggregation is order-independent — the same aggregate is produced regardless of the order in which the inputs are provided.

### Round 1: Generating Nonces

Each party independently draws a fresh nonce pair for the upcoming session. The `generate` function returns a ``P256K/Schnorr/SecureNonce`` (kept private to the caller) and a sharable pubnonce value:

```swift
import Foundation
import P256K

let message = "Hello, MuSig!".data(using: .utf8)!
let messageHash = SHA256.hash(data: message)

let aliceNonce = try P256K.MuSig.Nonce.generate(
    secretKey: alice,
    publicKey: alice.publicKey,
    msg32: Array(messageHash)
)
```

> Warning: A `SecureNonce` is `~Copyable` by design. Reusing one across two signing sessions **leaks the long-term private key**. The type system surfaces accidental reuse as a compile-time error.

### Round 1 (continued): Aggregating Pubnonces

Each party broadcasts their sharable pubnonce. Once every contribution has been collected, aggregate them:

```swift
import P256K

let aggregateNonce = try P256K.MuSig.Nonce(aggregating: [
    aliceNonce.pubnonce, bobNonce.pubnonce, carolNonce.pubnonce
])
```

### Round 2: Partial Signatures

Each party produces a partial signature using their long-term private key, their own secret half from the prior round, and the aggregated commitment:

```swift
import P256K

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
import P256K

let finalSignature = try P256K.MuSig.aggregateSignatures([
    alicePartial, bobPartial, carolPartial
])
```

### Verification

The final signature verifies against the aggregated x-only verifying key, just like any [BIP-340][bip-340] Schnorr signature:

```swift
import P256K

let isValid = aggregate.xonly.isValidSignature(finalSignature, for: messageHash)
```

You can also verify individual partial signatures before aggregation:

```swift
import P256K

let isPartialValid = aggregate.isValidSignature(
    alicePartial,
    publicKey: alice.publicKey,
    nonce: aliceNonce.pubnonce,
    for: messageHash
)
```

## See Also

- <doc:WorkingWithKeys>
- <doc:SilentPayments>
- ``P256K/Schnorr``
- ``P256K/MuSig``

[bip-327]: https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki
[bip-340]: https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki
[musig2-paper]: https://eprint.iacr.org/2020/1261
