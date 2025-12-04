# Phase 7: Long-term — Key Derivation Functions

**Goal**: Implement password-based key derivation functions for BIP wallet standards  
**Status**: 📋 Future  
**Last Updated**: 2025-12-03  
**Depends On**: Phase 6 (HMAC-SHA512 for PBKDF2)

---

## Features

### PBKDF2-SHA512

**Purpose & User Value**:  
Implement PBKDF2 with HMAC-SHA512 for BIP-39 mnemonic-to-seed derivation. The standard method for converting mnemonic phrases to HD wallet seeds.

**Success Metrics**:
- Passes RFC 6070 test vectors (adapted for SHA-512)
- Passes BIP-39 test vectors
- 2048 iterations supported (BIP-39 standard)
- Zero external dependencies
- Constant-time behavior

**Dependencies**:
- Phase 6 HMAC-SHA512

**Notes**:
- BIP-39: `seed = PBKDF2(password=mnemonic, salt="mnemonic"+passphrase, iterations=2048, dkLen=64)`
- Also used in BIP-129 for DKey derivation
- Performance: 2048 iterations should complete < 100ms on modern devices

---

### scrypt

**Purpose & User Value**:  
Implement scrypt for BIP-38 encrypted private key storage. Memory-hard KDF that resists hardware brute-force attacks.

**Success Metrics**:
- Passes RFC 7914 test vectors
- BIP-38 parameters supported: N=16384, r=8, p=8
- Zero external dependencies
- Memory-hard properties preserved

**Dependencies**:
- None (can be implemented standalone, but benefits from HMAC-SHA256)

**Notes**:
- BIP-38: Password-protected private keys
- Memory requirements: ~16MB with BIP-38 parameters
- Consider: memory allocation strategy on constrained devices
- Lower priority than PBKDF2 (BIP-38 less common than BIP-39)

---

## Phase Dependencies & Sequencing

```
Phase 6 HMAC-SHA512 ──► PBKDF2-SHA512 ──► (enables BIP-39)

Standalone ──► scrypt ──► (enables BIP-38)
```

**Priority order**:
1. **PBKDF2-SHA512** — higher priority (BIP-39 is ubiquitous)
2. **scrypt** — lower priority (BIP-38 is niche)

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| RFC test vector pass rate | 100% |
| BIP-39 test vector pass rate | 100% |
| BIP-38 test vector pass rate | 100% |
| PBKDF2 performance (2048 iterations) | < 100ms |
| scrypt memory usage | ~16MB (BIP-38 params) |

---

## API Design Notes

**Proposed API**:

```swift
// PBKDF2
P256K.PBKDF2.deriveKey(
    password: Data,
    salt: Data,
    iterations: Int,
    keyLength: Int,
    hashFunction: .sha512
) -> Data

// BIP-39 convenience
P256K.BIP39.seed(mnemonic: String, passphrase: String = "") -> Data

// scrypt
P256K.scrypt.deriveKey(
    password: Data,
    salt: Data,
    n: Int,      // CPU/memory cost
    r: Int,      // block size
    p: Int,      // parallelization
    keyLength: Int
) -> Data

// BIP-38 convenience
P256K.BIP38.encrypt(privateKey: PrivateKey, passphrase: String) -> String
P256K.BIP38.decrypt(encrypted: String, passphrase: String) -> PrivateKey
```

---

## Scope Consideration

**Note from roadmap planning**: The general-purpose nature of PBKDF2 and scrypt (not secp256k1-specific) raised scope questions. Decision was to backlog scope decision—these may:
- Live in swift-secp256k1 as Bitcoin utilities
- Be recommended as separate packages
- Be included but marked as "Bitcoin utility" not core crypto

This decision should be revisited when Phase 7 begins.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| scrypt memory requirements | Crashes on constrained devices | Document requirements; consider streaming/chunked implementation |
| Performance too slow | Poor UX | Benchmark early; optimize hot paths; consider platform-specific optimizations |
| Scope creep into full BIP-39/BIP-38 | Delays roadmap | Strict scope: KDFs only; full BIP implementations are separate features |
