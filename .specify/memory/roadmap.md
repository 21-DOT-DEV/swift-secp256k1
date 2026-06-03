# swift-secp256k1 Product Roadmap

**Version**: v2.0.0  
**Last Updated**: 2026-06-05  
**Constitution**: [constitution.md](constitution.md)

---

## Vision & Goals

Build the most reliable, secure, and developer-friendly Swift secp256k1 library — the elliptic-curve specialist for Bitcoin, Bitcoin Layer-2 (Lightning, ARK, Cube), Nostr, and Cashu — with zero runtime dependencies.

**Target Audience** (ordered by strategic priority; see [Downstream Demand](#downstream-demand)):
- Bitcoin wallet developers (ECDSA, Schnorr/Taproot, keys)
- **Bitcoin Layer-2 / scaling developers — top strategic focus**: Lightning, ARK, and Cube (MuSig2/BIP-327, adaptor signatures, Taproot/x-only, BOLT11)
- Nostr client & relay developers
- Cashu ecash developers
- AI-agent / machine-payment & decentralized-messaging developers (cryptographic identity)
- Swift developers needing secp256k1 primitives

**Core Value Proposition**:
- Zero runtime dependencies (libsecp256k1 bindings only)
- Swift Crypto-inspired API design
- Comprehensive BIP/NIP/NUT/BOLT compliance for the in-scope ecosystems
- Cross-platform reliability (all Apple platforms + Linux)

---

## 🔴 High Priority Items

| Item | Description | Status |
|------|-------------|--------|
| **Module-rename migration & version adoption** | Most downstream consumers are stranded on the legacy `secp256k1` product name and old pins (e.g., 0.12.2, 0.18.0, 0.19.0). Primitives added only to `P256K` cannot reach them. Provide a migration path / compatibility story so new APIs are actually adoptable — the single highest adoption lever. | 🔜 Planned |
| **swift-crypto 4.2.0 Update** | Update vendored swift-crypto via subtree plugin from 3.11.1 to 4.2.0. Resolve breaking availability attribute changes in `Sources/Shared/` on a case-by-case basis (e.g., `UInt256.swift` retains current attributes due to `StaticBigInt` dependency). | 🔜 Planned |
| **UInt256 SecurityTests** | Add security test vectors for `UInt256`/`SIMDWordsInteger` to `Projects/Sources/SecurityTests/`: overflow detection, boundary correctness, power-of-two multiply paths, Codable parsing hardening. _(The `SecurityTests` target exists with DER/InvalidCurve/PointValidation/ScalarValidation/SignatureMalleability/ZeroSignature/Nonce coverage; UInt256 vectors are still absent.)_ | 🔜 Planned |

---

## Package Separation: swift-secp256k1 ↔ swift-openssl

`swift-secp256k1` is the **secp256k1 EC specialist**; general-purpose crypto is sourced from the sibling **`swift-openssl`** package. The boundary is **priority + fallback**, not a wall: swift-secp256k1 grows the Bitcoin-relevant primitives at its own pace; swift-openssl is the comprehensive superset and the always-available fallback meanwhile.

**Rule of thumb** — *Does it grow from the SHA-256/HMAC core already in libsecp256k1?*

| Zone | Primitives | swift-secp256k1 | swift-openssl |
|------|-----------|-----------------|---------------|
| **A — EC only** (OpenSSL can't match Schnorr/MuSig2/recovery) | ECDSA + recovery, Schnorr/BIP-340, MuSig2, ECDH (raw point), x-only, key tweaks, adaptor sigs, DLEQ, FROST, ellswift, hash-to-curve, key representations | ✅ **only** | ❌ |
| **B — overlap, high priority** (cheap SHA-2 tower; Bitcoin-essential) | HMAC-SHA256 *(expose existing C)*, SHA-512 → HMAC-SHA512 *(mirror)*, HKDF, PBKDF2-SHA512, double-SHA256, HMAC-DRBG *(RFC-6979 exists)* | ✅ **high** | ✅ (overlap) |
| **C — overlap, low priority** (separate but Bitcoin-relevant; openssl fallback now) | RIPEMD-160 / HASH160, SipHash, SHA-512/256 | 🔜 **low** | ✅ (use meanwhile) |
| **D — swift-openssl only** (separate + general; don't duplicate) | ChaCha20 / XChaCha20 / AES, scrypt, SHA-3 / Keccak, MurmurHash3 | ❌ | ✅ **only** |

**Encodings** (Bech32 / Bech32m / NIP-19 TLV / BOLT11-12) live in swift-secp256k1 — OpenSSL doesn't provide them and they're bound to secp256k1 *outputs* (addresses, npubs). `base64` → Foundation.

**Why this works:** libsecp256k1 already ships SHA-256, **HMAC-SHA256**, and an HMAC-SHA256-DRBG (RFC-6979) in C — so the whole SHA-2 tower (Zone B) is a thin shim/mirror, making swift-secp256k1 **self-sufficient for the Bitcoin core** (BIP-32 HMAC-SHA512, BIP-39 PBKDF2, BIP-340 tagged hashes) with zero new dependencies.

**Composition** — protocols combining both live in consumer apps / companion packages, not in either core: **NIP-44** = ECDH + HKDF + HMAC *(here)* + ChaCha20 *(swift-openssl)*; **BIP-32/39** HD wallets; **Cashu** mint/wallet.

---

## Roadmap — Now / Next / Later

Phases are **theme-based capability slices**, ordered by **downstream-consumer reach** (RICE: Reach ÷ Effort) with enablers pulled forward (WSJF), grouped into Now / Next / Later horizons — the further out, the more uncertain. "Reach" = how many in-scope cohorts hand-roll or need the capability.

| Horizon | # | Phase | Reach (who needs it) | Status |
|---------|---|-------|----------------------|--------|
| **✅ Foundation** | 0 | [Tooling Foundation](roadmap/phase-0-tooling-foundation.md) | enabler | ✅ Complete |
| | 1 | [Testing Foundation](roadmap/phase-1-testing-foundation.md) | enabler | ✅ Complete |
| **🔵 Now** | 2 | [CI & Quality Gates](roadmap/phase-2-ci-quality-gates.md) | enabler | 🔜 Planned |
| | 3 | [Documentation & DX](roadmap/phase-3-documentation-dx.md) | all | 🚧 In Progress |
| | 4 | [Encodings](roadmap/phase-4-encodings.md) | ★★★★★ Nostr, Bitcoin, Lightning, ARK | 🔜 Planned |
| | 5 | [SHA-2 Hash & MAC Tower](roadmap/phase-5-sha2-tower.md) | ★★★★☆ Lightning, Nostr, HD wallets | 🔜 Planned |
| | 6 | [Adaptor & Threshold Signatures](roadmap/phase-6-adaptor-threshold-signatures.md) | ★★★★☆ Lightning / ARK / Cube (L2) | 🔜 Planned |
| **🟡 Next** | 7 | [HD-Wallet & Key Derivation](roadmap/phase-7-hd-wallet-derivation.md) | ★★★★☆ wallets, Nostr (NIP-06), Cashu | 🔜 Planned |
| | 8 | [Blind Signatures & DLEQ](roadmap/phase-8-blind-signatures-dleq.md) | ★★★☆☆ Cashu | 🔜 Planned |
| | 9 | [Applications / L2 Showcase](roadmap/phase-9-applications.md) | demo / reference | 🔜 Planned |
| **⚪ Later** | 10 | [secp256k1-Native Protocols](roadmap/phase-10-native-protocols.md) | ★★★☆☆ Bitcoin advanced | 📋 Future |
| | 11 | [Forward-looking Signatures](roadmap/phase-11-forward-looking-signatures.md) | ★★☆☆☆ future | 📋 Future |
| **—** | — | [Backlog](roadmap/backlog.md) | — | 📋 Future |

### Phase Summaries

- **Phase 0 — Tooling Foundation** ✅ — SPM pre-build plugin sharing code between P256K and ZKP targets from one source.
- **Phase 1 — Testing Foundation** ✅ — Test architecture under `Projects/`: BIP-340 Schnorr, Wycheproof ECDSA/ECDH, MuSig2, CVE, and security vectors.
- **Phase 2 — CI & Quality Gates** — Coveralls coverage (tiered), CodeQL, fuzzing, exit tests. *(Platform/benchmark CI exists; these deliverables not started.)*
- **Phase 3 — Documentation & DX** 🚧 — DocC live at docs.21.dev (10 articles shipped); remaining: Key-Formats deep-dive, Schnorr/x-only article, interactive tutorials, UInt256 audit.
- **Phase 4 — Encodings** — Bech32/Bech32m, NIP-19 + TLV, BOLT11/BOLT12, Base58Check/WIF. The highest-reach unbuilt work; every Nostr/Bitcoin/Lightning consumer hand-rolls it.
- **Phase 5 — SHA-2 Hash & MAC Tower** — SHA-512, double-SHA256, HMAC-SHA256 (expose C), HMAC-SHA512 (mirror), HKDF, HMAC-DRBG. Cheap (cores in C); unblocks HD-wallet.
- **Phase 6 — Adaptor & Threshold Signatures** — wrap the vendored `ecdsa_adaptor` C (Lightning PTLCs, ARK, Cube); FROST groundwork. The strategic L2 lever.
- **Phase 7 — HD-Wallet & Key Derivation** — BIP-32 CKD + xpub/xprv serialization, BIP-39 (PBKDF2-SHA512 + wordlist), HASH160/RIPEMD-160 (low). Depends on Phase 5.
- **Phase 8 — Blind Signatures & DLEQ** — Cashu BDHKE (hash-to-curve, DST `Secp256k1_HashToCurve_Cashu_`) + NUT-12 DLEQ. Re-verify constants before implementing.
- **Phase 9 — Applications / L2 Showcase** — MuSig2 SwiftUI app re-aimed at L2 (ARK/Cube covenant signing, Lightning PTLC) + NIP-19 / BIP-137 samples.
- **Phase 10 — secp256k1-Native Protocols** — Silent Payments (BIP-352), ellswift / BIP-324 v2 transport.
- **Phase 11 — Forward-looking Signatures** — FROST threshold (draft), Schnorr half-aggregation.
- **Backlog** — Data structures (Bloom/Golomb/Merkle), CLI apps, niche primitives, Windows support.

---

## Downstream Demand

Priorities are informed by how downstream apps and libraries actually use the package across the Bitcoin, Lightning, Nostr, and Cashu ecosystems.

**Cohort priority stack:**
1. **Bitcoin + Bitcoin Layer-2** (Lightning, ARK, Cube) — strategic focus. ARK/Cube emulate covenants with MuSig2; Lightning uses MuSig2 + PTLC adaptor signatures. *(ARK/Cube are nascent in the public data — strategic bets, not raw count.)*
2. **Nostr**, then **Cashu**, then **AI-agent / messaging**.

**Key findings:**
- **The EC-signature layer is already complete** (Schnorr, ECDSA + recovery, MuSig2, ECDH, x-only, tweaks) — it already covers BOLT11/12 signing, Lightning Sphinx ECDH, ARK/Cube MuSig2, NIP-01, and Cashu BDHKE point ops. The remaining work is **utility primitives** (encodings, hashing, MAC/KDF) — i.e., Phases 4–8.
- **Module-era skew is the top adoption lever** — most consumers are stranded on the legacy `secp256k1` product name + old pins; primitives added only to `P256K` don't reach them.
- **Most-used surfaces already ship but were roadmap-invisible** — key-format serialization (universal) and ECDH (Nostr/Cashu; Lightning Sphinx). Harden + document, don't rebuild.
- **Adaptor signatures are vendored-C-only** — the `ZKP` tier is `Placeholder.swift`; Phase 6 wraps the existing C.

---

## Product-Level Metrics & Success Criteria

| Metric | Target | Status |
|--------|--------|--------|
| Test vector coverage | 100% BIP-340, Wycheproof vectors pass | 🔜 |
| Code coverage (critical paths) | ≥90% signing/verification/key handling | 🔜 |
| Code coverage (overall) | ≥70% repository-wide | 🔜 |
| Platform CI pass rate | 100% across all 6 platforms | ✅ |
| Documentation coverage | 100% public API documented | 🔜 |
| Build time | < 60 seconds clean build | 🔜 |
| Zero runtime dependencies | Maintained | ✅ |

**Note**: Adoption and grant-readiness metrics tracked in a separate repository.

---

## High-Level Dependencies

- **Foundation (Phase 0 → 1)** ✅ unblocks all new cryptographic code.
- **Phase 5 (SHA-2 Tower)** enables **Phase 7 (HD-Wallet)** (HMAC-SHA512/PBKDF2) and feeds **Phase 8 (DLEQ uses SHA-256)**.
- **Phase 4 (Encodings)** feeds **Phase 7** (Base58Check for xpub/xprv) and **Phase 9** (address/invoice display).
- **Phase 6 (Adaptor sigs)** enables **Phase 9** (PTLC demo) and the L2 strategy.
- **Phase 2 (CI)** + **Phase 3 (Docs)** are continuous enabler tracks that overlap everything.
- **Zone-D primitives** (ChaCha20, scrypt, AES, SHA-3) are **not** roadmap items — they come from swift-openssl (see Package Separation).

---

## Global Risks & Assumptions

**Assumptions**:
- Zero runtime dependency philosophy is maintained for `swift-secp256k1` (libsecp256k1 bindings only); general crypto is sourced from `swift-openssl`, not added as a dependency here.
- Swift Package Manager remains the primary build system; Tuist used for `Projects/` only.
- All six Apple platforms + Linux continue as supported targets.

**Risks & Mitigations**:

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hand-rolling crypto under the zero-dependency constraint | Verification burden per primitive | Limit built-here crypto to the **SHA-2 tower** (Zone B — cores already in libsecp256k1 C); defer ciphers/scrypt/SHA-3 to swift-openssl (Zone D) |
| Constant-time requirement for all crypto code | Significant verification burden | Adopt libsecp256k1's existing constant-time patterns; constant-time compare helpers for MAC verification |
| Platform breadth (6 platforms) multiplies CI/testing effort | Slow CI, flaky failures | Tiered CI: full matrix on release, subset on PRs |
| Scope creep from BIP/NIP/NUT completeness pressure | Primitives expand into full protocols | Strict scope: primitives + encodings only; full protocol stacks (NIP-44, BIP-39, Cashu) are composition in apps/companion packages |
| Cashu constants (hash-to-curve / DLEQ) drift | Interop breakage | Re-verify against `cashubtc/nuts` primary specs before implementing Phase 8 |

---

## Change Log

| Version | Date | Change Type | Description |
|---------|------|-------------|-------------|
| v1.4.0 | 2026-03-14 | Improved | Full overview refresh: per-phase summaries, Global Risks & Assumptions section |
| v1.5.0 | 2026-06-05 | Reprioritized | Downstream-demand refactor: verified completed statuses; 324-consumer analysis; reprioritized by measured demand; migration high-priority lever |
| v1.6.0 | 2026-06-05 | Refocused | Strategic refocus on Bitcoin & Bitcoin Layer-2 (Lightning, ARK, Cube): re-elevated MuSig2 + adaptor sigs and sharpened scope to the Bitcoin / Nostr / Cashu ecosystems |
| v1.7.0 | 2026-06-05 | Researched | Deep-research pass 1 (Bitcoin/L2): EC-signature layer confirmed complete; corrected 3 errors (adaptor sigs vendored-C-only; Sphinx = HMAC-SHA256 not HKDF; tagged-hash partial) |
| v1.8.0 | 2026-06-05 | Researched | Deep-research pass 2 (Nostr/Cashu): NIP-44 exact construction, NIP-19 Bech32/TLV, Cashu BDHKE + NUT-12 DLEQ; corrected NIP-44 to bare ChaCha20 (not Poly1305 AEAD) |
| **v2.0.0** | **2026-06-05** | **Restructured** | Re-architected into **12 demand-ordered, theme-based phases on Now/Next/Later horizons** (RICE/WSJF by downstream reach); added the centralized **Package Separation (swift-secp256k1 ↔ swift-openssl)** section (Zone A–D + priority/fallback rule); promoted ZKP-tier / BDHKE / Silent-Payments / ellswift / BIP-32-serialization from backlog to first-class phases; **folded the standalone `downstream-demand.md` + `foundational-toolkit-research.md` into this fileset (distilled) and removed them**; resolved ChaCha20 → sourced from swift-openssl (NIP-44 = composition) |
