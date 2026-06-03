# Phase 8: Blind Signatures & DLEQ (ZKP tier)

**Goal**: Cashu's blind Diffie-Hellman key exchange (BDHKE) and NUT-12 discrete-log-equality proofs — secp256k1-native, for the ecash cohort  
**Horizon**: 🟡 Next  
**Status**: 🔜 Planned  
**Reach**: ★★★☆☆ — Cashu (CashuSwift, macadamia, bitpoints, nutsack, CashuKit); every lib reimplements BDHKE  
**Depends On**: SHA-256 + point ops (shipped); hash-to-curve  
**Last Updated**: 2026-06-05

Zone A (EC-native). **MEDIUM confidence** — re-verify the exact constants against `cashubtc/nuts` primary specs before implementing (see Caveats).

---

## Features

### hash-to-curve (secp256k1)

**Purpose & User Value**: `Y = hash_to_curve(secret)` — the one net-new primitive for BDHKE.
**Success Metrics**:
- Current algorithm: domain-separated SHA-256 + counter loop, DST `Secp256k1_HashToCurve_Cashu_` (supersedes the deprecated direct-hash version)
- Maps any input to a valid secp256k1 point

### BDHKE Blind Sign / Unblind / Verify

**Purpose & User Value**: The Cashu mint/wallet core: `B_ = Y + r·G`; `C_ = a·B_`; `C = C_ - r·A`; verify `C == a·Y`.
**Success Metrics**: secp256k1 point arithmetic (shipped) + hash-to-curve; round-trip against Cashu test vectors.

### DLEQ Proofs (NUT-12)

**Purpose & User Value**: The mint proves `C_ = a·B_` and `A = a·G` share the same `a`.
**Success Metrics**:
- Schnorr-style `(e, s)` proof; SHA-256 Fiat-Shamir challenge
- Alice-side verification using blinding factor `r`
**Notes**: A C `dleq_impl.h` exists **inside the adaptor module** and may not match NUT-12 byte-for-byte — likely a fresh, spec-conformant Swift authoring.

---

## Caveats (re-verify before implementing)

- NUT-00 hash-to-curve **counter encoding** (byte order/width) and exact DST casing
- NUT-12 DLEQ **Fiat-Shamir challenge inputs** and serialization
- NUT-02 **keyset-id** byte layout

_NUT-11 P2PK and NUT-14 HTLC reuse shipped Schnorr + SHA-256 — no new EC primitive. Cashu token V4 (CBOR) is composition, not a primitive._

---

## Phase Dependencies & Sequencing

1. **hash-to-curve** — the net-new primitive
2. **BDHKE** — point ops + hash-to-curve
3. **DLEQ** — after constant re-verification

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| BDHKE round-trip vs Cashu vectors | 100% |
| NUT-12 DLEQ verify | 100% |
| Constants re-verified vs `cashubtc/nuts` | Yes |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Wrong hash-to-curve constant | Interop break with mints | Re-verify DST/counter vs primary spec + reference impls before coding |
| Reusing adaptor-internal DLEQ | Non-conformant proofs | Author a NUT-12-conformant Swift DLEQ rather than wrapping the adaptor C |
