# Phase 11: Forward-looking Signatures

**Goal**: Emerging signature schemes from 2024–2026 drafts — threshold and aggregation — tracked until the specs stabilize  
**Horizon**: ⚪ Later  
**Status**: 📋 Future  
**Reach**: ★★☆☆☆ — future / nascent  
**Depends On**: Phase 6 groundwork; the half-aggregation C module re-homed with the `secp256k1-zkp` fork (spec 003 / ADR 0008)  
**Last Updated**: 2026-10-18

These rest on moving drafts — **track, re-verify before committing scope**.

---

## Features

### FROST Threshold Schnorr

**Purpose & User Value**: t-of-n threshold Schnorr signing.
**Reference**: `siv2r/bip-frost-signing` (draft BIP).
**Notes**: No vendored C exists for FROST — candidate homes are upstream `secp256k1-zkp`'s `frost` module (added after this repo's last zkp pin), the vanilla-fork module in `bancaditalia/secp256k1-frost`, or a Swift authoring; residency is undecided — track, don't commit.
**Success Metrics**: Conformant key generation + signing once the draft stabilizes.

### Schnorr Half-Aggregation

**Purpose & User Value**: Non-interactive aggregation of Schnorr signatures (block-space savings).
**Reference**: Blockstream Research `cross-input-aggregation/half-aggregation.mediawiki`; the `schnorrsig_halfagg` C module lives in `secp256k1-zkp` — re-homed to the future `swift-secp256k1-zkp` package (spec 003 / ADR 0008).
**Success Metrics**: Swift wrapper over the zkp fork's C; vectors pass.

---

## Phase Dependencies & Sequencing

1. **Half-aggregation** — wrap the `schnorrsig_halfagg` C (concrete, in the zkp fork — lands with the future package)
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
