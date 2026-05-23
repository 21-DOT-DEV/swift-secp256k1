# Choosing Between P256K and ZKP

@Metadata {
    @TitleHeading("Explanation")
}

When to reach for ``P256K`` (vanilla secp256k1 for Bitcoin, Lightning, Nostr) versus ``ZKP`` (Blockstream's `secp256k1-zkp` fork for confidential transactions, adaptor signatures, and zero-knowledge proofs).

## Overview

The package ships two products that wrap two distinct C libraries: `P256K` wraps upstream `bitcoin-core/secp256k1`, while `ZKP` wraps the `BlockstreamResearch/secp256k1-zkp` fork of the same upstream codebase. The fork adds zero-knowledge proof primitives that the upstream library deliberately scopes out: range proofs (*Confidential Transactions*), surjection proofs (asset-swap unlinkability), ECDSA and BIP-340 adaptor signatures (atomic swaps and scriptless scripts), MuSig2 half-aggregation, and Bulletproofs++ (`bppp` trait). The decision between them is driven by which **set of opt-in traits** you need.

### The two products

Two trait tables live in `Package.swift`:

- **`moduleDefines`** — six traits that gate upstream secp256k1 modules: `ecdh`, `ellswift`, `musig`, `recovery`, `schnorrsig`, and `uint256`. Each one maps to an `ENABLE_MODULE_*` define on the C compilation.
- **`zkpModuleDefines`** — eight ZKP-only traits that gate the Blockstream fork's additional modules. The first seven are `bppp`, `ecdsaAdaptor`, `ecdsaS2C`, `generator`, `rangeproof`, `schnorrsigHalfagg`, and `surjectionproof`. The eighth trait gates Blockstream's allow-list-ring-signature module (identifier preserved verbatim in the upstream fork's public API; see the `zkpModuleDefines` entry in `Package.swift`).

Default-enabled traits for `P256K` are `ecdh`, `musig`, `recovery`, and `schnorrsig` (Package.swift `traits:` block). The `zkp` aggregate trait additionally enables every flag in `zkpModuleDefines` plus `ellswift`, mapping cleanly to the Liquid Network's confidential-transaction feature surface.

### When to reach for P256K

`P256K` is the default choice for Bitcoin, Lightning, Nostr, and any other application that uses vanilla secp256k1 cryptography. Concretely:

- **Bitcoin signing**: ECDSA with RFC 6979 deterministic nonces is the legacy script-signature scheme; `P256K.Signing.PrivateKey` produces lower-S-normalized signatures that pass `secp256k1_ecdsa_verify` without further processing.
- **Taproot signing**: BIP-340 Schnorr signatures (`P256K.Schnorr.PrivateKey`) are the v1 witness program signature scheme defined in [BIP-341][bip-341]. The construction itself is specified in BIP-340.
- **Multi-signature aggregation**: BIP-327 MuSig2 (`P256K.MuSig`) aggregates N signatures into a single 64-byte Schnorr signature, indistinguishable on-chain from a single-key spend. See [BIP-327][bip-327].
- **Nostr events**: NIP-01 signs events with a 32-byte x-only key (BIP-340 Schnorr); the `xonly` accessor on every Schnorr key returns the right shape.
- **Recoverable signatures**: Bitcoin signed-message workflows (BIP-137, BIP-322) use recoverable ECDSA (`P256K.Recovery`) so verifiers can recover the public key from the 65-byte `signature || recoveryId` payload alone, eliminating one round trip in address-discovery flows.

The bitcoin-core/secp256k1 README describes the upstream library's stability guarantees and threat model — `P256K` inherits those guarantees.

### When to reach for ZKP

`ZKP` is the right choice when your application needs **zero-knowledge proof primitives** that the upstream library deliberately scopes out. Each ZKP-only trait corresponds to a research result or production protocol:

- **Range proofs** (`rangeproof` trait): The original Confidential Transactions construction by Greg Maxwell (Bitcoin core developer) — proves that a Pedersen-committed value lies in a specified range without revealing the value itself. The canonical consumer is the [Liquid Network][liquid-net], Blockstream's federated sidechain. See Further reading for the original write-up.
- **Bulletproofs++** (`bppp` trait): A more efficient range-proof construction by Liu et al., reducing proof sizes versus original Bulletproofs while preserving the same security guarantees. See Further reading for the IACR preprint.
- **Surjection proofs** (`surjectionproof` trait): Prove that an output asset comes from one of N input assets without revealing which — the privacy backbone of Liquid's confidential-asset transactions.
- **Adaptor signatures** (`ecdsaAdaptor` trait): The scriptless-script primitive by Andrew Poelstra et al., documented at [github.com/ElementsProject/scriptless-scripts][scriptless-scripts]. Adaptor signatures enable atomic swaps, payment channels with non-script-based payment proofs, and discreet log contracts (DLCs).
- **MuSig2 half-aggregation** (`schnorrsigHalfagg` trait): Compresses N Schnorr signatures over distinct messages into roughly N/2 + 1 group elements; useful when batch-verifying many independent BIP-340 signatures.

If your application uses any of these primitives — even just one — `import ZKP` rather than `import P256K`. Mixed imports are technically possible but require fully-qualified `P256K.…` lookups to disambiguate the duplicated shared-source types.

### Shared cryptographic surface

`SharedSourcesPlugin` (declared in `Package.swift` as `.plugin(name: "SharedSourcesPlugin", capability: .buildTool())`) compiles every Swift file under `Sources/Shared/` into both `P256K` and `ZKP` builds. This means the entire vanilla cryptographic surface — ``P256K/Signing``, ``P256K/Schnorr``, ``P256K/MuSig``, ``P256K/Recovery``, ``P256K/KeyAgreement``, ``SHA256`` — is identical across the two products. Choosing `ZKP` does **not** sacrifice any vanilla capability; it adds to the surface.

### Stability guarantees

Both products are pre-1.0 — major-version zero per SemVer 2.0 §4: "Major version zero (`0.y.z`) is for initial development. Anything MAY change at any time. The public API SHOULD NOT be considered stable." Pin `exact:` versions in `Package.swift` to avoid surprise migrations. `P256K` is the planned long-term stability surface; `ZKP` tracks Blockstream's `secp256k1-zkp` fork, which itself tracks Bitcoin Core's stability cadence on the shared surface and Blockstream's research cadence on the proof-primitive surface.

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

### Further reading

Research-paper background for the zero-knowledge primitives discussed above:

- **Confidential Transactions** ([people.xiph.org/~greg/confidential_values.txt][confidential-tx-maxwell]) — Greg Maxwell's original write-up of Pedersen-committed value range proofs.
- **Bulletproofs++** ([eprint.iacr.org/2022/510][bulletproofs-pp]) — Liu, Nguyen, Yu, Au; IACR preprint introducing the construction behind the `bppp` trait.

## See Also

- ``P256K``
- ``ZKP``

[bip-327]: https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki
[bip-341]: https://github.com/bitcoin/bips/blob/master/bip-0341.mediawiki
[bulletproofs-pp]: https://eprint.iacr.org/2022/510
[confidential-tx-maxwell]: https://people.xiph.org/~greg/confidential_values.txt
[liquid-net]: https://liquid.net/
[scriptless-scripts]: https://github.com/ElementsProject/scriptless-scripts
