# Phase 3: Documentation & Developer Experience

**Goal**: Enable adoption through comprehensive documentation, tutorials, and improved API ergonomics  
**Status**: 🔜 Planned  
**Last Updated**: 2025-12-03  
**Depends On**: Phase 2 (CI & Quality Gates) — can partially overlap  
**Blocks**: Phase 5 (apps need documented APIs)

---

## Features

### Initial DocC Setup

**Purpose & User Value**:  
Set up DocC infrastructure for custom pages and tutorials beyond auto-generated API docs. Establishes foundation for comprehensive documentation at docs.21.dev.

**Success Metrics**:
- DocC catalog configured in package
- Custom landing page live at docs.21.dev
- Navigation structure for tutorials and articles
- Builds successfully in CI

**Dependencies**:
- None (can start immediately)

**Notes**:
- Hosting already configured at https://docs.21.dev/
- Use DocC's article and tutorial capabilities
- Consider documentation versioning strategy

---

### DocC Quickstart Page

**Purpose & User Value**:  
Create a quickstart guide that gets developers from zero to working code in under 5 minutes. First thing users need; reduces friction to adoption.

**Success Metrics**:
- Complete quickstart at docs.21.dev
- Covers: installation, basic signing, basic verification
- Copy-pasteable code examples
- Works on iOS, macOS, and Linux
- Time to first signature < 5 minutes for new users

**Dependencies**:
- Initial DocC setup

**Notes**:
- Priority P1 (first documentation deliverable)
- Keep minimal—detailed explanations go in tutorials
- Test with fresh environment to validate time estimate

---

### DocC Tutorial: Getting Started (ECDSA)

**Purpose & User Value**:  
Step-by-step tutorial covering ECDSA signing and verification—the most common use case. Validates the library works and teaches fundamental concepts.

**Success Metrics**:
- Complete tutorial with progressive sections
- Covers: key generation, signing, verification, error handling
- Interactive code examples
- Clear explanations of cryptographic concepts (appropriate for developers, not cryptographers)

**Dependencies**:
- DocC Quickstart

**Notes**:
- Priority P1 (initial release alongside quickstart)
- Follow DocC tutorial best practices (chapters, assessments)

---

### DocC Tutorial: Schnorr Signatures (BIP-340)

**Purpose & User Value**:  
Tutorial covering Schnorr signatures per BIP-340—the primary differentiator for Bitcoin/Taproot development. Explains x-only public keys, tagged hashing, and Bitcoin-specific considerations.

**Success Metrics**:
- Complete BIP-340 tutorial
- Covers: Schnorr key generation, signing, verification, x-only keys
- Explains differences from ECDSA
- Bitcoin/Taproot context provided

**Dependencies**:
- Getting Started tutorial (builds on concepts)

**Notes**:
- Priority P2 (fast follow after initial release)

---

### DocC Tutorial: Key Formats

**Purpose & User Value**:  
Tutorial covering key import/export formats—critical for interoperability and a frequent pain point. Covers PEM, DER, raw bytes, and x-only representations.

**Success Metrics**:
- Complete key formats tutorial
- Covers: PEM import/export, DER encoding, raw bytes, x-only (BIP-340)
- Interop examples with Bitcoin Core, OpenSSL
- Common pitfalls documented

**Dependencies**:
- Getting Started tutorial

**Notes**:
- Priority P2 (fast follow)
- Include troubleshooting section for format mismatches

---

### DocC Tutorial: ECDH Key Agreement

**Purpose & User Value**:  
Tutorial covering elliptic curve Diffie-Hellman for shared secret derivation. Common use case for encrypted communication.

**Success Metrics**:
- Complete ECDH tutorial
- Covers: key agreement flow, shared secret derivation, format options
- Security considerations documented (hashing shared secrets, etc.)

**Dependencies**:
- Getting Started tutorial

**Notes**:
- Priority P3 (complete coverage)

---

### DocC Tutorial: MuSig2

**Purpose & User Value**:  
Advanced tutorial covering MuSig2 multi-party Schnorr signatures per BIP-327. Smaller audience but high value for Bitcoin applications.

**Success Metrics**:
- Complete MuSig2 tutorial
- Covers: key aggregation, nonce generation, partial signing, signature aggregation
- Multi-party coordination explained
- Security considerations (nonce reuse dangers)

**Dependencies**:
- Schnorr tutorial (builds on concepts)

**Notes**:
- Priority P3 (complete coverage)
- May reference Phase 5 MuSig2 app as practical example

---

### UInt256 Audit and Improvement

**Purpose & User Value**:  
Audit existing UInt256 implementation in ZKP for correctness, API ergonomics, and potential promotion to P256K. Initial implementation exists; this is review and refinement.

**Success Metrics**:
- UInt256 implementation reviewed for correctness
- API ergonomics improved where needed
- Decision made: keep in ZKP or promote to P256K
- Documentation added for public API
- Test coverage meets Phase 2 thresholds

**Dependencies**:
- Phase 2 coverage infrastructure (to measure current state)

**Notes**:
- Cross-reference current usage in `Sources/ZKP/UInt256.swift` and `Sources/ZKP/Asymmetric.swift`
- Consider: overflow behavior, constant-time properties, Swift Numerics alignment

---

## Phase Dependencies & Sequencing

```
DocC Setup ──► Quickstart ──► Getting Started (ECDSA)
                    │                   │
                    │                   ├──► Schnorr (P2)
                    │                   ├──► Key Formats (P2)
                    │                   ├──► ECDH (P3)
                    │                   └──► MuSig2 (P3)
                    │
                    └──► UInt256 Audit (parallel)
```

**Priority order**:
1. DocC Setup + Quickstart + Getting Started (ECDSA) — initial release
2. Schnorr + Key Formats — fast follow
3. ECDH + MuSig2 — complete coverage
4. UInt256 Audit — can run in parallel

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Time to first signature (new user) | < 5 minutes |
| Public API documentation coverage | 100% |
| Tutorial count | 6 (quickstart + 5 topics) |
| docs.21.dev uptime | 99.9% |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| DocC limitations for crypto concepts | Poor explanations | Supplement with diagrams; link to external resources |
| Documentation becomes stale | User confusion | Tie docs to CI; test code examples |
| UInt256 audit reveals issues | Delays promotion | Scope audit early; fix critical issues only |
