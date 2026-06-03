# Backlog: Future Consideration

**Purpose**: Items deferred for future consideration, not currently scheduled as phases  
**Last Updated**: 2026-06-05

> Items with strong downstream demand were **promoted to first-class phases** (see [roadmap.md](../roadmap.md)): adaptor signatures & MuSig2-L2 (Phase 6), HD-wallet / BIP-32 serialization (Phase 7), Cashu BDHKE + DLEQ (Phase 8), Silent Payments & ellswift (Phase 10), FROST & half-aggregation (Phase 11). General-purpose crypto (ChaCha20, AES, scrypt, SHA-3) is **sourced from swift-openssl** per the Package Separation section — not a backlog item.

---

## ZKP-tier modules not yet phased

`libsecp256k1_zkp` C is vendored; these are lower-priority than the phased adaptor sigs (Phase 6) and BDHKE/DLEQ (Phase 8):

| C module | Capability | Cohort | Priority |
|----------|-----------|--------|----------|
| `secp256k1_ecdsa_s2c` | Sign-to-contract / anti-exfil | Bitcoin | Low |
| `secp256k1_rangeproof` / `secp256k1_surjectionproof` | Confidential assets | Liquid-style | Low |

---

## Niche / deprecated primitives

| Item | Notes | Priority |
|------|-------|----------|
| **SipHash-2-4** | Zone C (built-here low; swift-openssl fallback). Needed by the BIP-152/158 filters below | Low |
| **MurmurHash3 (32-bit)** | BIP-37 Bloom filters; deprecated, not in OpenSSL → only if a consumer needs it | Low |
| **Strict DER validation (BIP-66)** | Likely already handled by libsecp256k1; review only | Low |

---

## Data Structures

General-purpose structures supporting specific BIPs (in-repo vs recommend-external is undecided):

| Item | BIP | Notes |
|------|-----|-------|
| **Bloom Filters** | BIP-37 | Uses MurmurHash3; deprecated (privacy); low |
| **Golomb-Coded Sets** | BIP-158 | Uses SipHash; modern filter; medium if SipHash is built |
| **Merkle Trees / taptrees** | BIP-341 | Tagged-hash based; medium-high for Taproot completeness |

---

## Deferred applications (CLIs)

Complement the Phase 9 SwiftUI app:

| App | Notes | Priority |
|-----|-------|----------|
| MuSig2 CLI | Command-line ceremony for scripting | Medium |
| Address Generator | Key → address (Phase 4 Bech32) | Medium |
| ECDSA Signing CLI | Basic signing/verification | Low |
| Schnorr Verifier | Standalone verification utility | Low |

---

## Platform Support

### Windows Build Support

**Status**: Deferred — placeholder `#if os(Windows)` in `Plugin.swift`  
**Priority**: Low (Windows is not a primary Swift platform)  
**Notes**: `SharedSourcesPlugin` uses POSIX `find + cp`; Windows needs `robocopy /E` or `xcopy /E /I` + a Windows CI runner.  
**Acceptance**: `swift build` succeeds on Windows without symlink errors; Windows CI job passes.

---

## Prioritization Criteria

When promoting an item from backlog to a phase:
1. **Downstream reach** — how many in-scope cohorts need it (RICE)
2. **Spec coverage** — fills a real BIP/NIP/NUT/BOLT gap
3. **Dependency chain** — unblocks other work (WSJF opportunity-enablement)
4. **Effort** — cheap overlaps (SHA-2 tower) before standalone primitives
5. **Scope alignment** — secp256k1-native or Bitcoin-utility; general crypto → swift-openssl

---

## Adding to Backlog

New items should include: **Purpose**, **spec reference** (if any), **dependencies**, **priority signal** (with rationale), and **notes**.
