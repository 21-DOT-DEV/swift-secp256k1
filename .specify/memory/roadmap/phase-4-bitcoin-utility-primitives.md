# Phase 4: Bitcoin Utility Primitives

**Goal**: Add essential Bitcoin utility primitives (hashing, encoding) with zero external dependencies  
**Status**: 🔜 Planned  
**Last Updated**: 2025-12-03  
**Depends On**: Phase 2 (CI & Quality Gates must be solid before adding crypto code)  
**Blocks**: Phase 5 (MuSig2 app may use Bech32 for addresses)

---

## Features

### SHA-512 Implementation

**Purpose & User Value**:  
Implement SHA-512 based on secp256k1's SHA-256 implementation to maintain zero external dependencies and ensure constant-time behavior. Required for BIP-32 (HMAC-SHA512) and BIP-39 (PBKDF2-SHA512).

**Success Metrics**:
- SHA-512 implementation passes NIST test vectors
- Zero external dependencies (no CryptoKit, no CommonCrypto)
- Constant-time behavior verified (no data-dependent branches)
- API consistent with existing hash interfaces
- Performance within 2x of CryptoKit (acceptable for security trade-off)

**Dependencies**:
- Phase 2 CI infrastructure (for comprehensive testing)

**Notes**:
- Base implementation on `Vendor/secp256k1/src/hash_impl.h` patterns
- Implement in ZKP first, promote to P256K after validation
- Consider: streaming API for large inputs

---

### RIPEMD-160 Implementation

**Purpose & User Value**:  
Implement RIPEMD-160 for Bitcoin HASH160 construction (SHA-256 + RIPEMD-160) used in legacy P2PKH addresses. Zero dependencies, constant-time.

**Success Metrics**:
- RIPEMD-160 passes standard test vectors
- Zero external dependencies
- Constant-time behavior verified
- HASH160 convenience function provided (SHA-256 → RIPEMD-160)
- Compatible with Bitcoin address generation

**Dependencies**:
- Phase 2 CI infrastructure

**Notes**:
- Implement in ZKP first, promote to P256K
- Lower priority than SHA-512 (legacy addresses declining)
- Reference: Bitcoin Core's implementation

---

### Bech32/Bech32m Encoding

**Purpose & User Value**:  
Implement Bech32 (BIP-173) and Bech32m (BIP-350) encoding with support for Bitcoin, Lightning, and Nostr ecosystems. Enables address generation and validation.

**Success Metrics**:
- Bech32 (BIP-173) encoding/decoding works correctly
- Bech32m (BIP-350) encoding/decoding works correctly
- Bitcoin support:
  - SegWit v0 addresses (`bc1q...`)
  - Taproot v1 addresses (`bc1p...`)
  - Testnet variants (`tb1...`)
- Lightning support:
  - BOLT11 invoice parsing (`lnbc...`, `lntb...`, `lnbcrt...`)
- Nostr support:
  - NIP-19 entities (`npub`, `nsec`, `note`, `nprofile`, `nevent`, `naddr`, `nrelay`)
- Checksum validation for all formats
- Clear error messages for invalid encodings

**Dependencies**:
- Phase 2 CI infrastructure
- SHA-256 (already available via libsecp256k1)

**Notes**:
- Implement in ZKP first, promote to P256K
- BIP-173 test vectors: https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki
- BIP-350 test vectors: https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki
- Consider: separate types for each ecosystem (BitcoinAddress, LightningInvoice, NostrEntity)

---

## Phase Dependencies & Sequencing

```
Phase 2 Complete ──► SHA-512 ──► (enables HMAC-SHA512 in Phase 6)
                │
                ├──► RIPEMD-160 ──► (enables HASH160)
                │
                └──► Bech32/Bech32m ──► Phase 5 (MuSig2 app)
```

**Recommended order**:
1. **SHA-512** — highest value (unblocks HMAC-SHA512, PBKDF2)
2. **Bech32/Bech32m** — needed for Phase 5 app, high user demand
3. **RIPEMD-160** — lowest priority (legacy use case)

All can technically run in parallel but SHA-512 should complete first.

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| SHA-512 test vector pass rate | 100% |
| RIPEMD-160 test vector pass rate | 100% |
| Bech32/Bech32m test vector pass rate | 100% |
| External dependencies added | 0 |
| Constant-time verification | All implementations |

---

## API Design Notes

**Proposed API structure** (ZKP first, then P256K):

```swift
// SHA-512
P256K.SHA512.hash(data: Data) -> SHA512Digest

// RIPEMD-160
P256K.RIPEMD160.hash(data: Data) -> RIPEMD160Digest
P256K.HASH160.hash(data: Data) -> HASH160Digest  // SHA256 + RIPEMD160

// Bech32
P256K.Bech32.encode(hrp: String, data: Data) -> String
P256K.Bech32.decode(_ string: String) -> (hrp: String, data: Data)

// Bitcoin Addresses
P256K.Bitcoin.Address.segwit(publicKey: PublicKey, network: Network) -> String
P256K.Bitcoin.Address.taproot(xOnlyKey: XOnlyKey, network: Network) -> String

// Lightning (if included)
P256K.Lightning.Invoice.decode(_ bolt11: String) -> Invoice

// Nostr
P256K.Nostr.npub(publicKey: PublicKey) -> String
P256K.Nostr.nsec(privateKey: PrivateKey) -> String
// etc.
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Constant-time implementation difficult | Security vulnerability | Review against known constant-time patterns; consider formal verification |
| Performance too slow | User complaints | Benchmark against CryptoKit; document trade-offs; allow opt-in to platform crypto |
| Bech32 ecosystem scope creep | Delays phase | Strict scope: encoding/decoding only; higher-level features in Phase 5+ |
| RIPEMD-160 test vectors scarce | Incomplete validation | Use Bitcoin Core test cases; cross-validate with OpenSSL |
