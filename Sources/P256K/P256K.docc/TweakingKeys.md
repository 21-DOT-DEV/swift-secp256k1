# Tweaking Keys

@Metadata {
    @TitleHeading("How-to Guide")
}

Derive child secp256k1 keys with ``P256K``'s additive and multiplicative scalar offsets — the primitive behind BIP-32 hierarchical derivation, BIP-341 Taproot output construction, BIP-327 MuSig2 key aggregation, and BIP-352 Silent Payments destination derivation.

## Overview

Tweaking combines an existing key pair with a scalar offset to produce a new key pair while preserving the linear relationship between private and public halves. Concretely, if `(d, P)` is a key pair with `P = d·G` and `t` is a 32-byte scalar offset, the additive operation produces `(d + t mod n, P + t·G)` and the multiplicative operation produces `(d·t mod n, t·P)`. Either form can be performed on the public half alone — a property that makes hardware-wallet-style "watch-only" child-key generation possible without exposing the private half.

This algebra is the foundation of [BIP-32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) hierarchical deterministic wallets (which chain `add(_:)` calls under a parent extended key) and [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) Taproot output-key construction (which commits a script tree or a key-path-only marker into a single x-only adjustment applied to an internal key). The same primitives also appear in [BIP-352 Silent Payments](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki) (where the destination output is built by adding an ECDH shared secret to the recipient's spend key) and in BIP-327 MuSig2's key aggregation step. The sections below cover each signature family's offset API.

### ECDSA Key Tweaking

Apply an additive scalar offset to an ECDSA private key, producing a new key pair. This is the basis of BIP-32 hierarchical deterministic key chaining:

```swift
import P256K

let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: keyBytes)
let tweak = SHA256.hash(data: someData)

// Additive tweak: newKey = privateKey + tweak (mod n)
let tweakedPrivateKey = try privateKey.add(Array(tweak))

// Multiplicative tweak: newKey = privateKey * tweak (mod n)
let tweakedByMul = try privateKey.multiply(Array(tweak))
```

Public keys can be tweaked directly without the private key:

```swift
import P256K

// Additive: newPubKey = pubKey + tweak * G
let tweakedPublicKey = try publicKey.add(Array(tweak))

// Multiplicative: newPubKey = tweak * pubKey
let tweakedByMul = try publicKey.multiply(Array(tweak))
```

### Schnorr Key Tweaking

Schnorr keys use x-only (32-byte) public keys with implicit even parity. The Schnorr API handles the parity adjustment automatically when an offset is applied:

```swift
import P256K

let schnorrKey = try P256K.Schnorr.PrivateKey(dataRepresentation: keyBytes)
let tweak = SHA256.hash(data: someData)

let tweakedKey = try schnorrKey.add(Array(tweak))
```

X-only public keys can also be tweaked directly:

```swift
import P256K

let tweakedXonly = try schnorrKey.xonly.add(Array(tweak))
```

### Taproot Output Key Construction

BIP-341 Taproot computes an output key from an internal key using a tagged hash as the offset. For a key-path-only output (no script tree):

```swift
import Foundation
import P256K

let internalKey = try P256K.Schnorr.PrivateKey(
    dataRepresentation: keyBytes
).xonly

// Compute the taptweak: H_TapTweak(internalKey)
let tweakHash = SHA256.taggedHash(
    tag: "TapTweak".data(using: .utf8)!,
    data: Data(internalKey.bytes)
)

// Derive the output key: internalKey + tweakHash
let outputKey = try internalKey.add(Array(tweakHash))
```

For outputs with a script tree, include the Merkle root in the offset:

```swift
import Foundation
import P256K

// H_TapTweak(internalKey || merkleRoot)
let tweakHash = SHA256.taggedHash(
    tag: "TapTweak".data(using: .utf8)!,
    data: Data(internalKey.bytes) + merkleRoot
)
let outputKey = try internalKey.add(Array(tweakHash))
```

### MuSig Aggregate Key Tweaking

Aggregated MuSig2 keys accept the same additive offsets for BIP-32 chaining or Taproot construction:

```swift
import P256K

let aggregate = try P256K.MuSig.aggregate(publicKeys)

// BIP-32 style: tweak the full public key
let derivedKey = try aggregate.add(Array(tweak))

// Taproot: tweak the x-only aggregate key
let taprootOutput = try aggregate.xonly.add(Array(tweakHash))
```

## See Also

- <doc:MuSig2MultiSignatures>
- ``P256K/Schnorr``
- ``P256K/Signing``
