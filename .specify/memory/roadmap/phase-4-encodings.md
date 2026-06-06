# Phase 4: Encodings

**Goal**: Encoding & serialization primitives bound to secp256k1 outputs — addresses, invoices, and Nostr/Lightning entities  
**Horizon**: 🔵 Now  
**Status**: 🔜 Planned  
**Reach**: ★★★★★ — Nostr (npub/nsec/note), Bitcoin addresses, Lightning (BOLT11), ARK; every consumer hand-rolls these today  
**Depends On**: Base58Check checksum needs double-SHA256 (Phase 5); Bech32 is self-contained  
**Last Updated**: 2026-06-05

These encodings live in `swift-secp256k1` because OpenSSL doesn't provide them and they're bound to secp256k1 *outputs* (see the **Package Separation** section in [roadmap.md](../roadmap.md)). `base64` → Foundation.

---

## Features

### Bech32 / Bech32m (BIP-173 / BIP-350)

**Purpose & User Value**: One parameterized codec for Bitcoin addresses and Nostr/Lightning entities. Bech32 and Bech32m differ *only* by the final checksum XOR constant (`1` vs `0x2bc830a3`); witness v0 (P2WPKH/P2WSH) uses Bech32, v1+ (Taproot) uses Bech32m, selected by witness version on both encode and decode.

**Success Metrics**:
- BIP-173 + BIP-350 test vectors pass
- SegWit v0 (`bc1q…`), Taproot v1 (`bc1p…`), testnet (`tb1…`)
- Clear errors for invalid checksum / HRP

**Notes**: A no-length-cap variant (BOLT11) and a checksum-less variant (BOLT12) reuse the same charset/polymod.

### NIP-19 Entities + TLV Codec

**Purpose & User Value**: Nostr's shareable identifiers — every Nostr library reimplements these.

**Success Metrics**:
- Bare (single 32-byte payload), Bech32 **not** bech32m: `npub`, `nsec`, `note`
- TLV-based: `nprofile`, `nevent`, `naddr` (1-byte Type + 1-byte Length + Value; types 0=special, 1=relay, 2=author, 3=kind/BE-u32); parser ignores unknown types
- NIP-21 `nostr:` URI wrapper

### BOLT11 / BOLT12 (Lightning)

**Purpose & User Value**: Lightning invoices and offers.

**Success Metrics**:
- BOLT11: Bech32 **without** the 90-char cap; payload decode + the recoverable-ECDSA signature (already shipped) enabling payee-node recovery
- BOLT12: checksum-less bech32 data string (HRP `lno`/`lnr`) + TLV stream + BIP-340 tagged-hash merkle root (offers are unsigned; invoice_request/invoice carry `bip340sig`)

### Base58Check + WIF

**Purpose & User Value**: Legacy Bitcoin addresses, WIF private keys, and the BIP-32 extended-key (78-byte xpub/xprv) serialization consumed in Phase 7.

**Success Metrics**:
- Base58Check with **double-SHA256** checksum (depends on Phase 5)
- WIF encode/decode

---

## Phase Dependencies & Sequencing

1. **Bech32/Bech32m** first — highest reach, self-contained
2. **NIP-19 + TLV** — reuses the Bech32 codec
3. **BOLT11/BOLT12** — reuses the codec (no-cap + checksum-less variants)
4. **Base58Check/WIF** — after double-SHA256 (Phase 5)

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| BIP-173/350 vector pass rate | 100% |
| NIP-19 round-trip (all entity types) | 100% |
| External dependencies added | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Bech32 variant confusion (v0 vs v1+) | Wrong addresses | Select variant by witness version on encode *and* decode; vector tests |
| TLV parser on malformed input | Crash / DoS | Ignore unknown types; bounds-check the 1-byte length; fuzz |
