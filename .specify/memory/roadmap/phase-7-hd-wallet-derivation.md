# Phase 7: HD-Wallet & Key Derivation

**Goal**: The hierarchical-deterministic wallet stack — BIP-32/39 derivation + extended-key serialization — composing the SHA-2 tower with EC key tweaks  
**Horizon**: 🟡 Next  
**Status**: 🔜 Planned  
**Reach**: ★★★★☆ — Bitcoin/Lightning wallets, Nostr (NIP-06), Cashu (NUT-13)  
**Depends On**: Phase 5 (HMAC-SHA512, PBKDF2-SHA512); Phase 4 (Base58Check for xpub/xprv)  
**Last Updated**: 2026-06-05

A single BIP-32/39 implementation serves Bitcoin wallets, Nostr NIP-06, and Cashu NUT-13. Downstream hand-rolls these today (`serializedPoint`, `bip32SeedSalt`).

---

## Features

### BIP-32 Child Key Derivation + Extended-Key Serialization

**Purpose & User Value**: HD key trees + xpub/xprv interchange (and key fingerprints for PSBT/descriptors).

**Success Metrics**:
- CKD via `HMAC-SHA512(Key=cpar, …)` + scalar/point tweak (EC — already shipped)
- 78-byte extended-key serialization (versions `0x0488ADE4` priv / `0x0488B21E` pub) + Base58Check (Phase 4)
- Key fingerprint = first 4 bytes of `HASH160(pubkey)`
- BIP-32 test vectors pass

### BIP-39 Mnemonic → Seed

**Purpose & User Value**: Mnemonic-to-seed (also Nostr NIP-06 path `m/44'/1237'/…`).

**Success Metrics**:
- `PBKDF2-HMAC-SHA512`, 2048 iterations, 64-byte seed, UTF-8 NFKD (Phase 5)
- Wordlist + checksum validation
- BIP-39 test vectors pass

### HASH160 / RIPEMD-160 (Zone C — low priority)

**Purpose & User Value**: BIP-32 fingerprints, legacy P2PKH/P2WPKH addresses, BOLT-3 Lightning HTLC scripts.
**Notes**: RIPEMD-160 is a separate (non-SHA-2) hash → low priority; **swift-openssl is the fallback** until built here (see Package Separation). HASH160 = SHA-256 → RIPEMD-160.

---

## Out of scope here

- **scrypt** (BIP-38 / NIP-49) → swift-openssl (Zone D).

---

## Phase Dependencies & Sequencing

1. **BIP-32 CKD + serialization** — after Phase 5 HMAC-SHA512 + Phase 4 Base58Check
2. **BIP-39** — after Phase 5 PBKDF2
3. **HASH160 / RIPEMD-160** — low priority; openssl fallback meanwhile

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| BIP-32 / BIP-39 vector pass rate | 100% |
| xpub/xprv round-trip | 100% |
| External dependencies added | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Secret handling in derivation | Key leakage | Zeroize intermediates; opaque seed types (Constitution III) |
| RIPEMD-160 from-scratch effort | Delay | Low priority; defer to swift-openssl until scheduled |
