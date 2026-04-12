# Serializing Keys

@Metadata {
    @TitleHeading("How-to Guide")
}

Import and export keys in raw bytes, PEM, DER, and other standard formats.

## Raw Bytes

The most common serialization. Use `dataRepresentation` to export and `init(dataRepresentation:format:)` to import:

```swift
// Export (33 bytes compressed, 65 bytes uncompressed)
let keyData = publicKey.dataRepresentation

// Import with explicit format
let restored = try P256K.Signing.PublicKey(
    dataRepresentation: keyData,
    format: .compressed
)
```

Private keys are always 32 bytes:

```swift
let privKeyData = privateKey.dataRepresentation  // 32 bytes
let restored = try P256K.Signing.PrivateKey(dataRepresentation: privKeyData)
```

## PEM Encoding

Import keys from PEM-encoded strings. Both SEC1 (`EC PRIVATE KEY`) and PKCS#8 (`PRIVATE KEY`) formats are supported:

```swift
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
let publicKey = try P256K.Signing.PublicKey(pemRepresentation: publicKeyPEM)
```

## DER Encoding

Import from DER-encoded binary data:

```swift
let privateKey = try P256K.Signing.PrivateKey(derRepresentation: derBytes)
let publicKey = try P256K.Signing.PublicKey(derRepresentation: derBytes)
```

ECDSA signatures also support DER:

```swift
let signature = try P256K.Signing.ECDSASignature(derRepresentation: derData)
let derBytes = signature.derRepresentation
```

## Compressed vs Uncompressed

Specify the format when creating keys:

```swift
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

## X-Only Keys

Schnorr signatures (BIP-340) use 32-byte x-only public keys with implicit even parity:

```swift
let schnorrKey = try P256K.Schnorr.PrivateKey()
let xonlyBytes = schnorrKey.xonly.bytes  // [UInt8], 32 bytes
```

Convert between full public keys and x-only:

```swift
// Full key to x-only
let xonly = ecdsaPublicKey.xonly

// X-only back to full key (original parity preserved)
let fullKey = P256K.Signing.PublicKey(xonlyKey: xonly)
```

## Format Comparison

| Format | Size | Prefix | Use Case |
|--------|------|--------|----------|
| Compressed | 33 bytes | `0x02` / `0x03` | Default, blockchain storage |
| Uncompressed | 65 bytes | `0x04` | Legacy compatibility |
| X-only | 32 bytes | None | BIP-340 Schnorr, Taproot |
| DER (private) | ~118 bytes | ASN.1 | Interoperability |
| PEM (private) | ~227 bytes | Base64 + header | Human-readable storage |
