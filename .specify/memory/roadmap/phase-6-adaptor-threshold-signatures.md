# Phase 6: Adaptor & Threshold Signatures (ZKP tier)

**Goal**: Turn the `ZKP` tier from a placeholder into real Swift wrappers over the vendored libsecp256k1-zkp C — starting with adaptor signatures, the strategic Bitcoin Layer-2 lever  
**Horizon**: 🔵 Now  
**Status**: 🔜 Planned  
**Reach**: ★★★★☆ — Lightning PTLCs, ARK forfeits/swaps, Cube (the L2 strategic focus)  
**Depends On**: `Sources/ZKP` is currently `Placeholder.swift`; the C modules are vendored  
**Blocks**: Phase 9 (L2 PTLC showcase)  
**Last Updated**: 2026-06-05

Zone A (EC-native). The C is vendored; this phase builds the Swift surface — see the **Package Separation** section in [roadmap.md](../roadmap.md).

---

## Features

### Adaptor Signatures (Schnorr / ECDSA)

**Purpose & User Value**: Point-time-locked contracts (Lightning PTLCs), ARK atomic forfeits/swaps, and Cube. Today every L2 effort hand-rolls or forgoes this.

**Success Metrics**:
- Swift wrapper over `secp256k1_ecdsa_adaptor` (encrypt / decrypt / recover / verify)
- Test vectors from libsecp256k1-zkp pass
- Docs + a working PTLC example

**Notes**: First module to make `Sources/ZKP` real; consider promoting common paths toward `P256K`.

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
| `ecdsa_adaptor` wrapper vector pass rate | 100% |
| ZKP tier no longer a placeholder | Yes |
| Working Lightning PTLC example | Yes |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| ZKP C API instability | Wrapper churn | Pin to the vendored version; track libsecp256k1-zkp |
| Adaptor-sig misuse (nonce reuse) | Key leakage | Safe-by-default API; document the danger; exit tests |
