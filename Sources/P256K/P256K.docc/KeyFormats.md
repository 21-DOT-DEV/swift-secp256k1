# Key Formats

@Metadata {
    @TitleHeading("Explanation")
}

Understand why secp256k1 has multiple key representations — compressed, uncompressed, and x-only — and how ``P256K`` exposes each one for Bitcoin, Lightning, Nostr, and Taproot.

## Overview

secp256k1 public keys can be serialized in four distinct formats: compressed, uncompressed, x-only, and the internal libsecp256k1 `secp256k1_pubkey` structure. Each has a specific use case and interoperability story. The compressed and uncompressed encodings are specified in [SEC 1: Elliptic Curve Cryptography v2 §2.3.3](https://www.secg.org/sec1-v2.pdf); x-only encoding was introduced by [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) for Schnorr signatures. This article explains the mathematical relationship between them, which format each Bitcoin / Lightning / Nostr protocol expects, and how to pick one for your application.

### Elliptic Curve Points

A secp256k1 public key is a point `(x, y)` on the elliptic curve. Both coordinates are 256-bit integers. Since the curve equation `y^2 = x^3 + 7` has exactly two solutions for each `x` value (one even, one odd), you only need the `x` coordinate plus a single bit to identify the point uniquely.

### Compressed Keys

The **compressed** form (33 octets) stores the x-coordinate with a one-octet prefix indicating the parity of y:

- `0x02` -- y is even
- `0x03` -- y is odd

This is the default format in P256K and the standard for Bitcoin since 2012:

```swift
import P256K

let key = try P256K.Signing.PrivateKey()  // compressed by default
key.publicKey.dataRepresentation.count    // 33
key.publicKey.format                      // .compressed
```

### Uncompressed Keys

The **uncompressed** form (65 octets) stores both coordinates with a `0x04` prefix:

```swift
import P256K

let key = try P256K.Signing.PrivateKey(format: .uncompressed)
key.publicKey.dataRepresentation.count    // 65
key.publicKey.format                      // .uncompressed
```

Uncompressed keys are rarely used in modern Bitcoin but appear in legacy transactions and some non-Bitcoin protocols. P256K supports them for interoperability.

### X-Only Keys

[BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) introduced **x-only** public keys for Schnorr signatures. These are the bare 32-octet x-coordinate with no prefix. The y-coordinate is implicitly defined as the **even** value.

```swift
import P256K

let schnorrKey = try P256K.Schnorr.PrivateKey()
schnorrKey.xonly.bytes.count  // 32
```

X-only keys save one octet per public key and simplify the Schnorr verification equation. They are used in:
- [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) Schnorr signatures
- [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) Taproot output keys
- [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki) MuSig2 aggregate keys

### Key Parity

The `parity` property on x-only key types indicates whether the full point's y-coordinate is odd (`true`) or even (`false`).

For ``P256K/Signing/XonlyKey``, parity is derived from the original full public key and can be either value. For ``P256K/Schnorr/XonlyKey``, parity is implicitly even and always returns `false`.

Parity matters when:
- **Taproot tweak verification** -- You need to know whether the internal key was negated during output key derivation.
- **MuSig2 key aggregation** -- The aggregate key's parity affects how partial signatures are combined.

### The Format Enum

``P256K/Format`` controls key serialization:

| Case | Value | Length (bytes) | C Flag |
|------|-------|----------------|--------|
| `.compressed` | `0x0202` | 33 | `SECP256K1_EC_COMPRESSED` |
| `.uncompressed` | `0x0604` | 65 | `SECP256K1_EC_UNCOMPRESSED` |

The `rawValue` maps directly to the flag passed to the underlying C library's serialization functions.

### Choosing a Format

- **Default to compressed** for all new applications. It is the standard for Bitcoin, smaller, and fully supported.
- **Use x-only** when working with Schnorr signatures, Taproot, or MuSig2.
- **Use uncompressed** only when required by a legacy protocol or for compatibility with systems that expect the `0x04` prefix.

## See Also

- <doc:SerializingKeys>
- <doc:GettingStarted>
- ``P256K/Format``
