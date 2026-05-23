# ECDSA Signing on secp256k1 for Bitcoin Transactions in Swift

@Metadata {
    @TitleHeading("How-to Guide")
}

Produce ECDSA signatures on secp256k1 in Swift with `P256K`, encode them in DER and compact form, verify incoming signatures, and assemble the SIGHASH-flagged element Bitcoin script expects.

## Overview

Bitcoin's pre-Taproot script signatures are ECDSA signatures on the secp256k1 elliptic curve, DER-encoded per SEC 1 v2 §4.1, with a single sighash-type byte appended. This article walks through producing such a signature with ``P256K/Signing``, choosing the right wire encoding, verifying a signature received from another library, and assembling the signature element that goes into a scriptSig or segwit-v0 witness stack. Construction of the BIP-143 (or pre-segwit) sighash preimage is out of scope — the article assumes you already have the 32-byte digest to be signed, and links to the relevant BIPs.

> Important: secp256k1 is **not** NIST P-256. ``P256K`` wraps [bitcoin-core/secp256k1][libsecp256k1] and is incompatible with Apple CryptoKit's `P256` (the FIPS 186-4 NIST P-256 curve). If you arrived expecting `P256.Signing.ECDSASignature` semantics, see <doc:CryptoKitP256AndSecp256k1> for the curve-by-curve mapping. The rest of this article uses ``P256K/Signing`` exclusively.

Taproot key-path signatures — both single-key ([BIP-340][bip-340] Schnorr) and multi-key (BIP-327 MuSig2) — use Schnorr signatures with the BIP-341 sighash machinery and are out of scope here. See <doc:GettingStarted> for BIP-340 single-key Schnorr and <doc:MuSig2MultiSignatures> for BIP-327.

### Prerequisites

- A ``P256K/Signing/PrivateKey`` constructed from your wallet's key material — raw 32-byte scalar, PEM, or DER. See <doc:WorkingWithKeys> for the construction options.
- A 32-byte sighash digest for the input you want to sign, computed from your transaction's preimage per the relevant Bitcoin rule:
  - **Segwit v0** (P2WPKH, P2WSH, P2SH-wrapped variants): BIP-143 (see the Standards reference below).
  - **Pre-segwit** (P2PKH, bare P2SH, multisig): Bitcoin Core's legacy `SignatureHash` algorithm.
- The `P256K` package added to your project — see <doc:GettingStarted>.

### Producing an ECDSA signature on secp256k1 in Swift

``P256K/Signing/PrivateKey`` produces ECDSA signatures via two `signature(for:)` overloads — one taking a precomputed digest, one taking raw data. Both are **non-throwing** and return a ``P256K/Signing/ECDSASignature`` in lower-S normalized form. The lower-S guarantee comes from libsecp256k1's [`secp256k1_ecdsa_sign`][libsecp256k1-h], which normalizes internally before returning; `P256K` does not add or alter the normalization.

For Bitcoin, you almost always have a precomputed digest — the BIP-143 (or pre-segwit) sighash. Wrap the 32-byte sighash as a ``SHA256Digest`` and pass it to the `Digest` overload, which feeds the bytes directly to `secp256k1_ecdsa_sign` without re-hashing:

```swift
import P256K

// `sighashBytes` is the 32-byte SHA-256(SHA-256(preimage)) value from BIP-143.
let sighashDigest = SHA256Digest(Array(sighashBytes))
let signature = privateKey.signature(for: sighashDigest)
```

For other use cases where you have message bytes and want SHA-256 applied internally, the `Data` overload handles the hash for you:

```swift
import Foundation
import P256K

let message = "Hello, secp256k1!".data(using: .utf8)!
let signature = privateKey.signature(for: message)  // SHA-256 hashed internally
```

> Note: Both overloads use RFC 6979 deterministic nonces by default — the same private key and digest always produce the same signature, and there is no random-nonce reuse risk for non-MuSig signing paths. See <doc:SecurityConsiderations> for the nonce hygiene story across all signing schemes; the RFC anchor lives in the Standards reference below.

### Choosing between DER, compact, and the internal representation

A ``P256K/Signing/ECDSASignature`` exposes three byte forms. Choosing the right one matters for wire compatibility:

| Form | Length | Stable wire format? | Where it appears |
|---|---|---|---|
| ``P256K/Signing/ECDSASignature/derRepresentation`` | up to 72 bytes (typically 70-72) | Yes — SEC 1 v2 §4.1 ASN.1 DER | Bitcoin scriptSig / witness, TLS, X.509 |
| ``P256K/Signing/ECDSASignature/compactRepresentation`` | exactly 64 bytes (`r ‖ s` big-endian) | Yes | Nostr events, Lightning gossip, fixed-length contexts |
| ``P256K/Signing/ECDSASignature/dataRepresentation`` | 64 bytes | **No** | In-process retention only |

