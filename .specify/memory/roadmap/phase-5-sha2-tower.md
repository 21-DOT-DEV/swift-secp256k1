# Phase 5: SHA-2 Hash & MAC Tower

**Goal**: The SHA-2-rooted hash / MAC / KDF tower, built on the SHA-256 + HMAC-SHA256 cores already in libsecp256k1's C  
**Horizon**: 🔵 Now  
**Status**: 🔜 Planned  
**Reach**: ★★★★☆ — Lightning Sphinx (HMAC-SHA256), Nostr NIP-44 (HKDF+HMAC), BIP-32 (HMAC-SHA512), Cashu  
**Depends On**: none (cores already vendored in C)  
**Blocks**: Phase 7 (HD-Wallet), Phase 4 (Base58Check needs double-SHA256)  
**Last Updated**: 2026-06-05

Zone B of the **Package Separation** ([roadmap.md](../roadmap.md)): cheap because libsecp256k1 already ships `secp256k1_sha256`, `secp256k1_hmac_sha256`, and `secp256k1_rfc6979_hmac_sha256` (an HMAC-DRBG) in C. Building this tower makes the package **self-sufficient for the Bitcoin core** with zero new dependencies.

---

## Features

### HMAC-SHA256 (expose existing C)

**Purpose**: Load-bearing for Lightning — BOLT-4 Sphinx derives per-hop keys *and* packet integrity via HMAC-SHA256 (*not* HKDF). Also the NIP-44 MAC and Cashu.
**Notes**: `secp256k1_hmac_sha256` already exists in C (used for RFC-6979) — surface it via the same path as `P256K.SHA256`. Ship a **constant-time compare** helper for MAC verification.

### SHA-512 (+ SHA-512/256)

**Purpose**: Root for HMAC-SHA512 (BIP-32) and PBKDF2 (BIP-39).
**Notes**: Not in libsecp256k1 — mirror the `secp256k1_sha256` structure (64-bit words, 80 rounds, new IV/constants). NIST vectors.

### HMAC-SHA512

**Purpose**: BIP-32 child key derivation (`HMAC-SHA512(Key="Bitcoin seed", …)`) and BIP-39.
**Notes**: Mirror `secp256k1_hmac_sha256` over the SHA-512 core. RFC-4231 vectors.

### HKDF-SHA256 / HKDF-SHA512

**Purpose**: NIP-44 v2 key schedule — **separately-exposed** extract + expand. RFC-5869 vectors.
**Notes**: Pure composition over HMAC — no new core.

### double-SHA256

**Purpose**: Base58Check checksum (Phase 4), BIP-32 serialization, BOLT12 merkle leaves. Trivial (two SHA-256 calls).

### HMAC-DRBG (expose RFC-6979)

**Purpose**: Deterministic bit generation. `secp256k1_rfc6979_hmac_sha256` already in C — surface it.

---

## Out of scope here (see Package Separation)

- **scrypt, ChaCha20, AES, SHA-3 / Keccak** → swift-openssl (Zone D).
- **SipHash, SHA-512/256** → Zone C (built-here, low priority); SipHash is tied to BIP-152/158 filters in the backlog.
- **MurmurHash3** → backlog (BIP-37 deprecated; not in OpenSSL).

---

## Phase Dependencies & Sequencing

1. **HMAC-SHA256** + **double-SHA256** — expose/trivial; unblock Phase 4 Base58Check + Lightning Sphinx
2. **SHA-512** → **HMAC-SHA512** → **HKDF** — the BIP-32 / NIP-44 chain
3. **HMAC-DRBG** — expose RFC-6979

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| NIST SHA-512 / RFC-4231 HMAC / RFC-5869 HKDF vectors | 100% pass |
| Constant-time MAC verification | Verified |
| External dependencies added | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Surfacing static C (`secp256k1_hmac_sha256`) | Linkage friction | Reuse the shim path already used for `secp256k1_sha256` |
| Hand-rolled SHA-512 correctness | Silent wrong hashes | NIST vectors + cross-check against swift-openssl |
