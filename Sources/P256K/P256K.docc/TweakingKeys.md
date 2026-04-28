# Tweaking Keys

@Metadata {
    @TitleHeading("How-to Guide")
}

Derive child keys using additive and multiplicative tweaks for BIP-32 key derivation and BIP-341 Taproot.

## Overview

Tweaking combines an existing key pair with a scalar offset to produce a new key pair while preserving the linear relationship between private and public halves. This is the algebraic foundation of [BIP-32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) hierarchical deterministic wallets and [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) Taproot output-key derivation. The sections below cover each signature family's tweak API.

### ECDSA Key Tweaking

Tweak an ECDSA private key by adding a scalar, producing a new key pair. This is the basis of BIP-32 hierarchical deterministic key derivation:

```swift
let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: keyBytes)
let tweak = SHA256.hash(data: someData)

// Additive tweak: newKey = privateKey + tweak (mod n)
let tweakedPrivateKey = try privateKey.add(Array(tweak))

// Multiplicative tweak: newKey = privateKey * tweak (mod n)
let tweakedByMul = try privateKey.multiply(Array(tweak))
```

Public keys can be tweaked directly without the private key:

```swift
// Additive: newPubKey = pubKey + tweak * G
let tweakedPublicKey = try publicKey.add(Array(tweak))

// Multiplicative: newPubKey = tweak * pubKey
let tweakedByMul = try publicKey.multiply(Array(tweak))
```

### Schnorr Key Tweaking

Schnorr keys use x-only (32-byte) public keys with implicit even parity. Tweaking a Schnorr key handles the parity adjustment automatically:

```swift
let schnorrKey = try P256K.Schnorr.PrivateKey(dataRepresentation: keyBytes)
let tweak = SHA256.hash(data: someData)

let tweakedKey = try schnorrKey.add(Array(tweak))
```

X-only public keys can also be tweaked directly:

```swift
let tweakedXonly = try schnorrKey.xonly.add(Array(tweak))
```

### Taproot Output Key Construction

BIP-341 Taproot derives an output key from an internal key using a tagged hash tweak. For a key-path-only output (no script tree):

```swift
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

For outputs with a script tree, include the Merkle root in the tweak:

```swift
// H_TapTweak(internalKey || merkleRoot)
let tweakHash = SHA256.taggedHash(
    tag: "TapTweak".data(using: .utf8)!,
    data: Data(internalKey.bytes) + merkleRoot
)
let outputKey = try internalKey.add(Array(tweakHash))
```

### MuSig Aggregate Key Tweaking

Aggregated MuSig2 keys can be tweaked for BIP-32 derivation or Taproot:

```swift
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
