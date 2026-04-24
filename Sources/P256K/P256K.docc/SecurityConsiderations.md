# Security Considerations

@Metadata {
    @TitleHeading("Explanation")
}

Understand the security properties of P256K and how to avoid common cryptographic pitfalls.

## Overview

P256K layers a Swift API over [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1), which is engineered for constant-time execution and side-channel resistance on the private-key paths. The sections below cover the areas where application code can still make mistakes that weaken those guarantees: context randomization lifecycle, nonce hygiene, comparison timing, secret zeroization, and ECDSA signature malleability.

### Context Randomization

Every cryptographic operation in P256K depends on a secp256k1 context managed by ``P256K/Context``. The shared context is created and **randomized** once at process startup using OS-provided entropy.

Randomization seeds a blinding factor that protects **ECDSA signing**, **Schnorr signing**, and **public key generation** against timing and power analysis attacks. The blinding factor is applied to the base point multiplication, making the internal computation pattern independent of the secret key.

> Note: ECDH key agreement uses a different kind of elliptic curve point multiplication and does **not** currently benefit from context randomization.

### Nonce Reuse

The most dangerous mistake in elliptic curve cryptography is reusing a nonce (random value) across two different signing operations with the same private key. If the same nonce `k` is used to sign two different messages, an attacker can compute the private key from the two signatures using simple algebra.

### MuSig2 SecureNonce

P256K uses Swift's `~Copyable` (non-copyable) type for ``P256K/Schnorr/SecureNonce`` to prevent accidental nonce reuse at the type-system level. Once a `SecureNonce` is consumed by a signing operation, it cannot be used again:

```swift
let nonce = try P256K.MuSig.Nonce.generate(
    secretKey: privateKey,
    publicKey: privateKey.publicKey,
    msg32: messageBytes
)

// The secnonce is consumed here -- it cannot be reused
let partial = try privateKey.partialSignature(
    for: digest,
    pubnonce: nonce.pubnonce,
    secureNonce: nonce.secnonce,  // consumed, cannot use again
    publicNonceAggregate: aggregateNonce,
    publicKeyAggregate: aggregate
)
```

### ECDSA and Schnorr Nonces

For standard (non-MuSig) ECDSA and Schnorr signing, P256K uses deterministic nonce generation (RFC 6979 for ECDSA, BIP-340 for Schnorr) by default, which eliminates the risk of random nonce reuse entirely.

### Constant-Time Comparison

When comparing secret values (shared secrets, keys, signatures), use constant-time comparison to avoid timing side-channels. P256K's ``SharedSecret`` type uses constant-time equality internally:

```swift
let secret1 = alice.sharedSecretFromKeyAgreement(with: bobPublicKey)
let secret2 = bob.sharedSecretFromKeyAgreement(with: alicePublicKey)

// This comparison is constant-time
secret1 == secret2
```

Never compare secret bytes using standard `==` on `Data` or `[UInt8]`, as this may short-circuit on the first differing byte, leaking information about which bytes match.

### Secret Key Zeroization

P256K uses `SecureBytes` internally for private key storage. When a `SecureBytes` value is deallocated, its memory is overwritten with zeros using `memset_s` (or an equivalent that the compiler cannot optimize away). This prevents secret key material from lingering in memory after the key object is destroyed.

### ECDSA Signature Malleability

An ECDSA signature `(r, s)` has a counterpart `(r, n - s)` that is also valid for the same message and public key. This **malleability** can cause problems in systems that use the signature as a unique transaction identifier (e.g., Bitcoin before SegWit).

P256K enforces **lower-S normalization** (BIP-62 rule 6): `secp256k1_ecdsa_verify` only accepts signatures where `s` is in the lower half of the curve order. The `signature(for:)` overloads on ``P256K/Signing/PrivateKey`` always produce normalized signatures, and the `normalize` property on a recoverable signature (``P256K/Recovery/ECDSASignature``) converts it to the canonical form.
