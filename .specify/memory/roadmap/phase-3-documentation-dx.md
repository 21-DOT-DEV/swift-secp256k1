# Phase 3: Documentation & Developer Experience

**Goal**: Enable adoption through comprehensive documentation, tutorials, and improved API ergonomics  
**Horizon**: 🔵 Now (continuous enabler)  
**Status**: 🚧 In Progress  
**Last Updated**: 2026-06-05  
**Depends On**: Phase 2 (CI & Quality Gates) — can partially overlap  
**Blocks**: Phase 9 (apps need documented APIs)

---

## Progress (2026-06-05)

DocC catalog is live; documentation currently exists as **articles** (not yet interactive `.tutorial`s). Built archives ship in `docs/` and `docc-release.yml` publishes to docs.21.dev. Per-feature status:

| Feature | Status | Notes |
|---------|--------|-------|
| Initial DocC Setup | ✅ Done | Catalog configured; `P256K`/`ZKP` landing pages; CI publishes |
| Quickstart | ✅ Done (article) | `GettingStarted.md` |
| Getting Started (ECDSA) | ✅ Done (article) | `ECDSASigningAndBitcoinTransactions.md` |
| Schnorr (BIP-340) | 🟡 Partial | Covered within signing/keys articles; no dedicated Schnorr article |
| Key Formats | 🟡 Partial — **reprioritized up** | `WorkingWithKeys.md`; expand to raw/compressed/DER/x963/PEM — the single most-used downstream surface |
| ECDH | ✅ Done (article) | `EllipticCurveDiffieHellman.md` |
| MuSig2 | ✅ Done (article) | `MuSig2MultiSignatures.md` |
| Recovering Public Keys | ✅ Done (article) | `RecoveringPublicKeys.md`; Bitcoin message signing (BIP-137) |
| Silent Payments | 📄 Doc-only | `SilentPayments.md` article exists but **no implementation** — see Phase 10 (Native Protocols) |
| UInt256 Audit | 🔜 Planned | Source moved ZKP → `Sources/Shared/` (see corrected note below) |

**Remaining**: deepen Key Formats; dedicated Schnorr/x-only article; UInt256 audit; optionally convert articles to interactive `.tutorial`s.

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
- May reference Phase 9 MuSig2 app as practical example

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
- **Updated 2026-06-05**: `UInt256` has been promoted from ZKP to `Sources/Shared/UInt256/` (now compiled into both `P256K` and `ZKP`). Cross-reference `Sources/Shared/UInt256/UInt256.swift` (+ `UInt256+Arithmetic/+FixedWidthInteger/+Modular/+Representation`), **not** the old `Sources/ZKP/UInt256.swift` path.
- Pairs with the **UInt256 SecurityTests** high-priority item (security vectors not yet in `Projects/Sources/SecurityTests/`).
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

**Priority order (revised 2026-06-05 — most articles shipped; remaining work, strategy-ordered)**:
1. **Bitcoin L2 signing guide** — MuSig2 (BIP-327) covenant/pooled signing + Schnorr **adaptor signatures** (ZKP) for ARK / Cube / Lightning. The MuSig2 article ships; extend with adaptor-sig + L2 framing.
2. Dedicated **Schnorr / BIP-340 + x-only + Taproot** article (L2, Nostr)
3. **Key Formats deep-dive** — universal surface (raw/compressed/DER/x963/PEM)
4. UInt256 audit (now in `Sources/Shared/`)
5. Interactive `.tutorial` conversion (optional; current docs are articles)

(`RecoveringPublicKeys.md` already ships — relevant to Bitcoin message signing (BIP-137); keep as-is.)

_Original sequencing (for reference): DocC Setup + Quickstart + Getting Started → Schnorr + Key Formats → ECDH + MuSig2 → UInt256 Audit. Most of this is now shipped as articles._

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
