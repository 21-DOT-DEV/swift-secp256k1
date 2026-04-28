# Silent Payments

@Metadata {
    @TitleHeading("How-to Guide")
}

Send Bitcoin to a reusable static address without on-chain linkability or sender–receiver interaction, using the [BIP-352](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki) Silent Payments protocol.

## Overview

[Silent Payments](https://bitcoinops.org/en/topics/silent-payments/) ([BIP-352](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki), Status: Complete, Version 1.0.2) lets a receiver publish a single static address while still receiving every payment to a fresh, unlinkable on-chain output. The sender derives the destination locally using ECDH between the receiver's published scan key and the sender's transaction inputs — no notification transactions, no out-of-band coordination, no on-chain footprint identifying the receiver.

This solves the long-standing tension between **address reuse** (privacy-degrading; reveals that the same wallet received multiple payments) and **interactive address generation** (often infeasible — donations, content monetization, recurring payroll). Existing alternatives such as BIP-47 PayNyms or stealth-address protocols require on-chain notification transactions that increase fees and reveal metadata. BIP-352 produces transactions indistinguishable from any other taproot spend.

The trade-off is **scanning cost**: receivers must perform an ECDH multiplication per scanned transaction. This is feasible for full nodes; light-client support is an area of [open research](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki#appendix-a-light-client-support).

This guide walks through the cryptographic core of BIP-352 using `P256K`'s primitives. **It is an educational walkthrough, not a complete BIP-352 implementation** — see the [Production Considerations](#Production-Considerations) and [Reference Implementations](#Reference-Implementations) sections for everything you must add for a wallet-grade integration.

### The Core Formula

The simple case (one input, no labels, no scan/spend split) reduces to one line:

```
P = B + hash(a·B)·G
```

where `a` is the sender's input private key, `B` is the receiver's published public key, `G` is the secp256k1 generator. Because `a·B == b·A` (the standard ECDH identity), the receiver can compute the same `P` using their own private key `b` against the sender's public input key `A`, and scan transactions for outputs matching `P`.

The full BIP-352 protocol layers four refinements on top:

1. **Sum all eligible inputs** rather than one — works inside CoinJoins, makes light-client filtering tractable.
2. **Add an input hash** committing to the smallest outpoint — prevents address reuse when the sender reuses an input set.
3. **Add an output counter `k`** — lets a single payment produce multiple destination outputs (CoinJoin-shaped privacy, change splitting).
4. **Split scan and spend keys** `(B_scan, B_spend)` — the receiver can keep `b_spend` in cold storage while `b_scan` runs online.

The remaining refinement — labels (`B_m = B_spend + hash_BIP0352/Label(b_scan || m)·G`) — lets a single address differentiate incoming payments without re-publishing.

### Tagged Hashes

BIP-352 specifies three [BIP-340-style tagged hashes](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki#design) to prevent cross-protocol collisions, each computed as `SHA256(SHA256(tag) || SHA256(tag) || message)`:

| Tag | Used for |
|---|---|
| `BIP0352/Inputs` | The `input_hash` committing to the smallest outpoint |
| `BIP0352/SharedSecret` | The shared-secret derivation `hash(input_hash·a·B || k)` |
| `BIP0352/Label` | Optional label tweaks `hash(b_scan || m)` |

`P256K` provides BIP-340 tagged hashing via ``SHA256/taggedHash(tag:data:)`` — pass the tag string above as UTF-8 bytes.

### Sender: Deriving the Destination Output

For a sender with a single input `(a, A)` and a receiver with published public key `B` (33-byte compressed):

```swift
import Foundation
import P256K

// Inputs: sender's private key, receiver's published public key, an outpoint
let aliceSigningKey = try P256K.Signing.PrivateKey()  // (a, A)

// Bob's `B` is published as a compressed 33-byte point; create both views.
// `bobECDHKey` participates in ECDH; `bobSigningKey` is the base point we
// add the shared-secret tweak to in Step 4. Both wrap the same point.
let bobPublicKeyBytes: Data = /* 33-byte compressed B from Bob's address */
let bobECDHKey = try P256K.KeyAgreement.PublicKey(
    dataRepresentation: bobPublicKeyBytes,
    format: .compressed
)
let bobSigningKey = try P256K.Signing.PublicKey(
    dataRepresentation: bobPublicKeyBytes,
    format: .compressed
)

let smallestOutpoint: Data = /* 36-byte COutPoint: little-endian txid || vout */

// Step 1: input_hash = hash_BIP0352/Inputs(outpoint_L || A)
let inputHashInput = smallestOutpoint + aliceSigningKey.publicKey.dataRepresentation
let inputHash = SHA256.taggedHash(
    tag: "BIP0352/Inputs".data(using: .utf8)!,
    data: inputHashInput
)

// Step 2: ECDH between (input_hash * a) and B.
// The spec writes the shared point as input_hash·a·B; with one input, this is
// input_hash·a applied as a private-key tweak via `multiply`, then ECDH with B.
let tweakedPrivateKey = try aliceSigningKey.multiply(Array(inputHash))
let tweakedECDHKey = try P256K.KeyAgreement.PrivateKey(
    dataRepresentation: tweakedPrivateKey.dataRepresentation
)
let sharedPoint = tweakedECDHKey.sharedSecretFromKeyAgreement(with: bobECDHKey)

// Step 3: shared_secret_k = hash_BIP0352/SharedSecret(sharedPoint || ser_32(k))
let k: UInt32 = 0
let kBytes = withUnsafeBytes(of: k.bigEndian) { Data($0) }
let sharedSecret = SHA256.taggedHash(
    tag: "BIP0352/SharedSecret".data(using: .utf8)!,
    data: Data(sharedPoint.bytes) + kBytes
)

// Step 4: P_k = B + sharedSecret·G — produce the BIP-341 x-only output key.
let destination = try bobSigningKey.add(Array(sharedSecret))
let destinationXonly = destination.xonly.bytes  // [UInt8] of length 32
// The taproot scriptPubKey is: OP_1 OP_PUSHBYTES_32 <destinationXonly>
```

For multiple inputs, sum the input private keys (`a = a_1 + a_2 + ... + a_n`) before computing the input hash and the ECDH step. See <doc:TweakingKeys> for the additive-tweak primitives.

### Receiver: Scanning for Incoming Payments

The receiver reconstructs the same shared secret using their scan key `b_scan` and the **summed input public key** `A` extracted from the candidate transaction. `B_spend` is the receiver's spend key — the base point that gets tweak-added to produce each `P_k`:

```swift
let bobScanKey: P256K.KeyAgreement.PrivateKey = /* b_scan */
let bobSpendBytes: Data = /* B_spend as 33-byte compressed point */
let bobSpendKey = try P256K.Signing.PublicKey(
    dataRepresentation: bobSpendBytes,
    format: .compressed
)

let summedInputPubKey: P256K.KeyAgreement.PublicKey = /* A from tx inputs */
let smallestOutpoint: Data = /* same 36-byte COutPoint as sender */

// Step 1: reproduce input_hash with summed input pubkey (A)
let inputHashInput = smallestOutpoint + summedInputPubKey.dataRepresentation
let inputHash = SHA256.taggedHash(
    tag: "BIP0352/Inputs".data(using: .utf8)!,
    data: inputHashInput
)

// Step 2: ECDH on receiver's side: input_hash·b_scan·A
// (KeyAgreement.PrivateKey exposes raw bytes as `rawRepresentation`,
//  unlike the other private-key types which use `dataRepresentation`.)
let tweakedScanKey = try P256K.Signing.PrivateKey(
    dataRepresentation: bobScanKey.rawRepresentation
).multiply(Array(inputHash))
let tweakedScanECDH = try P256K.KeyAgreement.PrivateKey(
    dataRepresentation: tweakedScanKey.dataRepresentation
)
let sharedPoint = tweakedScanECDH.sharedSecretFromKeyAgreement(with: summedInputPubKey)

// Step 3 & 4: derive P_k for k = 0, 1, 2... and check transaction outputs
var k: UInt32 = 0
let txOutputs: [Data] = /* x-only output keys from the candidate tx */

while true {
    let kBytes = withUnsafeBytes(of: k.bigEndian) { Data($0) }
    let sharedSecret = SHA256.taggedHash(
        tag: "BIP0352/SharedSecret".data(using: .utf8)!,
        data: Data(sharedPoint.bytes) + kBytes
    )
    let candidate = try bobSpendKey.add(Array(sharedSecret))
    let candidateXonly = candidate.xonly.bytes  // [UInt8] of length 32

    if !txOutputs.contains(Data(candidateXonly)) {
        break  // No more matches — stop incrementing
    }
    // Found a match: candidate is one of Bob's outputs.
    // Spending key: (b_spend + sharedSecret) mod n — derive when ready to spend.
    k += 1
}
```

The receiver only does the per-`k` SHA-256 work after a `k=0` match, keeping the scan cost bounded.

### Scan and Spend Key Separation

To minimize hot-key exposure, BIP-352 separates the receiver's address into a scan key and a spend key:

```
silent-payment-address = encode(B_scan, B_spend)
```

The scanning workflow needs `b_scan` (private) plus `B_spend` (public) — both online. The signing workflow that finally spends a discovered output needs `b_spend` (private) — which can stay in cold storage. Compromise of the scanning host leaks transaction discoverability (the attacker learns that Bob received payments and how much) but **does not let the attacker spend** any output. This mirrors view-key/spend-key separation in privacy coins like Monero.

### Address Encoding

A BIP-352 address is a [Bech32m](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki) encoding of `ser_P(B_scan) || ser_P(B_m)` (66 bytes total) with HRP `sp` (mainnet) or `tsp` (testnets), version `q` (= v0). The minimum address length is 117 characters; implementations should accept up to 1023 characters per the [BIP-173 checksum-design recommendation](https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki#checksum-design).

`P256K` does not currently ship a Bech32m encoder. For end-to-end address handling, pair it with a Bech32m library or implement encoding per [BIP-350](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki).

### Production Considerations

The walkthrough above shows the cryptographic core. A wallet-grade implementation also requires:

- **Eligible-input filtering**. Only `P2TR`, `P2WPKH`, `P2SH-P2WPKH`, and `P2PKH` inputs (with X-only or compressed public keys) participate in shared-secret derivation. Mixed-input transactions skip ineligible inputs.
- **Sighash flag restrictions**. Senders must use `DEFAULT`, `ALL`, `SINGLE`, or `NONE`. `ANYONECANPAY` is **unsafe** because changing inputs after signing breaks the receiver's ability to derive the shared secret.
- **Transaction-level scan filter**. Skip transactions with no taproot output, no eligible input, or any SegWit-version-greater-than-1 input.
- **Label support**. The change label `m = 0` is reserved and must be scanned for during wallet recovery; never hand it out as a payment label.
- **Bech32m encoding/decoding** with HRP and version validation (`sp1q…`, `tsp1q…`).
- **Forward compatibility**. Reading a `v1`–`v30` address means reading the first 66 bytes of the data part and discarding the rest; `v31` (`l`) is reserved for backwards-incompatible changes.

The protocol explicitly leaves CoinJoin support and light-client filter design as **open research** — do not deploy BIP-352 for collaborative-input transactions without a security review, and treat any light-client implementation as experimental.

### Reference Implementations

For a complete BIP-352 implementation to compare against, study these:

- [Bitcoin Core PR #28122](https://github.com/bitcoin/bitcoin/pull/28122) — the canonical reference implementation, written by the BIP authors.
- [`silentpayments-rs`](https://github.com/cygnet3/silentpayments-rs) — Rust reference library used by silent-payments-light-client work.
- [Optech Silent Payments topic](https://bitcoinops.org/en/topics/silent-payments/) — running list of newsletter coverage, ecosystem deployments, and related research.

### Further Reading

- [BIP-352: Silent Payments](https://github.com/bitcoin/bips/blob/master/bip-0352.mediawiki) — the canonical specification (authors: josibake, Ruben Somsen, Sebastian Falbesoner)
- [Bitcoin Optech: Silent payments topic](https://bitcoinops.org/en/topics/silent-payments/) — protocol context, deployment status, related protocols
- [Original 2022 bitcoin-dev proposal](https://gnusha.org/pi/bitcoindev/CAPv7TjbXm953U2h+-12MfJ24YqOM5Kcq77_xFTjVK+R2nf-nYg@mail.gmail.com/) by Ruben Somsen
- [BIP-340: Schnorr Signatures](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) — tagged-hash conventions inherited by BIP-352
- [BIP-341: Taproot output rules](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki) — output encoding for Silent Payments destinations

## See Also

- <doc:EllipticCurveDiffieHellman>
- <doc:TweakingKeys>
- <doc:SecurityConsiderations>
- ``P256K/KeyAgreement``
- ``P256K/Schnorr``
