# Working with Keys

@Metadata {
    @TitleHeading("How-To Guide")
}

Encode ``P256K`` secp256k1 keys in raw and x-only forms, import them from PEM and DER, and derive child keys via additive or multiplicative tweaks — the foundations under Bitcoin wallet storage, Lightning interop, Nostr key handling, BIP-32 derivation, BIP-341 Taproot output construction, and BIP-327 MuSig2 aggregation.

## Overview

You arrived with a key in hand — a ``P256K/Signing/PrivateKey``, a ``P256K/Schnorr/PrivateKey``, an x-only public key from a Bitcoin output, or a reconstructed public key. Two adjacent operations come up next: moving the key between encodings (exporting to raw or x-only bytes, importing from PEM or DER), and deriving new keys from it (BIP-32 child keys, Taproot output keys, MuSig2 aggregate outputs). Both depend on the same small set of representations the curve admits, so this article covers them together.

> Important: The secp256k1 curve used here is distinct from NIST P-256 (which Apple CryptoKit exposes as `P256`). ``P256K`` wraps [Bitcoin Core's `libsecp256k1`][libsecp256k1] and does not interoperate with `P256` keys, signatures, or shared secrets. See <doc:CryptoKitP256AndSecp256k1> for the CryptoKit-to-`P256K` mapping.

> Note: All operations below run against the shared ``P256K/Context`` initialized once at process startup, providing base-point blinding for signing and key generation. No per-call context setup is required — see <doc:GettingStarted> for the full context story.

### Key representations at a glance

secp256k1 public keys serialize in three operational forms because each Bitcoin, Lightning, or Nostr protocol commits to a specific on-the-wire layout. The curve equation `y² = x³ + 7` has exactly two solutions for any valid `x`, so the full point `(x, y)` can be reconstructed from `x` plus a single parity bit — the property that makes compression possible. The three forms surfaced by ``P256K/Format`` and the BIP-340 x-only encoding are:

| Form | Length | Prefix | Where it appears |
|---|---|---|---|
| Compressed | 33 bytes | `0x02` (even y) / `0x03` (odd y) | Default since 2012; Bitcoin script, Lightning gossip, Nostr `npub` |
| Uncompressed | 65 bytes | `0x04` | Legacy transactions, some non-Bitcoin protocols |
| X-only | 32 bytes | none | BIP-340 Schnorr, BIP-341 Taproot output keys, BIP-327 MuSig2 aggregates (links in Standards reference below) |

Private keys, by contrast, are always a 32-byte scalar in the curve's prime-order subgroup — there is no compressed/uncompressed distinction on the private side. The compressed and uncompressed point encodings are defined in SEC 1: Elliptic Curve Cryptography v2 §2.3.3; x-only encoding was introduced by BIP-340 for Schnorr signatures. The Standards reference subsection at the end of this article lists the full citations.

Parity matters when an x-only key participates in derivation. Both ``P256K/Signing/XonlyKey`` and ``P256K/Schnorr/XonlyKey`` expose a `parity: Bool` property carrying the underlying y-coordinate's oddness (`false` for even, `true` for odd) — so a round-trip from full public key to x-only and back preserves the point exactly. BIP-340's "implicit even parity" is a *protocol-level* convention: when an x-only key has odd y, ``P256K/Schnorr/PrivateKey`` internally negates its scalar so signatures verify against the even-y representative the BIP-340 verifier expects. The `parity` accessor itself remains a true reflection of the underlying point and is consulted during BIP-341 Taproot tweak verification.

### Choosing a representation

Default to **compressed**. It is the Bitcoin standard since 2012, the smaller wire form, and what every modern Bitcoin or Lightning peer expects on the protocol layer.

Use **x-only** when working with Schnorr signatures, Taproot output keys, or MuSig2 aggregates. The 32-byte form is required by BIP-340, BIP-341, and BIP-327.

Use **uncompressed** only when a legacy protocol or external system explicitly requires the 65-byte `0x04`-prefixed form. New code rarely needs it.

### Encoding raw bytes

Round-trip a public key through `dataRepresentation` and the format-aware initializer on ``P256K/Signing/PublicKey``:

```swift
import P256K

// Export — 33 bytes for compressed, 65 for uncompressed
let keyData = publicKey.dataRepresentation

let restored = try P256K.Signing.PublicKey(
    dataRepresentation: keyData,
    format: .compressed
)
```

Private keys are a fixed 32-byte scalar; no format flag is needed on ``P256K/Signing/PrivateKey``:

```swift
import P256K

let privateKeyBytes = privateKey.dataRepresentation  // 32 bytes
let restored = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
```

Select the public-key form at private-key creation time using the `format:` parameter, or convert an existing compressed public key to its uncompressed bytes on demand:

```swift
import P256K

let compressed = try P256K.Signing.PrivateKey(format: .compressed)
compressed.publicKey.dataRepresentation.count  // 33

let uncompressed = try P256K.Signing.PrivateKey(format: .uncompressed)
uncompressed.publicKey.dataRepresentation.count  // 65

// Compressed public key → uncompressed bytes without a new key pair
let fullBytes = compressed.publicKey.uncompressedRepresentation  // 65 bytes
```

### Importing PEM-encoded keys

PEM frames a Base64-encoded ASN.1 body between `-----BEGIN ... -----` / `-----END ... -----` lines, per RFC 7468. ``P256K/Signing/PrivateKey`` accepts both the SEC 1 `EC PRIVATE KEY` form and the algorithm-agnostic PKCS#8 (RFC 5958) `PRIVATE KEY` form:

```swift
import P256K

let pemString = """
-----BEGIN EC PRIVATE KEY-----
MHQCAQEEIBXwHPDpec6b07GeLbnwetT0dvWzp0nV3MR+4pPKXIc7oAcGBSuBBAAK
oUQDQgAEt2uDn+2GqqYs/fmkBr5+rCQ3oiFSIJMAcjHIrTDS6HEELgguOatmFBOp
2wU4P2TAl/0Ihiq+nMkrAIV69m2W8g==
-----END EC PRIVATE KEY-----
"""
let privateKey = try P256K.Signing.PrivateKey(pemRepresentation: pemString)
```

Public keys use the `PUBLIC KEY` PEM type wrapping an X.509 SubjectPublicKeyInfo (RFC 5280 §4.1) carrying a SEC 1 point:

```swift
let publicKey = try P256K.Signing.PublicKey(pemRepresentation: publicKeyPEM)
```

> Note: ``P256K`` parses PEM but does not currently emit it. To send a key in another direction, use `dataRepresentation` (the raw 32-byte scalar for private keys, or the 33/65-byte point form for public keys) and have the consumer either accept the raw form or wrap it through an external ASN.1 layer.

### Importing DER-encoded keys

DER is the binary ASN.1 Distinguished Encoding Rules body that sits inside the PEM wrapper. ``P256K/Signing/PrivateKey`` accepts either the SEC 1 §C.4 `ECPrivateKey` structure or PKCS#8; ``P256K/Signing/PublicKey`` accepts the X.509 `SubjectPublicKeyInfo` shape:

```swift
import P256K

let privateKey = try P256K.Signing.PrivateKey(derRepresentation: derBytes)
let publicKey = try P256K.Signing.PublicKey(derRepresentation: derBytes)
```

As with PEM, DER on key types is import-only — use `dataRepresentation` for the export path. ECDSA signatures are the bidirectional exception: ``P256K/Signing/ECDSASignature`` both encodes to *and* parses from DER:

```swift
import P256K

let signature = try P256K.Signing.ECDSASignature(derRepresentation: derData)
let derBytes = signature.derRepresentation
```

### Working with x-only keys

Schnorr keys expose their 32-byte x-only form through the `xonly` accessor, which returns a ``P256K/Schnorr/XonlyKey``:

```swift
import P256K

let schnorrKey = try P256K.Schnorr.PrivateKey()
let xonlyBytes = schnorrKey.xonly.bytes  // [UInt8], 32 bytes
```

An ECDSA public key can be projected to x-only and lifted back, preserving the original parity through the round-trip:

```swift
import P256K

// Full key → x-only (drops the parity bit from the wire form, retains it in XonlyKey.parity)
let xonly = ecdsaPublicKey.xonly

// X-only → full key (uses the retained parity to reconstruct the point)
let fullKey = P256K.Signing.PublicKey(xonlyKey: xonly)
```

A ``P256K/Schnorr/XonlyKey`` and a ``P256K/Signing/XonlyKey`` track parity identically at the API surface — the BIP-340 implicit-even-parity convention is enforced inside ``P256K/Schnorr/PrivateKey`` (which negates its scalar when needed), not by suppressing the `parity` accessor.

### Deriving child keys with tweaks

A tweak combines an existing key pair with a 32-byte scalar offset to produce a new key pair while preserving the linear relationship between the private and public halves. For a key pair `(d, P)` with `P = d·G` and an offset `t`, the additive form yields `(d + t mod n, P + t·G)` and the multiplicative form yields `(d·t mod n, t·P)`. Either form can be applied to the public half alone — the property that makes hardware-wallet watch-only child-key derivation possible without exposing the private half. This algebra is the foundation under BIP-32 hierarchical deterministic wallets, BIP-341 Taproot output keys, BIP-327 MuSig2 key aggregation, and BIP-352 Silent Payments destination derivation (BIPs anchored in Standards reference below).

> Note: ``P256K`` provides only the tweak primitive. Chain-code derivation per BIP-32 §3, Silent Payments output construction per BIP-352, and other wallet-layer composition are caller-supplied — the package exposes the elliptic-curve operation, not the surrounding protocol.

> Warning: `add(_:)` and `multiply(_:)` throw ``secp256k1Error/underlyingCryptoError`` when the tweak fails `secp256k1_ec_seckey_verify` (zero or ≥ the curve order `n`) or — on public-key forms — when the result is the point at infinity. With cryptographically hashed tweaks the failure is vanishingly rare, but the `try` is real and must be handled rather than `try!`-forced in production.

For ECDSA, apply an additive or multiplicative offset to a ``P256K/Signing/PrivateKey``:

```swift
import P256K

let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: keyBytes)
let tweak = SHA256.hash(data: someData)

// Additive: newKey = privateKey + tweak (mod n)
let tweakedPrivateKey = try privateKey.add(Array(tweak))

// Multiplicative: newKey = privateKey * tweak (mod n)
let tweakedByMul = try privateKey.multiply(Array(tweak))
```

Apply the same offsets directly to a public key — no private half required, which is what enables watch-only derivation:

```swift
import P256K

// Additive: newPubKey = pubKey + tweak * G
let tweakedPublicKey = try publicKey.add(Array(tweak))

// Multiplicative: newPubKey = tweak * pubKey
let tweakedByMul = try publicKey.multiply(Array(tweak))
```

### Tweaking Schnorr keys

BIP-340 Schnorr keys live as 32-byte x-only points with implicit even parity. The Schnorr tweak API on ``P256K/Schnorr/PrivateKey`` handles the parity adjustment automatically: if the tweaked point lands with odd y, the underlying private scalar is negated so the public half remains implicit-even.

```swift
import P256K

let schnorrKey = try P256K.Schnorr.PrivateKey(dataRepresentation: keyBytes)
let tweak = SHA256.hash(data: someData)

let tweakedKey = try schnorrKey.add(Array(tweak))
```

X-only public keys can be tweaked directly:

```swift
import P256K

let tweakedXonly = try schnorrKey.xonly.add(Array(tweak))
```

### Constructing a Taproot output key

A BIP-341 Taproot output key is the internal x-only key plus a tagged-hash offset. For a key-path-only output (no script tree), the offset is `H_TapTweak(internalKey)`:

```swift
import Foundation
import P256K

let internalKey = try P256K.Schnorr.PrivateKey(
    dataRepresentation: keyBytes
).xonly

let tweakHash = SHA256.taggedHash(
    tag: "TapTweak".data(using: .utf8)!,
    data: Data(internalKey.bytes)
)

let outputKey = try internalKey.add(Array(tweakHash))
```

For an output committing to a script tree, append the Merkle root to the tagged-hash input:

```swift
import Foundation
import P256K

let tweakHash = SHA256.taggedHash(
    tag: "TapTweak".data(using: .utf8)!,
    data: Data(internalKey.bytes) + merkleRoot
)
let outputKey = try internalKey.add(Array(tweakHash))
```

The `TapTweak` tag provides domain separation so the same offset cannot be reinterpreted as a different BIP-341 commitment. See BIP-341 §Constructing and spending Taproot outputs (linked in the Standards reference) for the full output construction algorithm.

### Tweaking MuSig2 aggregate keys

A BIP-327 ``P256K/MuSig`` aggregate has its own tweak overloads — `add(_:format:)` on the full public key and `add(_:)` on the x-only form — that call `secp256k1_musig_pubkey_ec_tweak_add` and `secp256k1_musig_pubkey_xonly_tweak_add` respectively. Unlike a plain key tweak, these update the BIP-327 key-aggregation cache in place, which is required if downstream MuSig partial signatures must verify against the tweaked aggregate. Use the full form for BIP-32 chaining and the x-only form for Taproot output construction:

```swift
import P256K

let aggregate = try P256K.MuSig.aggregate(publicKeys)

// BIP-32-style: tweak the full aggregate; updates the keyagg cache
let derivedKey = try aggregate.add(Array(tweak))

// Taproot: tweak the x-only aggregate with H_TapTweak(...)
let taprootOutput = try aggregate.xonly.add(Array(tweakHash))
```

See <doc:MuSig2MultiSignatures> for the surrounding aggregation, nonce, and signing protocol.

### Standards reference

The encodings, key types, and derivation paths in this article are defined by the following specifications. Where multiple proposals share an authoritative catalog, the catalog is anchored once and the individual proposals are listed by number:

- **[SEC 1: Elliptic Curve Cryptography v2][sec1-v2]** — point encoding (§2.3.3) and `ECPrivateKey` DER structure (§C.4).
- **[RFC 7468][rfc-7468]** — textual PEM framing for cryptographic objects.
- **[RFC 5958][rfc-5958]** — PKCS#8 asymmetric key package format.
- **[RFC 5280 §4.1][rfc-5280-4-1]** — X.509 SubjectPublicKeyInfo carrying a SEC 1 point.
- **[Bitcoin BIPs catalog][bips-catalog]** — the relevant proposals are **BIP-32** (hierarchical deterministic wallets; chain-code derivation is caller-supplied), **BIP-327** (MuSig2 key aggregation), **BIP-340** (Schnorr signatures and x-only encoding), **BIP-341** (Taproot output keys; see *Constructing and spending Taproot outputs* for the full output-key construction algorithm), and **BIP-352** (Silent Payments destination derivation).

## See Also

- <doc:GettingStarted>
- <doc:MuSig2MultiSignatures>
- <doc:CryptoKitP256AndSecp256k1>
- <doc:SecurityConsiderations>
- ``P256K/Format``
- ``P256K/Signing``
- ``P256K/Schnorr``
- ``P256K/MuSig``

[bips-catalog]: https://github.com/bitcoin/bips
[libsecp256k1]: https://github.com/bitcoin-core/secp256k1
[rfc-5280-4-1]: https://datatracker.ietf.org/doc/html/rfc5280#section-4.1
[rfc-5958]: https://datatracker.ietf.org/doc/html/rfc5958
[rfc-7468]: https://datatracker.ietf.org/doc/html/rfc7468
[sec1-v2]: https://www.secg.org/sec1-v2.pdf
