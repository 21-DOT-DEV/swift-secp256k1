# Elliptic Curve Diffie-Hellman

@Metadata {
    @TitleHeading("How-to Guide")
}

Derive a shared secret between two parties over secp256k1 using ECDH key agreement, the foundation of Nostr NIP-04 encryption, BIP-352 Silent Payments, and Lightning's Noise XK handshake.

## Overview

Elliptic Curve Diffie-Hellman (ECDH) is the elliptic-curve form of the original [Diffie-Hellman key exchange](https://datatracker.ietf.org/doc/html/rfc2631) (1976). Two parties — Alice with key pair `(a, A)` and Bob with key pair `(b, B)`, where `A = a·G` and `B = b·G` — can each independently compute the same shared point:

```
S = a·B = a·(b·G) = b·(a·G) = b·A
```

Neither party transmits a secret. An eavesdropper observing only the public keys `A` and `B` cannot derive `S` without solving the [elliptic curve discrete logarithm problem](https://en.wikipedia.org/wiki/Elliptic-curve_cryptography#Rationale), which is computationally infeasible on secp256k1 at the 128-bit security level.

This package implements ECDH on the secp256k1 curve via libsecp256k1's [`secp256k1_ecdh`](https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1_ecdh.h) function. ECDH on secp256k1 is the building block for several open-protocol stacks:

- **[BIP-352 Silent Payments](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki)** — sender derives a unique destination output from receiver's static address (see <doc:SilentPayments>).
- **[Nostr NIP-04](https://github.com/nostr-protocol/nips/blob/master/04.md)** — encrypted direct messages between Nostr identities (note: NIP-04 has known confidentiality limitations; NIP-44 supersedes it).
- **[Lightning's Noise XK handshake](https://github.com/lightning/bolts/blob/master/08-transport.md)** — establishes the encrypted transport between Lightning Network peers.
- **Hybrid encryption schemes** — ECIES variants combining ECDH with a symmetric AEAD.

### The Key Agreement Namespace

All ECDH operations live under ``P256K/KeyAgreement``:

```swift
import P256K

let alicePrivateKey = try P256K.KeyAgreement.PrivateKey()
let bobPrivateKey = try P256K.KeyAgreement.PrivateKey()

let alicePublicKey = alicePrivateKey.publicKey
let bobPublicKey = bobPrivateKey.publicKey
```

``P256K/KeyAgreement/PrivateKey`` is byte-compatible with ``P256K/Signing/PrivateKey`` — you can convert between them via `dataRepresentation` when a single key serves both roles (signing and key agreement).

### Computing a Shared Secret

Each party calls `sharedSecretFromKeyAgreement(with:)` with the other party's public key. Both produce identical output:

```swift
let aliceShared = alicePrivateKey.sharedSecretFromKeyAgreement(with: bobPublicKey)
let bobShared = bobPrivateKey.sharedSecretFromKeyAgreement(with: alicePublicKey)

// aliceShared.bytes == bobShared.bytes
```

The returned ``SharedSecret`` wraps the **raw serialized EC point** in compressed form (33 bytes: `0x02`/`0x03` prefix + 32-byte x-coordinate). This differs from libsecp256k1's upstream default (`secp256k1_ecdh_hash_function_sha256`, which would return a SHA-256 of the compressed point) — this package surfaces the unhashed point so callers can pipe it into whatever KDF their protocol requires.

### Format Selection

The default is `.compressed` (33 bytes). For protocols that mandate the full point (uncompressed SEC1 encoding, 65 bytes: `0x04` prefix + 32-byte x + 32-byte y):

```swift
let sharedUncompressed = alicePrivateKey.sharedSecretFromKeyAgreement(
    with: bobPublicKey,
    format: .uncompressed
)
// sharedUncompressed.bytes.count == 65
```

Choose compressed unless interoperability with a protocol that requires uncompressed encoding (for example, some legacy ECIES variants, or specific OpenSSL-generated key material) forces the larger form. See <doc:KeyFormats> for the broader format-selection story.

### Deriving a Symmetric Key

The raw shared point should not be used directly as a symmetric key. Always run it through a key-derivation function (KDF). Three common patterns:

**SHA-256 (simplest, suitable for ad-hoc symmetric key derivation):**

```swift
let symmetricKey = SHA256.hash(data: aliceShared.bytes)
// 32-byte key suitable for AES-256 or ChaCha20
```

**BIP-340 tagged SHA-256 (for protocols like BIP-352 that specify a domain-separation tag):**

```swift
let tagged = SHA256.taggedHash(
    tag: "BIP0352/SharedSecret".data(using: .utf8)!,
    data: aliceShared.bytes
)
```

**HKDF (when you need multiple keys from one shared secret, or a non-SHA-256 underlying hash):** use Apple's `swift-crypto` `HKDF` API or `CryptoKit.HKDF` with `aliceShared.bytes` as input keying material.

### Protocols Using ECDH on secp256k1

| Protocol | Spec | What ECDH derives |
|---|---|---|
| BIP-352 Silent Payments | [BIP-352](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki) | Per-output destination tweak |
| Nostr NIP-04 | [NIP-04](https://github.com/nostr-protocol/nips/blob/master/04.md) | AES-CBC encryption key for DMs |
| Lightning Noise XK | [BOLT 8](https://github.com/lightning/bolts/blob/master/08-transport.md) | ChaCha20-Poly1305 transport keys |
| ECIES (generic) | [SEC 1 §5.1](https://www.secg.org/sec1-v2.pdf) | Symmetric encryption + MAC keys |

For the BIP-352 case specifically, see the dedicated <doc:SilentPayments> guide — the protocol layers an input hash, a counter, and BIP-340 tagged hashing on top of the basic ECDH primitive.

### Production Considerations

#### Side-channel guarantees

ECDH multiplication uses a different curve-arithmetic path than ECDSA/Schnorr signing. As noted in <doc:SecurityConsiderations>, **context randomization does not provide side-channel protection for ECDH** on this code path. If your threat model requires constant-time guarantees against power or timing analysis, audit the underlying `secp256k1_ecdh` invocation against your target hardware.

#### Authenticate the peer's public key

ECDH alone provides confidentiality against passive eavesdroppers but says nothing about who you exchanged secrets with. A man-in-the-middle who substitutes their own public key for `B` derives a shared secret with Alice, and separately derives a different shared secret with Bob, then proxies traffic between them. Always pair ECDH with peer-key authentication — typically via a signature, a certificate, or out-of-band fingerprint verification (the [Noise framework](https://noiseprotocol.org/) integrates both).

#### Static vs ephemeral keys

ECDH keys can be **static** (long-lived, like a Nostr identity) or **ephemeral** (single-session, like Noise XK's `e` keys). Ephemeral keys provide forward secrecy: compromising a long-term key after the fact does not let an attacker decrypt past sessions. Use ephemeral keys for transport encryption; reserve static keys for identity and signature operations.

### Further Reading

- [BIP-352: Silent Payments specification](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki)
- [Nostr NIP-04: Encrypted Direct Message](https://github.com/nostr-protocol/nips/blob/master/04.md)
- [BOLT 8: Encrypted and Authenticated Transport](https://github.com/lightning/bolts/blob/master/08-transport.md)
- [SEC 1: Elliptic Curve Cryptography v2](https://www.secg.org/sec1-v2.pdf) (sections 3.3 and 5.1)
- [Noise Protocol Framework](https://noiseprotocol.org/)

## See Also

- <doc:GettingStarted>
- <doc:SilentPayments>
- <doc:SecurityConsiderations>
- ``P256K/KeyAgreement``
- ``SharedSecret``
