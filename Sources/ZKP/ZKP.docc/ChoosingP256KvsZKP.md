# Choosing Between P256K and ZKP

@Metadata {
    @TitleHeading("Explanation")
}

When to reach for ``P256K`` (vanilla secp256k1 for Bitcoin, Lightning, Nostr) versus ``ZKP`` (Blockstream's `secp256k1-zkp` fork for confidential transactions, adaptor signatures, and zero-knowledge proofs).

## Overview

The package ships two products that wrap two distinct C libraries: `P256K` wraps upstream [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1), while `ZKP` wraps the [BlockstreamResearch/secp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp) fork of upstream [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1). The fork adds zero-knowledge proof primitives that the upstream library deliberately scopes out: range proofs (*Confidential Transactions*), surjection proofs (asset-swap unlinkability), ECDSA and BIP-340 adaptor signatures (atomic swaps and scriptless scripts), MuSig2 half-aggregation, and Bulletproofs++ (`bppp` trait). The decision between them is driven by which **set of opt-in traits** you need.

### The two products

Two trait tables live in `Package.swift` (see [the full declaration on GitHub](https://github.com/21-DOT-DEV/swift-secp256k1/blob/main/Package.swift)):

- **`moduleDefines`** — six traits that gate upstream secp256k1 modules: `ecdh`, `ellswift`, `musig`, `recovery`, `schnorrsig`, and `uint256`. Each one maps to an `ENABLE_MODULE_*` define on the C compilation.
- **`zkpModuleDefines`** — eight ZKP-only traits that gate the Blockstream fork's additional modules. The first seven are `bppp`, `ecdsaAdaptor`, `ecdsaS2C`, `generator`, `rangeproof`, `schnorrsigHalfagg`, and `surjectionproof`. The eighth trait gates Blockstream's allow-list-ring-signature module (identifier preserved verbatim in the upstream fork's public API; see the `zkpModuleDefines` entry in `Package.swift` and the [BlockstreamResearch/secp256k1-zkp module layout](https://github.com/BlockstreamResearch/secp256k1-zkp)).

Default-enabled traits for `P256K` are `ecdh`, `musig`, `recovery`, and `schnorrsig` (Package.swift `traits:` block). The `zkp` aggregate trait additionally enables every flag in `zkpModuleDefines` plus `ellswift`, mapping cleanly to the Liquid Network's confidential-transaction feature surface.

### When to reach for P256K

`P256K` is the default choice for Bitcoin, Lightning, Nostr, and any other application that uses vanilla secp256k1 cryptography. Concretely:

- **Bitcoin signing**: ECDSA with RFC 6979 deterministic nonces is the legacy script-signature scheme; `P256K.Signing.PrivateKey` produces lower-S-normalized signatures that pass `secp256k1_ecdsa_verify` without further processing.
- **Taproot signing**: BIP-340 Schnorr signatures (`P256K.Schnorr.PrivateKey`) are the v1 witness program signature scheme defined in [BIP-341](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki). Cite [BIP-340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) for the signature construction itself.
- **Multi-signature aggregation**: BIP-327 MuSig2 (`P256K.MuSig`) aggregates N signatures into a single 64-byte Schnorr signature, indistinguishable on-chain from a single-key spend. See [BIP-327](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki).
- **Nostr events**: NIP-01 signs events with a 32-byte x-only key (BIP-340 Schnorr); the `xonly` accessor on every Schnorr key returns the right shape.
- **Recoverable signatures**: Bitcoin signed-message workflows ([BIP-137](https://github.com/bitcoin/bips/blob/master/bip-0137.mediawiki), [BIP-322](https://github.com/bitcoin/bips/blob/master/bip-0322.mediawiki)) use recoverable ECDSA (`P256K.Recovery`) so verifiers can recover the public key from the 65-byte `signature || recoveryId` payload alone, eliminating one round trip in address-discovery flows.

The bitcoin-core README at [github.com/bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1) describes the upstream library's stability guarantees and threat model — `P256K` inherits those guarantees.

### When to reach for ZKP

`ZKP` is the right choice when your application needs **zero-knowledge proof primitives** that the upstream library deliberately scopes out. Each ZKP-only trait corresponds to a research result or production protocol:

- **Range proofs** (`rangeproof` trait): The original [Confidential Transactions](https://people.xiph.org/~greg/confidential_values.txt) construction by Greg Maxwell (Bitcoin core developer) — proves that a Pedersen-committed value lies in a specified range without revealing the value itself. The canonical consumer is the [Liquid Network](https://liquid.net/), Blockstream's federated sidechain.
- **Bulletproofs++** (`bppp` trait): A more efficient range-proof construction by Liu et al. ([eprint/2022/510](https://eprint.iacr.org/2022/510)), reducing proof sizes versus original Bulletproofs while preserving the same security guarantees.
- **Surjection proofs** (`surjectionproof` trait): Prove that an output asset comes from one of N input assets without revealing which — the privacy backbone of Liquid's confidential-asset transactions.
- **Adaptor signatures** (`ecdsaAdaptor` trait): The scriptless-script primitive by Andrew Poelstra et al., documented at [github.com/ElementsProject/scriptless-scripts](https://github.com/ElementsProject/scriptless-scripts). Adaptor signatures enable atomic swaps, payment channels with non-script-based payment proofs, and discreet log contracts (DLCs).
- **MuSig2 half-aggregation** (`schnorrsigHalfagg` trait): Compresses N Schnorr signatures over distinct messages into roughly N/2 + 1 group elements; useful when batch-verifying many independent BIP-340 signatures.

If your application uses any of these primitives — even just one — `import ZKP` rather than `import P256K`. Mixed imports are technically possible but require fully-qualified `P256K.…` lookups to disambiguate the duplicated shared-source types.

### Shared cryptographic surface

`SharedSourcesPlugin` (declared in `Package.swift` as `.plugin(name: "SharedSourcesPlugin", capability: .buildTool())`) compiles every Swift file under `Sources/Shared/` into both `P256K` and `ZKP` builds. This means the entire vanilla cryptographic surface — ``P256K/Signing``, ``P256K/Schnorr``, ``P256K/MuSig``, ``P256K/Recovery``, ``P256K/KeyAgreement``, ``SHA256`` — is identical across the two products. Choosing `ZKP` does **not** sacrifice any vanilla capability; it adds to the surface.

### Stability guarantees

Both products are pre-1.0 — major-version zero per [SemVer 2.0 §4](https://semver.org/#spec-item-4): "Major version zero (`0.y.z`) is for initial development. Anything MAY change at any time. The public API SHOULD NOT be considered stable." Pin `exact:` versions in `Package.swift` to avoid surprise migrations. `P256K` is the planned long-term stability surface; `ZKP` tracks Blockstream's `secp256k1-zkp` fork, which itself tracks Bitcoin Core's stability cadence on the shared surface and Blockstream's research cadence on the proof-primitive surface.

### Mixing products

Both products can be imported in the same Swift file — each links its own copy of the underlying C library with disjoint trait flags. The shared Swift types (defined in `Sources/Shared/`) are the same source by identity but live in two distinct module namespaces (`P256K.…` and `ZKP.…`); ambiguous references in mixed-import contexts must be fully qualified. Most applications avoid the friction by picking one product per target:

```swift
// Bitcoin / Lightning / Nostr stack: vanilla cryptography only.
import P256K

let signingKey = try P256K.Signing.PrivateKey()
let signature = signingKey.signature(for: message)
```

```swift
// Liquid / Elements stack: range proofs, surjection proofs,
// adaptor signatures, MuSig2 half-aggregation.
import ZKP

// All P256K-equivalent APIs are available here too, plus the
// ZK extensions gated by the `zkp` aggregate trait.
let signingKey = try P256K.Signing.PrivateKey()
```

## See Also

- ``P256K``
- ``ZKP``
- [bitcoin-core/secp256k1 README](https://github.com/bitcoin-core/secp256k1/blob/master/README.md)
- [BlockstreamResearch/secp256k1-zkp README](https://github.com/BlockstreamResearch/secp256k1-zkp/blob/master/README.md)
- [BIP-340: Schnorr Signatures for secp256k1](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki)
- [BIP-327: MuSig2 for BIP-340 Schnorr signatures](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki)
- [BIP-341: Taproot — SegWit version 1 spending rules](https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki)
- [Liquid Network](https://liquid.net/)
