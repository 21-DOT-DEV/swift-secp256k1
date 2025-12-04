# swift-secp256k1 Product Roadmap

**Version**: v1.0.0  
**Last Updated**: 2025-12-03  
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

## Phases Overview

| Phase | Name | Status | File |
|-------|------|--------|------|
| **0** | Tooling Foundation | 🔜 Planned | [phase-0-tooling-foundation.md](roadmap/phase-0-tooling-foundation.md) |
| **1** | Testing Foundation | 🔜 Planned | [phase-1-testing-foundation.md](roadmap/phase-1-testing-foundation.md) |
| **2** | CI & Quality Gates | 🔜 Planned | [phase-2-ci-quality-gates.md](roadmap/phase-2-ci-quality-gates.md) |
| **3** | Documentation & DX | 🔜 Planned | [phase-3-documentation-dx.md](roadmap/phase-3-documentation-dx.md) |
| **4** | Bitcoin Utility Primitives | 🔜 Planned | [phase-4-bitcoin-utility-primitives.md](roadmap/phase-4-bitcoin-utility-primitives.md) |
| **5** | Applications | 🔜 Planned | [phase-5-applications.md](roadmap/phase-5-applications.md) |
| **6** | Long-term: MACs & PRFs | 📋 Future | [phase-6-macs-prfs.md](roadmap/phase-6-macs-prfs.md) |
| **7** | Long-term: KDFs | 📋 Future | [phase-7-kdfs.md](roadmap/phase-7-kdfs.md) |
| **—** | Backlog | 📋 Future | [backlog.md](roadmap/backlog.md) |

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

## Change Log

| Version | Date | Change Type | Description |
|---------|------|-------------|-------------|
| v1.0.0 | 2025-12-03 | Initial | Initial roadmap with 8 phases + backlog |
