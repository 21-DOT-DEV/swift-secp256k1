# Recovering Public Keys

@Metadata {
    @TitleHeading("How-to Guide")
}

Recover an ECDSA public key from a recoverable signature and its recovery ID.

## Overview

ECDSA recoverable signatures attach a small (1–3 bit) **recovery ID** to a signature, letting verifiers reconstruct the signing public key from the signature and message alone. This saves one round trip in account-discovery flows and underpins Bitcoin signed-message workflows — [BIP-137](https://github.com/bitcoin/bips/blob/master/bip-0137.mediawiki) (legacy `signmessage`/`verifymessage` in Bitcoin Core) and [BIP-322](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki) (generic signed-message format). The sections below walk through creating, serializing, and recovering keys from recoverable signatures, and converting them to standard ECDSA signatures for use with APIs that expect the vanilla form.

### Creating a Recoverable Signature

Use ``P256K/Recovery/PrivateKey`` to produce a recoverable ECDSA signature. Unlike standard ECDSA signatures, recoverable signatures include a recovery ID that identifies which of up to four candidate public keys produced the signature:

```swift
let privateKey = try P256K.Recovery.PrivateKey(
    dataRepresentation: keyBytes
)
let message = "We're all Satoshi.".data(using: .utf8)!

let recoverySignature = privateKey.signature(for: message)
```

### Recovering the Public Key

Recover the signer's public key from the message and recoverable signature:

```swift
let recoveredKey = P256K.Recovery.PublicKey(message, signature: recoverySignature)

// The recovered key matches the original
recoveredKey.dataRepresentation == privateKey.publicKey.dataRepresentation
```

You can also recover from a hash digest:

```swift
let digest = SHA256.hash(data: message)
let recoveredKey = P256K.Recovery.PublicKey(digest, signature: recoverySignature)
```

### Compact Representation and Recovery ID

A recoverable signature can be serialized as a compact representation (64 bytes) plus a separate recovery ID (0-3):

```swift
let compact = recoverySignature.compactRepresentation
// compact.signature -- 64-byte compact ECDSA signature
// compact.recoveryId -- Int32 (0, 1, 2, or 3)
```

Reconstruct from the compact form:

```swift
let restored = try P256K.Recovery.ECDSASignature(
    compactRepresentation: compactBytes,
    recoveryId: recoveryId
)
```

### Converting to Standard ECDSA

Use the ``P256K/Recovery/ECDSASignature/normalize`` property to convert a recoverable signature to a standard ECDSA signature:

```swift
let standardSignature = recoverySignature.normalize

// Access standard formats
standardSignature.dataRepresentation   // 64-byte compact
standardSignature.derRepresentation    // DER-encoded
```

> Important: The converted signature is **not guaranteed to be lower-S normalized** and may fail `secp256k1_ecdsa_verify`. If your application requires lower-S form (e.g., Bitcoin Core's BIP-62 rule 6), pass the result through `secp256k1_ecdsa_signature_normalize` before verifying.
