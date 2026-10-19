# Phase 6: Adaptor & Threshold Signatures

**Goal**: Swift wrappers over the `secp256k1-zkp` fork's adaptor-signature C — the strategic Bitcoin Layer-2 lever — plus MuSig2 hardening for L2 use  
**Horizon**: 🔵 Now  
**Status**: 🔜 Planned  
**Reach**: ★★★★☆ — Lightning PTLCs, ARK forfeits/swaps, Cube (the L2 strategic focus)  
**Depends On**: the future `swift-secp256k1-zkp` package for the adaptor-signature C (`secp256k1-zkp` left this repo with the `ZKP` products — spec 003 / ADR 0008); MuSig2 already ships  
**Blocks**: Phase 9 (L2 PTLC showcase)  
**Last Updated**: 2026-10-18

Zone A (EC-native). The adaptor-signature C is no longer vendored — it lives in the `secp256k1-zkp` fork and returns with the future dedicated package (design sketch in [backlog](backlog.md)); the MuSig2-hardening and FROST-groundwork features below build on what already ships — see the **Package Separation** section in [roadmap](README.md).

---

## Features

### Adaptor Signatures (Schnorr / ECDSA)

> **Re-homed (2026-10-18):** `ecdsa_adaptor` exists only in the `secp256k1-zkp` fork, which left this repo with the `ZKP` products (spec 003 / ADR 0008); this feature resumes in the future `swift-secp256k1-zkp` package — sketch in [backlog](backlog.md).

**Purpose & User Value**: Point-time-locked contracts (Lightning PTLCs), ARK atomic forfeits/swaps, and Cube. Today every L2 effort hand-rolls or forgoes this.

**Success Metrics**:
- Swift wrapper over `secp256k1_ecdsa_adaptor` (encrypt / decrypt / recover / verify)
- Test vectors from libsecp256k1-zkp pass
- Docs + a working PTLC example

**Notes**: Lands in the dedicated package rather than a `Sources/ZKP` here; that package still compiles this repo's `Sources/P256K/` as its canonical shared surface.

### MuSig2 L2 Ergonomics + Hardening

**Purpose & User Value**: `P256K.MuSig` already ships (BIP-327) — ARK/Cube emulate covenants with it; Lightning taproot channels use it. Harden + document for L2: deterministic nonces, key aggregation, Taproot tweaks, and Cube-style key-projector tweaks (`pk + t·G`).

**Notes**: Hardening/documentation of an existing capability, grouped here thematically.

### FROST Groundwork

**Purpose**: Lay the wrapping/API groundwork for threshold Schnorr (full FROST in Phase 11).

---

## Phase Dependencies & Sequencing

1. **Adaptor signatures** — wrap the C (highest L2 value)
2. **MuSig2 hardening/docs** — in parallel
3. **FROST groundwork** — toward Phase 11

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| `ecdsa_adaptor` wrapper vector pass rate (in the future package) | 100% |
| Working Lightning PTLC example | Yes |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| zkp-fork C API instability | Wrapper churn | Pin the fork in the future package's `vendir.yml`; track BlockstreamResearch/secp256k1-zkp |
| Adaptor-sig misuse (nonce reuse) | Key leakage | Safe-by-default API; document the danger; exit tests |
