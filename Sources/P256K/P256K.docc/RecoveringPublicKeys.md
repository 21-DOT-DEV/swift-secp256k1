# Recovering Public Keys

@Metadata {
    @TitleHeading("How-to Guide")
}

Recover an ECDSA public key from a recoverable signature and its recovery ID.

## Overview

ECDSA recoverable signatures attach a small (1–3 bit) **recovery ID** to a signature, letting verifiers reconstruct the signing key from the signature and message alone. This saves one round trip in account-discovery flows and underpins Bitcoin signed-message workflows — [BIP-137](https://github.com/bitcoin/bips/blob/master/bip-0137.mediawiki) (legacy `signmessage`/`verifymessage` in Bitcoin Core) and [BIP-322](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki) (generic signed-message format).

The mechanism leverages a structural fact about ECDSA. Every signature `(r, s)` is consistent with up to four candidate elliptic-curve points on the secp256k1 curve, and the ID encodes which of those four candidates matches the original signer's verifying key — two bits suffice (high vs. low half of the field, and even vs. odd parity). Without that hint, a verifier would have to try all four candidates and disambiguate by message content; with it, the lift is deterministic and inexpensive. The trade-off is a single extra byte on the wire — small enough that recoverable signatures dominate Bitcoin signed-message workflows even though Bitcoin's on-chain script signatures use the vanilla form.

The sections below walk through creating, serializing, and reconstructing keys from a 65-byte signature payload, and converting the result to a standard ECDSA signature for APIs that expect the vanilla form.

### Creating a Recoverable Signature

Use ``P256K/Recovery/PrivateKey`` to produce a recoverable ECDSA signature. Unlike a standard ECDSA signature, this variant embeds the additional ID that identifies which of up to four candidate verifying keys produced it:

```swift
import Foundation
import P256K

let privateKey = try P256K.Recovery.PrivateKey(
    dataRepresentation: keyBytes
)
let message = "We're all Satoshi.".data(using: .utf8)!

let recoverySignature = privateKey.signature(for: message)
```

### Reconstructing the Signing Key

Lift the signer's verifying key out of the message and signature in one step:

```swift
import P256K

let recoveredKey = P256K.Recovery.PublicKey(message, signature: recoverySignature)

// The recovered key matches the original
recoveredKey.dataRepresentation == privateKey.publicKey.dataRepresentation
```

You can also lift from a hash digest directly:

```swift
import P256K

let digest = SHA256.hash(data: message)
let recoveredKey = P256K.Recovery.PublicKey(digest, signature: recoverySignature)
```

### Compact Representation and Recovery ID

The signature serializes as a compact 64-byte body plus a separate ID (0-3):

```swift
import P256K

let compact = recoverySignature.compactRepresentation
// compact.signature -- 64-byte compact ECDSA signature
// compact.recoveryId -- Int32 (0, 1, 2, or 3)
```

Reconstruct from the compact form:

```swift
import P256K

let restored = try P256K.Recovery.ECDSASignature(
    compactRepresentation: compactBytes,
    recoveryId: recoveryId
)
```

### Converting to Standard ECDSA

Use the ``P256K/Recovery/ECDSASignature/normalize`` property to drop the ID and obtain a standard ECDSA signature:

```swift
import P256K

let standardSignature = recoverySignature.normalize

// Access standard formats
standardSignature.dataRepresentation   // 64-byte compact
standardSignature.derRepresentation    // DER-encoded
```

> Important: The converted signature is **not guaranteed to be lower-S normalized** and may fail `secp256k1_ecdsa_verify`. If your application requires lower-S form (e.g., Bitcoin Core's [BIP-146](https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki) LOW_S rule), pass the result through `secp256k1_ecdsa_signature_normalize` before verifying.

## See Also

- <doc:GettingStarted>
- <doc:SecurityConsiderations>
- ``P256K/Recovery``
