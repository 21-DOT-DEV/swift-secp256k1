# Why CryptoKit's P256 Can't Sign Bitcoin or Nostr

@Metadata {
    @TitleHeading("Explanation")
}

Apple's CryptoKit and swift-crypto expose elliptic-curve primitives on NIST P-256, P-384, P-521, and Curve25519, but not secp256k1 — the curve Bitcoin, Lightning, and Nostr require. The ``P256K`` module provides the secp256k1 equivalents with a CryptoKit-shaped API.

## Overview

### The short answer

If you reached for CryptoKit's `P256` or its swift-crypto equivalent to sign a Bitcoin transaction, a Lightning channel update, or a Nostr event, the type compiles but the cryptography does not interoperate with those protocols. CryptoKit's `P256` is NIST P-256 — an entirely different elliptic curve from secp256k1, the curve Bitcoin and every protocol derived from it require. No combination of flags, key formats, or hash functions in CryptoKit will produce a signature that a Bitcoin node, a Lightning peer, or a Nostr relay will accept.

The ``P256K`` module provides the secp256k1 equivalents under a deliberately CryptoKit-shaped API. ECDSA signing for Bitcoin transactions and signed messages lives in ``P256K/Signing``; BIP-340 Schnorr (used by Nostr events and Taproot spends) lives in ``P256K/Schnorr``; ECDH key agreement for the Lightning Noise handshake and Nostr direct messages lives in ``P256K/KeyAgreement``. The rest of this article documents *why* the mismatch exists and *which P256K type* replaces each CryptoKit call.

### NIST P-256 and secp256k1 are different curves

NIST P-256 and secp256k1 are two distinct elliptic curves defined over different prime fields, with different generators and different curve equations. The shared "256" refers only to the bit-length of the underlying prime field, and nothing else about them is interchangeable.

The SEC 2 nomenclature makes the family explicit: the trailing letter is meaningful, not arbitrary. **secp256r1** — the curve CryptoKit calls `P256` — is a **r**andom curve, with the coefficient `b` fixed by ANSI X9.62's verifiable-random procedure: a published seed is hashed with SHA-1 to derive an intermediate value, and `b` is then chosen so the curve satisfies a published constraint against it. **secp256k1** is a **K**oblitz curve, a class with algebraic structure named after Neal Koblitz. Both are 256-bit prime-field curves; that is the entirety of their compatibility.

The curve equations diverge immediately:

- NIST P-256: `y² ≡ x³ − 3x + b (mod p)`, where `b` is fixed by the verifiable procedure above and `p = 2²⁵⁶ − 2²²⁴ + 2¹⁹² + 2⁹⁶ − 1`. The full parameters are specified in NIST SP 800-186, the parameter document for FIPS 186-5.
- secp256k1: `y² ≡ x³ + 7 (mod p)`, where `p = 2²⁵⁶ − 2³² − 977`. The full parameters are specified in SEC 2 v2 §2.4.1.

The generator points are different. The group orders are different. The set of valid public keys is different. Bytes with the right shape for a compressed key — a `0x02` or `0x03` prefix followed by 32 bytes — can be interpreted as a point on either curve, but the same bytes denote different points in different groups, and a signature produced under one curve cannot be verified under the other.

Every Bitcoin-derived ecosystem — Lightning, Nostr, Stacks, and so on — inherits the same curve choice, and so requires the same secp256k1 implementation. Satoshi Nakamoto's 2008 selection has aged well: secp256k1's parameters are fully explicit, with no constants pulled from an unexplained hash, and the Koblitz structure (`a = 0`) admits a GLV endomorphism that meaningfully speeds scalar multiplication.

> Important: A secp256k1 key or signature cannot be used with NIST P-256, and vice versa; the byte representations may be byte-identical but they describe points on different curves.

### What CryptoKit and swift-crypto actually support

CryptoKit's elliptic-curve surface is deliberately curated: three NIST prime curves (P-256, P-384, P-521) for ECDSA and ECDH, plus Curve25519 for Ed25519 signing and X25519 key agreement. Each of these curves has matching `Signing` and `KeyAgreement` namespaces nested under the curve type — for example, `P256.Signing` and `Curve25519.KeyAgreement`. There is no entry for secp256k1.

The Secure Enclave gets an additional `SecureEnclave.P256` surface that keeps the private key bound to the device and never returns it to process memory. That hardware path is also NIST P-256 only — the Secure Enclave does not implement secp256k1.

swift-crypto is Apple's open-source implementation used for Linux and server-side Swift, tracking CryptoKit's API. The curve catalog is the same — P-256, P-384, P-521, Curve25519 — and the same omission applies: no secp256k1 in the main module, and none in the `CryptoExtras` subset either. The name appears only as an inert OID constant in the vendored BoringSSL sources (NID 714, OID `1.3.132.0.10`) — an object identifier for ASN.1 parsing, not an implementation.