> Warning: ``P256K/Signing/ECDSASignature/dataRepresentation`` is the packed `secp256k1_ecdsa_signature` C struct buffer — its byte layout is **opaque and not stable across libsecp256k1 versions**. It is *not* the compact `r ‖ s` form despite also being 64 bytes long. Never persist or transmit it. For Bitcoin script, use ``P256K/Signing/ECDSASignature/derRepresentation``. For fixed-length non-Bitcoin contexts (Nostr, Lightning), use ``P256K/Signing/ECDSASignature/compactRepresentation``.

Round-trip a DER-encoded signature parsed from a Bitcoin script:

```swift
import P256K

let signature = try P256K.Signing.ECDSASignature(derRepresentation: derBytes)
let reencoded = signature.derRepresentation  // canonicalized DER
```

Round-trip a compact signature:

```swift
import P256K

let signature = try P256K.Signing.ECDSASignature(compactRepresentation: compactBytes)
let reencoded = signature.compactRepresentation  // 64 bytes
```

### Verifying an ECDSA signature

``P256K/Signing/PublicKey`` exposes `isValidSignature(_:for:)` overloads mirroring the signing side — one for a precomputed digest, one for raw data. Both return `Bool` and never throw:

```swift
import P256K

let isValid = publicKey.isValidSignature(signature, for: sighashDigest)
```

```swift
import P256K

let isValid = publicKey.isValidSignature(signature, for: messageData)  // SHA-256 hashed internally
```

The underlying `secp256k1_ecdsa_verify` call requires the signature to be in lower-S normalized form. Any signature `(r, s)` where `s > n/2` will fail — which is the topic of the next section.

### Why does an ECDSA signature from another library fail verification?

In nearly all real-world interop cases, **the signature is in high-S form**, and libsecp256k1's `secp256k1_ecdsa_verify` rejects it on purpose. Many older Bitcoin libraries, Java's standard ECDSA, and pre-2015 OpenSSL signers do not normalize to lower-S. A signature `(r, s)` with `s > n/2` is mathematically valid, but `secp256k1_ecdsa_verify` rejects it to prevent the malleability vector described in BIP-146 (see the Standards reference below).

If you control the producer, fix it there — every `P256K`-produced signature is already lower-S, and most modern Bitcoin libraries expose a "low-S" flag or post-process to canonical form. If the producer is out of your control, the canonicalization path within `P256K` today is narrow: the library does **not** expose a public lower-S normalize API on ``P256K/Signing/ECDSASignature``, and ``P256K/Recovery/ECDSASignature/normalize`` only converts a recoverable signature to the standard ECDSA shape — it does **not** lower-S normalize the result (the source-side guidance in <doc:RecoveringPublicKeys> states this explicitly). To canonicalize locally, parse the incoming bytes with ``P256K/Signing/ECDSASignature/init(derRepresentation:)``, copy the resulting ``P256K/Signing/ECDSASignature/dataRepresentation`` into a `secp256k1_ecdsa_signature` C struct, call `secp256k1_ecdsa_signature_normalize` via a direct libsecp256k1 binding (the package re-exports `libsecp256k1` as a target), and reconstruct an ``P256K/Signing/ECDSASignature`` from the canonicalized struct before handing it to ``P256K/Signing/PublicKey``.

### Signing a Bitcoin transaction input with ECDSA in Swift

Bitcoin's pre-Taproot script signature element is an ECDSA signature in DER form followed by a single sighash-type byte. The end-to-end recipe assumes the 32-byte sighash digest is already computed per BIP-143 (segwit v0) or the legacy pre-segwit `SignatureHash` algorithm:

```swift
import Foundation
import P256K

// 1. Wrap the precomputed 32-byte sighash as a SHA256Digest.
let sighashDigest = SHA256Digest(Array(sighashBytes))

// 2. Sign with the ECDSA private key controlling the input.
let signature = privateKey.signature(for: sighashDigest)

// 3. Emit DER bytes and append the SIGHASH-type byte.
let sighashType: UInt8 = 0x01  // SIGHASH_ALL
let signatureElement = signature.derRepresentation + Data([sighashType])
```

`signatureElement` is the signature value that goes into the scriptSig (legacy P2PKH, P2SH, multisig) or the witness stack (segwit-v0 P2WPKH, P2WSH). Full scriptSig / witness assembly — pushing the pubkey, the redeem script, the pushdata opcodes around this signature element — is **out of scope** for this article. Consult your transaction-builder library or BIP-143's *Specification* section (linked under Standards reference below) for the witness layout per script type.

