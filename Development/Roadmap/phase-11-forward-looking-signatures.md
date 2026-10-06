# Phase 11: Forward-looking Signatures

**Goal**: Emerging signature schemes from 2024–2026 drafts — threshold and aggregation — tracked until the specs stabilize  
**Horizon**: ⚪ Later  
**Status**: 📋 Future  
**Reach**: ★★☆☆☆ — future / nascent  
**Depends On**: Phase 6 (ZKP-tier groundwork)  
**Last Updated**: 2026-06-05

These rest on moving drafts — **track, re-verify before committing scope**.

---

## Features

### FROST Threshold Schnorr

**Purpose & User Value**: t-of-n threshold Schnorr signing.
**Reference**: `siv2r/bip-frost-signing` (draft BIP).
**Success Metrics**: Conformant key generation + signing once the draft stabilizes.

### Schnorr Half-Aggregation

**Purpose & User Value**: Non-interactive aggregation of Schnorr signatures (block-space savings).
**Reference**: Blockstream Research `cross-input-aggregation/half-aggregation.mediawiki`; vendored C `secp256k1_schnorrsig_halfagg`.
**Success Metrics**: Swift wrapper over the vendored C; vectors pass.

---

## Phase Dependencies & Sequencing

1. **Half-aggregation** — wrap vendored `schnorrsig_halfagg` C (concrete C exists)
2. **FROST** — after the draft BIP stabilizes

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Tracks current draft specs | Yes |
| Vector pass rate (when implemented) | 100% |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Draft specs change | Rework | Track upstream; don't ship until stabilized |
| Premature FROST commitment | Wasted effort | Groundwork only (Phase 6) until the BIP firms up |
