# Phase 10: secp256k1-Native Protocols

**Goal**: secp256k1-native protocol-level capabilities that are pure EC but go beyond single primitives  
**Horizon**: ⚪ Later  
**Status**: 📋 Future  
**Reach**: ★★★☆☆ — Bitcoin advanced  
**Depends On**: Phase 4 (encodings), EC ops (shipped)  
**Last Updated**: 2026-06-05

---

## Features

### Silent Payments (BIP-352)

**Purpose & User Value**: Reusable payment addresses without on-chain address reuse — a hot Bitcoin topic. Pure secp256k1 (ECDH + tweaks).
**Status**: A `SilentPayments.md` DocC article exists but **no implementation**. Decision: implement, or relabel the article as aspirational.
**Success Metrics**: BIP-352 test vectors pass; sender/receiver flows.

### ellswift / BIP-324 v2 Transport

**Purpose & User Value**: ElligatorSwift point encoding for the v2 encrypted P2P transport.
**Status**: The C `ellswift` module is **vendored but unwrapped** in Swift.
**Success Metrics**: Swift wrapper over `secp256k1_ellswift_*`; BIP-324 vectors.

---

## Phase Dependencies & Sequencing

1. **ellswift wrapper** — wrap vendored C (smaller, self-contained)
2. **Silent Payments** — larger, protocol-level; decide scope first

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| BIP-352 / BIP-324 vector pass rate | 100% (if implemented) |
| External dependencies added | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Silent Payments scope creep into wallet logic | Delay | Primitive/EC layer only; full SP wallet is composition |
| Doc-only SilentPayments article misleads | User confusion | Relabel as aspirational until implemented |
