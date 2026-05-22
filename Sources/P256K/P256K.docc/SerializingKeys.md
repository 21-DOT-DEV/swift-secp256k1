# Serializing Keys

@Metadata {
    @TitleHeading("How-to Guide")
}

Import and export ``P256K`` secp256k1 keys in raw bytes, PEM, DER, and X.509 SubjectPublicKeyInfo — the encodings Bitcoin, Lightning, OpenSSL toolchains, and PKCS#8-based wallet storage use.

## Overview

Key serialization comes up in wallet storage, protocol interop, and on-the-wire Bitcoin/Lightning witness data. Three encoding families show up most often:

- **Raw compressed/uncompressed point encoding** — the SEC 1 layouts ([SEC 1: Elliptic Curve Cryptography v2 §2.3](https://www.secg.org/sec1-v2.pdf)) used everywhere in Bitcoin and Lightning witness data.
- **PEM** — the textual wrapper defined in [RFC 7468](https://datatracker.ietf.org/doc/html/rfc7468), framing a Base64-encoded DER body between `-----BEGIN …-----` / `-----END …-----` lines. Used by OpenSSL and most cross-language toolchains.
- **DER** — the binary ASN.1 Distinguished Encoding Rules body sitting inside the PEM wrapper. The private-key shape follows either SEC 1 §C.4 (the `EC PRIVATE KEY` form) or [PKCS#8 / RFC 5958](https://datatracker.ietf.org/doc/html/rfc5958) (the algorithm-agnostic `PRIVATE KEY` form); the public-key shape is the [X.509 SubjectPublicKeyInfo from RFC 5280 §4.1](https://datatracker.ietf.org/doc/html/rfc5280#section-4.1) carrying a SEC 1 point.

The sections below cover each supported format in the order you will typically encounter them.

### Raw Bytes

The most common serialization. Use `dataRepresentation` to export and `init(dataRepresentation:format:)` to import:

```swift
import P256K

// Export (33 bytes compressed, 65 bytes uncompressed)
let keyData = publicKey.dataRepresentation

// Import with explicit format
let restored = try P256K.Signing.PublicKey(
    dataRepresentation: keyData,
    format: .compressed
)
```

Private keys are a fixed 32-octet scalar:

```swift
import P256K

let privKeyData = privateKey.dataRepresentation  // 32 bytes
let restored = try P256K.Signing.PrivateKey(dataRepresentation: privKeyData)
```

### PEM Encoding

Import keys from PEM-encoded strings. Both SEC1 (`EC PRIVATE KEY`) and PKCS#8 (`PRIVATE KEY`) formats are supported:

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

Public keys use the `PUBLIC KEY` PEM type:

```swift
import P256K

let publicKey = try P256K.Signing.PublicKey(pemRepresentation: publicKeyPEM)
```

### DER Encoding

Import from DER-encoded binary data:

```swift
import P256K

let privateKey = try P256K.Signing.PrivateKey(derRepresentation: derBytes)
let publicKey = try P256K.Signing.PublicKey(derRepresentation: derBytes)
```

ECDSA signatures also support DER:

```swift
import P256K

let signature = try P256K.Signing.ECDSASignature(derRepresentation: derData)
let derBytes = signature.derRepresentation
```

### Compressed vs Uncompressed

Specify the format when creating keys:

```swift
import P256K

// Compressed (default): 33-byte public key with 0x02 or 0x03 prefix
let compressed = try P256K.Signing.PrivateKey(format: .compressed)
compressed.publicKey.dataRepresentation.count  // 33

// Uncompressed: 65-byte public key with 0x04 prefix
let uncompressed = try P256K.Signing.PrivateKey(format: .uncompressed)
uncompressed.publicKey.dataRepresentation.count  // 65
```

Convert a compressed public key to its uncompressed form:

```swift
let fullBytes = compressedPublicKey.uncompressedRepresentation  // 65 bytes
```

### X-Only Keys

Schnorr signatures ([BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)) use 32-byte x-only public keys with implicit even parity:

```swift
import P256K

let schnorrKey = try P256K.Schnorr.PrivateKey()
let xonlyBytes = schnorrKey.xonly.bytes  // [UInt8], 32 bytes
```

Convert between full public keys and x-only:

```swift
import P256K

// Full key to x-only
let xonly = ecdsaPublicKey.xonly

// X-only back to full key (original parity preserved)
let fullKey = P256K.Signing.PublicKey(xonlyKey: xonly)
```

### Format Comparison

| Format | Size (bytes) | Prefix | Use Case |
|--------|--------------|--------|----------|
| Compressed | 33 | `0x02` / `0x03` | Default, blockchain storage |
| Uncompressed | 65 | `0x04` | Legacy compatibility |
| X-only | 32 | None | BIP-340 Schnorr, Taproot |
| DER (private) | ~118 | ASN.1 | Interoperability |
| PEM (private) | ~227 | Base64 + header | Human-readable storage |

## See Also

- <doc:CryptoKitP256AndSecp256k1>
- <doc:KeyFormats>
- <doc:GettingStarted>
- ``P256K/Format``
