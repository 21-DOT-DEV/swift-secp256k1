# ``ZKP``

@Metadata {
    @TitleHeading("Framework")
}

Zero-knowledge proof primitives for the secp256k1 curve — adaptor signatures, range proofs, surjection proofs, and MuSig2 half-aggregation — layered on Blockstream's `secp256k1-zkp` fork of `libsecp256k1`.

## Overview

`ZKP` wraps the [BlockstreamResearch/secp256k1-zkp](https://github.com/BlockstreamResearch/secp256k1-zkp) fork of upstream [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1). The fork adds zero-knowledge proof primitives that the upstream library deliberately scopes out: range proofs (*Confidential Transactions*), surjection proofs (asset-swap unlinkability), ECDSA and BIP-340 adaptor signatures (atomic swaps and scriptless scripts), MuSig2 half-aggregation, and Bulletproofs++ (`bppp` trait). Blockstream's [Liquid Network](https://liquid.net/) — the canonical consumer — depends on the fork for its confidential-asset transaction format.

`ZKP` shares the same vanilla cryptographic surface as ``P256K`` via the package's `SharedSourcesPlugin` build-tool plugin: every type in `Sources/Shared/` (ECDSA, BIP-340 Schnorr, BIP-327 MuSig2, ECDH, recoverable signatures, SHA-256, tagged hashes) is compiled into both products. The two products differ only in their underlying C library (`libsecp256k1` vs `libsecp256k1_zkp`) and the set of opt-in traits each enables. Read <doc:ChoosingP256KvsZKP> to decide which product fits your application.

> Note: The ZKP-exclusive zero-knowledge surface is C-only at present — Swift wrappers for range proofs, surjection proofs, adaptor signatures, and MuSig2 half-aggregation will be added incrementally. The shared surface listed below is fully supported today.

## Topics

### Essentials

- <doc:ChoosingP256KvsZKP>
- ``P256K``
- ``P256K/Context``
- ``P256K/Format``

### ECDSA

- ``P256K/Signing``
- ``P256K/Signing/PrivateKey``
- ``P256K/Signing/PublicKey``
- ``P256K/Signing/XonlyKey``
- ``P256K/Signing/ECDSASignature``

### BIP-340 Schnorr

- ``P256K/Schnorr``
- ``P256K/Schnorr/PrivateKey``
- ``P256K/Schnorr/PublicKey``
- ``P256K/Schnorr/XonlyKey``
- ``P256K/Schnorr/SchnorrSignature``

### BIP-327 MuSig2

- ``P256K/MuSig``
- ``P256K/MuSig/PublicKey``
- ``P256K/MuSig/Nonce``

### Recoverable signatures

- ``P256K/Recovery``
- ``P256K/Recovery/PrivateKey``
- ``P256K/Recovery/PublicKey``
- ``P256K/Recovery/ECDSASignature``

### ECDH key agreement

- ``P256K/KeyAgreement``
- ``P256K/KeyAgreement/PrivateKey``
- ``P256K/KeyAgreement/PublicKey``
- ``SharedSecret``

### Hashing

- ``SHA256``
- ``HashDigest``

### Errors

- ``secp256k1Error``