The omission is deliberate and longstanding. When asked to add secp256k1 in [swift-crypto issue #8][swift-crypto-iss-8] (filed February 2020, declined that month and reaffirmed in January 2022), the maintainers' primary recommendation was "a high-quality secp256k1 Swift open source project made available, potentially with a compatible API," specifically calling out "a Swift wrapper of the bitcoin-core implementation (or any other preferred high-quality implementation), following the API design principles used in this library." ``P256K`` is exactly that.

> Note: swift-crypto and CryptoKit share an API contract by design. If a curve or primitive is missing from one, treat it as missing from both — including secp256k1.

This is the core elliptic-curve surface of the Apple stack. Every Bitcoin, Lightning, and Nostr operation that depends on secp256k1 has to go through a separately-vendored library — which Apple's own maintainers recommend.

### The use-case redirect, code by code

``P256K`` wraps `libsecp256k1` — the reference implementation used by Bitcoin Core itself (canonical repository linked in the Standards and specifications subsection) — and surfaces it under CryptoKit-shaped namespaces. The result is the library pattern issue #8's maintainers asked for: nested `Signing`, `Schnorr`, and `KeyAgreement` namespaces; `PrivateKey` and `PublicKey` types with `dataRepresentation`; `sharedSecretFromKeyAgreement(with:)` returning a ``SharedSecret`` type that mirrors CryptoKit's `ContiguousBytes`-conforming shape. The three subsections below pair each CryptoKit call you tried (or were about to try) with the P256K equivalent that actually interoperates with the protocol.

#### ECDSA: signing Bitcoin transactions and messages

ECDSA on secp256k1 is the signature primitive behind every pre-Taproot Bitcoin script and the BIP-137 signed-message format. The CryptoKit call compiles against NIST P-256 and produces signatures that no Bitcoin node, Lightning peer, or BIP-137 verifier will accept:

```swift
// CryptoKit / swift-crypto — NIST P-256, NOT compatible with Bitcoin
import CryptoKit

let key = P256.Signing.PrivateKey()
let signature = try key.signature(for: messageData)
// signature is ECDSA over NIST P-256 — Bitcoin nodes reject
```

The ``P256K/Signing/PrivateKey`` equivalent has the same nested-namespace shape and produces signatures already lower-S normalized per BIP-146, which is the only form `secp256k1_ecdsa_verify` accepts:

```swift
// P256K — secp256k1, the curve Bitcoin actually uses
import P256K

let key = try P256K.Signing.PrivateKey()
let signature = key.signature(for: messageData)
// signature is ECDSA over secp256k1, lower-S normalized
```

SHA-256 is applied internally before signing, matching CryptoKit's `signature(for:)` convention. Serialization is symmetric: ``P256K/Signing/ECDSASignature/compactRepresentation`` returns the 64-byte form, and ``P256K/Signing/ECDSASignature/derRepresentation`` returns the variable-length DER encoding.

#### BIP-340 Schnorr: Nostr events and Taproot key-path spends

NIP-01 signs every Nostr event with a BIP-340 Schnorr signature over a 32-byte x-only public key. Bitcoin's Taproot key-path spends use the same scheme. CryptoKit has no Schnorr signature support at all — its EdDSA implementation is Ed25519 on Curve25519, which is a different signature scheme on a different curve:

```swift
// CryptoKit / swift-crypto — Ed25519, NOT BIP-340 Schnorr
import CryptoKit

let key = Curve25519.Signing.PrivateKey()
let signature = try key.signature(for: messageData)
// signature is Ed25519 — Nostr relays and Taproot verifiers reject
```

The P256K equivalent uses ``P256K/Schnorr/PrivateKey``, signs under BIP-340, and exposes a 32-byte x-only verifying key via `xonly` — exactly the shape NIP-01 events and Taproot output keys require:

```swift
// P256K — BIP-340 Schnorr over secp256k1, the curve Nostr and Taproot use
import P256K
import Foundation

let key = try P256K.Schnorr.PrivateKey()

// Nostr NIP-01: sign SHA256 of the serialized event
let serializedEvent: Data = /* NIP-01 deterministic JSON serialization */
let eventId = SHA256.hash(data: serializedEvent)
let signature = try key.signature(for: eventId)
let nostrPubkey = key.xonly.bytes   // 32 bytes — the npub
```

Schnorr signing in P256K takes a pre-computed digest. BIP-340 accepts arbitrary-length messages but recommends domain separation via tagged hashing. Bitcoin's BIP-341 follows that recommendation with a `TapSighash` tagged hash; Nostr NIP-01 takes a simpler route — `SHA256(serialized event)`, no domain separator. Either way the message arrives at the signer as a fixed 32-byte digest, which is why P256K's Schnorr API takes a `Digest`.

Taproot key-path spends use the same `signature(for: Digest)` call, with the digest constructed via `SHA256.taggedHash(tag: "TapSighash", ...)` per BIP-341 (linked under Standards and specifications below).

#### ECDH: Lightning channel setup and Nostr direct messages

ECDH on secp256k1 underlies Lightning's encrypted-transport handshake (BOLT-08 Noise XK) and Nostr direct messaging (NIP-44, or legacy NIP-04). CryptoKit's ECDH is on NIST P-256, so the shared secret it produces is computed against the wrong curve:

```swift
// CryptoKit / swift-crypto — ECDH on NIST P-256
import CryptoKit

let aliceKey = P256.KeyAgreement.PrivateKey()
let bobKey   = P256.KeyAgreement.PrivateKey()
let secret   = try aliceKey.sharedSecretFromKeyAgreement(with: bobKey.publicKey)
// SharedSecret derived on NIST P-256 — Lightning peers and Nostr relays expect secp256k1
```

The P256K equivalent has the same shape — ``P256K/KeyAgreement/PrivateKey``, `sharedSecretFromKeyAgreement(with:)`, and a CryptoKit-shaped ``SharedSecret`` return type:

```swift
// P256K — ECDH on secp256k1, the curve Lightning and Nostr use
import P256K

let aliceKey = try P256K.KeyAgreement.PrivateKey()
let bobKey   = try P256K.KeyAgreement.PrivateKey()
let secret   = try aliceKey.sharedSecretFromKeyAgreement(with: bobKey.publicKey)
// SharedSecret derived on secp256k1 — interoperable with BOLT-08 and NIP-44
```

The returned ``SharedSecret`` is a separate type from CryptoKit's but mirrors its `ContiguousBytes` shape and constant-time equality semantics, so downstream key-derivation code that operates on `ContiguousBytes` (HKDF, HMAC) drops in without an adapter layer.

### What P256K is and what it is not

``P256K`` wraps `libsecp256k1` — the high-assurance reference implementation that Bitcoin Core itself runs, engineered for constant-time execution on secret-key paths. The Swift wrapper is **pre-1.0**: the public API is not yet stable, and consumers should pin `exact:` versions in `Package.swift` to avoid surprise migrations. See <doc:SecurityConsiderations> for the full operational guidance.

Three CryptoKit assumptions do not carry over:

- **No Secure Enclave.** All P256K keys live in process memory. There is no hardware-bound private-key path equivalent to `SecureEnclave.P256`; the secp256k1 curve is not implemented in Apple's Secure Enclave.
- **ECDH side-channel hygiene works differently.** Context randomization blinds operations on the fixed generator point — signing and key generation. ECDH multiplies the peer's public key, a variable point, so it relies on libsecp256k1's separate constant-time variable-base routine rather than base-point blinding.
- **No SDK availability gating.** CryptoKit is bundled with Apple platforms and follows OS version availability rules. P256K is a third-party SwiftPM dependency with its own pre-1.0 release cadence; expect breaking changes in any pre-1.0 release.

Secrets are protected by `SecureBytes` zeroization on deallocation and constant-time comparison on ``SharedSecret`` and `PrivateKey` types — mirroring CryptoKit's hygiene defaults. The upstream library's threat model and stability guarantees are documented in the `bitcoin-core/secp256k1` README (linked under Standards and specifications below).

### Standards and specifications

The curves, signature schemes, and message-domain protocols compared above are defined by the following canonical references. Where multiple proposals share an authoritative catalog, the catalog is anchored once and the individual proposals are listed by number:

- **NIST cryptographic standards** — [FIPS 186-5][fips-186-5] (Digital Signature Standard governing the NIST curves) and its parameter document **NIST SP 800-186** (curve parameters for NIST P-256).
- **[SEC 2 v2 §2.4.1][sec2-v2]** — secp256k1 curve parameters; also contains the X9.62 verifiable-random procedure used for secp256r1.
- **[Bitcoin BIPs catalog][bips-catalog]** — the relevant proposals are **BIP-137** (signed-message format), **BIP-146** (lower-S signature normalization), **BIP-340** (Schnorr signatures over secp256k1), and **BIP-341** (Taproot key-path spend; `TapSighash` tagged-hash construction).
- **[Nostr NIPs catalog][nips-catalog]** — the relevant proposals are **NIP-01** (Nostr event signing), **NIP-04** (legacy direct-message encryption), and **NIP-44** (current direct-message encryption).
- **[Lightning BOLT-08][bolt-08]** — Lightning encrypted-transport handshake (Noise XK).
- **[`bitcoin-core/secp256k1`][libsecp256k1]** — upstream reference C implementation and threat model.

## See Also

- <doc:GettingStarted>
- <doc:EllipticCurveDiffieHellman>
- <doc:WorkingWithKeys>
- <doc:RecoveringPublicKeys>
- <doc:SecurityConsiderations>
- ``P256K``

[bips-catalog]: https://github.com/bitcoin/bips
[bolt-08]: https://github.com/lightning/bolts/blob/master/08-transport.md
[fips-186-5]: https://csrc.nist.gov/pubs/fips/186-5/final
[libsecp256k1]: https://github.com/bitcoin-core/secp256k1
[nips-catalog]: https://github.com/nostr-protocol/nips
[sec2-v2]: https://www.secg.org/sec2-v2.pdf
[swift-crypto-iss-8]: https://github.com/apple/swift-crypto/issues/8