The standard sighash-type bytes are:

| Value | Name | Meaning |
|---|---|---|
| `0x01` | `SIGHASH_ALL` | Signs every input and every output (the default for almost all wallets). |
| `0x02` | `SIGHASH_NONE` | Signs every input, no outputs. Outputs remain replaceable until broadcast. |
| `0x03` | `SIGHASH_SINGLE` | Signs every input and only the output at the matching index. Used in some atomic-swap and offer-style flows. |
| `0x80` | `SIGHASH_ANYONECANPAY` (modifier) | OR'd with one of the above to sign only the current input (e.g. `0x81` = `SIGHASH_ALL` + `SIGHASH_ANYONECANPAY`, allowing additional inputs to be added by other parties). |

> Important: `OP_CHECKSIG` and `OP_CHECKMULTISIG` expect the sighash byte to be appended to the DER signature. A bare DER signature without the trailing byte will fail script execution. Conversely, the sighash byte is **not** part of what gets signed — it tells the verifier which preimage to reconstruct, and must match the preimage used when signing.

To parse a signature element coming off the wire (from a confirmed transaction's scriptSig or witness), strip the trailing sighash byte and parse the remainder as DER:

```swift
import P256K

let sighashType = signatureElement.last!
let derBytes = signatureElement.dropLast()
let signature = try P256K.Signing.ECDSASignature(derRepresentation: derBytes)
```

Taproot key-path signatures use BIP-340 Schnorr against the BIP-341 sighash preimage — a different signing scheme, not a variant of this recipe. For single-key Taproot spends, see <doc:GettingStarted>; for multi-key Taproot, see <doc:MuSig2MultiSignatures>.

### Standards reference

The wire formats and signing rules in this article are defined by the following specifications. Each is the canonical citation for the behaviour the prior sections rely on:

- **[RFC 6979][rfc-6979]** — deterministic ECDSA nonce generation. The default mode for libsecp256k1's `secp256k1_ecdsa_sign` and therefore for every ``P256K/Signing/PrivateKey`` `signature(for:)` call.
- **[SEC 1: Elliptic Curve Cryptography v2 §4.1][sec1-v2]** — ASN.1 DER encoding of an ECDSA signature as `SEQUENCE { INTEGER r, INTEGER s }`. The wire format produced by ``P256K/Signing/ECDSASignature/derRepresentation`` and consumed by Bitcoin's `OP_CHECKSIG`.
- **[Bitcoin BIPs catalog][bips-catalog]** — the relevant proposals are:
  - **BIP-62** (2012, *withdrawn*) — the original comprehensive transaction-malleability proposal. Superseded by BIP-66 and BIP-146 but historically referenced for its rule numbering (e.g. "BIP-62 rule 6").
  - **BIP-66** (2015, *consensus rule*) — `SCRIPT_VERIFY_DERSIG`: strict DER encoding becomes a consensus rule on Bitcoin mainnet. Non-DER signatures are rejected at the script-verification layer.
  - **BIP-143** (2016, *consensus rule for segwit-v0*) — defines the sighash preimage construction for witness program v0 (P2WPKH, P2WSH, and P2SH-wrapped variants). The 32-byte digest you feed into the recipe above is the double-SHA-256 of this preimage. The *Specification* section enumerates the witness layout per script type.
  - **BIP-146** (2017, *standardness rule*) — `LOW_S` and `NULLFAIL` mempool / relay rules. Lower-S is not a consensus rule, but libsecp256k1's `secp256k1_ecdsa_verify` rejects high-S signatures unconditionally — which is what `P256K`'s verifier inherits, and the reason interop with non-normalizing libraries fails until the signature is canonicalized.

## See Also

- <doc:GettingStarted>
- <doc:WorkingWithKeys>
- <doc:RecoveringPublicKeys>
- <doc:SecurityConsiderations>
- <doc:CryptoKitP256AndSecp256k1>
- <doc:MuSig2MultiSignatures>
- ``P256K/Signing``
- ``P256K/Signing/PrivateKey``
- ``P256K/Signing/PublicKey``
- ``P256K/Signing/ECDSASignature``

[bip-340]: https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki
[bips-catalog]: https://github.com/bitcoin/bips
[libsecp256k1]: https://github.com/bitcoin-core/secp256k1
[libsecp256k1-h]: https://github.com/bitcoin-core/secp256k1/blob/master/include/secp256k1.h
[rfc-6979]: https://datatracker.ietf.org/doc/html/rfc6979
[sec1-v2]: https://www.secg.org/sec1-v2.pdf
