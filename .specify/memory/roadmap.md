# swift-secp256k1 Product Roadmap

**Version**: v1.4.0  
**Last Updated**: 2026-03-14  
**Constitution**: [constitution.md](constitution.md)

---

## Vision & Goals

Build the most reliable, secure, and developer-friendly Swift wrapper for secp256k1 elliptic curve cryptography, enabling Bitcoin, Lightning, and Nostr application development with zero runtime dependencies.

**Target Audience**:
- Bitcoin wallet developers
- Lightning Network application builders
- Nostr client developers
- Swift developers needing secp256k1 primitives

**Core Value Proposition**:
- Zero runtime dependencies (libsecp256k1 bindings only)
- Swift Crypto-inspired API design
- Comprehensive BIP compliance
- Cross-platform reliability (all Apple platforms + Linux)

---

## 🔴 High Priority Items

| Item | Description | Status |
|------|-------------|--------|
| **swift-crypto 4.2.0 Update** | Update vendored swift-crypto via subtree plugin from 3.11.1 to 4.2.0. Resolve breaking availability attribute changes in `Sources/Shared/` on case-by-case basis (e.g., `UInt256.swift` retains current attributes due to `StaticBigInt` dependency). | 🔜 Planned |
| **UInt256 SecurityTests** | Add security test vectors for `UInt256`/`SIMDWordsInteger` to `Projects/Sources/SecurityTests/`. Cover: overflow detection, boundary correctness, power-of-two multiply paths, Codable parsing hardening. Use swift-testing framework with `*ReportingOverflow` pattern. | 🔜 Planned |

---

## Phases Overview

| Phase | Name | Status | File |
|-------|------|--------|------|
| **0** | Tooling Foundation | ✅ Complete | [phase-0-tooling-foundation.md](roadmap/phase-0-tooling-foundation.md) |
| **1** | Testing Foundation | ✅ Complete | [phase-1-testing-foundation.md](roadmap/phase-1-testing-foundation.md) |
| **2** | CI & Quality Gates | 🔜 Planned | [phase-2-ci-quality-gates.md](roadmap/phase-2-ci-quality-gates.md) |
| **3** | Documentation & DX | 🔜 Planned | [phase-3-documentation-dx.md](roadmap/phase-3-documentation-dx.md) |
| **4** | Bitcoin Utility Primitives | 🔜 Planned | [phase-4-bitcoin-utility-primitives.md](roadmap/phase-4-bitcoin-utility-primitives.md) |
| **5** | Applications | 🔜 Planned | [phase-5-applications.md](roadmap/phase-5-applications.md) |
| **6** | Long-term: MACs & PRFs | 📋 Future | [phase-6-macs-prfs.md](roadmap/phase-6-macs-prfs.md) |
| **7** | Long-term: KDFs | 📋 Future | [phase-7-kdfs.md](roadmap/phase-7-kdfs.md) |
| **—** | Backlog | 📋 Future | [backlog.md](roadmap/backlog.md) |

### Phase Summaries

- **Phase 0** — SPM pre-build plugin enabling code sharing between P256K and ZKP targets from a single source
- **Phase 1** — Test architecture under `Projects/`; BIP-340 Schnorr vectors, Wycheproof ECDSA/ECDH vectors, CVE regression tests, native secp256k1/zkp test suites
- **Phase 2** — Coveralls code coverage (tiered: ≥90% critical, ≥70% overall), CodeQL security scanning, fuzz testing, exit tests for precondition failures
- **Phase 3** — DocC setup at docs.21.dev with quickstart guide; 5 tutorials (ECDSA, Schnorr/BIP-340, Key Formats, ECDH, MuSig2); UInt256 audit and improvement
- **Phase 4** — SHA-512 (zero-dep, constant-time), RIPEMD-160 / HASH160, Bech32/Bech32m encoding for Bitcoin (SegWit/Taproot), Lightning (BOLT11), and Nostr (NIP-19)
- **Phase 5** — MuSig2 SwiftUI signing app on all Apple platforms; Bitcoin multi-sig wallet and Nostr shared-account user flows
- **Phase 6** — HMAC-SHA512 (BIP-32), HMAC-SHA256, HKDF (BIP-151), SipHash (BIP-152/158), MurmurHash3 (BIP-37), HMAC-DRBG
- **Phase 7** — PBKDF2-SHA512 for BIP-39 mnemonic-to-seed derivation; scrypt for BIP-38 encrypted private keys
- **Backlog** — Data structures (Bloom filters, Golomb-coded sets, Merkle trees), CLI apps, additional primitives (tagged hashes, Base58Check, strict DER), Windows support

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

**Note**: Adoption and grant-readiness metrics tracked in separate repository.

---

## High-Level Dependencies

```
Phase 0 (SPM Plugin) ──► Phase 1 (Testing) ──► Phase 2 (CI/Quality)
                                                      │
                                                      ▼
                              Phase 3 (Docs) ◄─── can overlap
                                    │
                                    ▼
                        Phase 4 (Primitives) ──► Phase 5 (Apps)
                                                      │
                                                      ▼
                                          Phase 6-7 (Long-term)
```

- **Phase 0** unblocks code sharing between P256K and ZKP
- **Phase 1-2** must complete before adding new cryptographic code
- **Phase 3** can partially overlap with Phase 2
- **Phase 4** depends on testing/CI infrastructure
- **Phase 5** demonstrates Phase 4 primitives in action

---

## Global Risks & Assumptions

**Assumptions**:
- Zero runtime dependency philosophy is maintained across all phases (libsecp256k1 bindings only)
- Swift Package Manager remains the primary build system; Tuist used for `Projects/` only
- All six Apple platforms + Linux continue as supported targets

**Risks & Mitigations**:

| Risk | Impact | Mitigation |
|------|--------|------------|
| Zero-dependency constraint limits implementation options | All hash/MAC/KDF primitives must be hand-rolled | Base on libsecp256k1 patterns; accept modest performance cost vs platform crypto |
| Constant-time requirement for all crypto code | Significant verification burden per primitive | Adopt libsecp256k1's existing constant-time patterns; consider formal verification for critical paths |
| Platform breadth (6 platforms) multiplies CI/testing effort | Slow CI, flaky platform-specific failures | Tiered CI: full matrix on release, subset on PRs |
| Scope creep from BIP completeness pressure | Primitives expand into full protocol implementations | Strict scope: primitives only in Phases 4-7; full BIP protocols are separate packages/features |

---

## Change Log

| Version | Date | Change Type | Description |
|---------|------|-------------|-------------|
| v1.0.0 | 2025-12-03 | Initial | Initial roadmap with 8 phases + backlog |
| v1.1.0 | 2025-12-12 | Added | High Priority Items section with Swift Version Compatibility Table |
| v1.2.0 | 2025-12-14 | Completed | Swift Version Compatibility Table implemented in README.md |
| v1.3.0 | 2025-12-26 | Updated | Phase 0 & 1 marked complete; added swift-crypto 4.2.0 update and UInt256 SecurityTests as high-priority items |
| v1.4.0 | 2026-03-14 | Improved | Full overview refresh: added per-phase summaries, removed completed high-priority item, added Global Risks & Assumptions section |
