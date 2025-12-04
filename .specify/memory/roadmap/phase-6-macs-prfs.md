# Phase 6: Long-term — MACs & PRFs

**Goal**: Implement message authentication codes and pseudo-random functions required for BIP implementations  
**Status**: 📋 Future  
**Last Updated**: 2025-12-03  
**Depends On**: Phase 4 (SHA-512 required for HMAC-SHA512)

---

## Features

### HMAC-SHA512

**Purpose & User Value**:  
Implement HMAC-SHA512 for BIP-32 hierarchical deterministic key derivation. This is the core primitive for HD wallets.

**Success Metrics**:
- Passes RFC 4231 test vectors
- Zero external dependencies
- Constant-time behavior
- Compatible with BIP-32 child key derivation: `I = HMAC-SHA512(key=chain_code, data=...)`

**Dependencies**:
- Phase 4 SHA-512

**Notes**:
- Critical for BIP-32 HD wallets
- Also used in BIP-39 (PBKDF2-HMAC-SHA512)
- BIP reference: BIP-32 child key derivation

---

### HMAC-SHA256

**Purpose & User Value**:  
Implement HMAC-SHA256 for various Bitcoin protocols including BIP-129 (encrypted multisig setup) and general message authentication.

**Success Metrics**:
- Passes RFC 4231 test vectors
- Zero external dependencies
- Constant-time behavior

**Dependencies**:
- SHA-256 (available via libsecp256k1)

**Notes**:
- Lower priority than HMAC-SHA512
- BIP reference: BIP-129 for MAC and IV computation

---

### HKDF (HMAC-SHA256)

**Purpose & User Value**:  
Implement HKDF (HMAC-based Key Derivation Function) per RFC 5869 for deriving multiple keys from a shared secret. Used in BIP-151 for P2P encryption.

**Success Metrics**:
- Passes RFC 5869 test vectors
- Extract and Expand functions available
- Zero external dependencies

**Dependencies**:
- HMAC-SHA256

**Notes**:
- BIP reference: BIP-151 derives ChaCha20-Poly1305 keys via HKDF
- Consider: BIP-324 also uses key derivation (evaluate compatibility)

---

### SipHash

**Purpose & User Value**:  
Implement SipHash-2-4 for transaction ID shortening (BIP-152 compact blocks) and Golomb-coded set filters (BIP-158).

**Success Metrics**:
- Passes SipHash test vectors
- SipHash-2-4 variant (c=2, d=4)
- 64-bit output
- Zero external dependencies

**Dependencies**:
- None (standalone primitive)

**Notes**:
- BIP-152: 6-byte short transaction IDs
- BIP-158: Golomb-coded set filter item hashing
- Not cryptographically secure for all purposes—document appropriate use

---

### MurmurHash3

**Purpose & User Value**:  
Implement MurmurHash3 (32-bit) for BIP-37 Bloom filter element hashing.

**Success Metrics**:
- Passes MurmurHash3 test vectors
- 32-bit variant
- Compatible with BIP-37 seed calculation: `seed = nHashNum * 0xFBA4C795 + nTweak`

**Dependencies**:
- None (standalone primitive)

**Notes**:
- BIP-37 is largely deprecated (privacy concerns) but still used
- Lower priority—implement for completeness
- Not cryptographically secure—document as non-crypto hash

---

### HMAC-DRBG

**Purpose & User Value**:  
Implement HMAC-DRBG (deterministic random bit generator) per NIST SP 800-90A for deterministic key/nonce generation. Used in BIP-75 for payment protocol encryption.

**Success Metrics**:
- Passes NIST DRBG test vectors
- SHA-512 variant (per BIP-75)
- Proper seeding interface

**Dependencies**:
- Phase 4 SHA-512
- HMAC-SHA512

**Notes**:
- BIP-75: Seeds HMAC-DRBG with ECDH secret hash + nonce
- Consider: RFC 6979 deterministic signatures (may already use libsecp256k1's implementation)

---

## Phase Dependencies & Sequencing

```
Phase 4 SHA-512 ──► HMAC-SHA512 ──► HMAC-DRBG
                         │
                         └──► (enables BIP-32 in future)

SHA-256 (existing) ──► HMAC-SHA256 ──► HKDF

Standalone ──► SipHash
           └──► MurmurHash3
```

**Priority order**:
1. **HMAC-SHA512** — highest value (BIP-32, BIP-39)
2. **HMAC-SHA256** — common primitive
3. **HKDF** — builds on HMAC-SHA256
4. **SipHash** — needed for BIP-152, BIP-158
5. **MurmurHash3** — lowest priority (BIP-37 deprecated)
6. **HMAC-DRBG** — specialized use case

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| RFC test vector pass rate | 100% |
| BIP compatibility | Verified against reference implementations |
| External dependencies | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Scope creep into full BIP implementations | Delays roadmap | Strict scope: primitives only, not full BIP protocols |
| Test vector availability | Incomplete validation | Use multiple sources: RFCs, Bitcoin Core, other implementations |
