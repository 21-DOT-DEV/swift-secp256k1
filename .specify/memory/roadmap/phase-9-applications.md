# Phase 9: Applications / L2 Showcase

**Goal**: Demonstrate the library through Bitcoin-Layer-2-focused apps and reference samples that double as integration tests  
**Horizon**: 🟡 Next  
**Status**: 🔜 Planned  
**Reach**: demo / reference (reduces the "everyone hand-rolls it" tax)  
**Depends On**: Phase 6 (adaptor sigs), Phase 4 (encodings)  
**Last Updated**: 2026-06-05

Re-aimed from the original "Applications" phase toward the L2 strategy: no cohort asked for a generic MuSig2 demo, but ARK/Cube/Lightning are MuSig2- and adaptor-signature-centric.

---

## Features

### MuSig2 SwiftUI Signing App (re-aimed at L2)

**Purpose & User Value**: Functional signing tool + reference implementation + MuSig2/adaptor integration test, across Apple platforms.

**Success Metrics**:
- Runs on iOS / macOS / iPadOS / visionOS / tvOS
- L2 flows: ARK/Cube-style covenant key aggregation + tweaks; Lightning taproot-channel cosigning
- Complete ceremony: key aggregation → nonce exchange → partial signing → aggregation; export keys/signatures
- Code quality suitable for a reference implementation

### Demand-aligned reference samples

The things consumers currently hand-roll — each a small, copy-pasteable sample + integration test:
- **Adaptor-signature PTLC** demo (Lightning; needs Phase 6)
- **BOLT11 invoice** encode/decode (Lightning; Phase 4)
- **NIP-19 encoding** (Nostr npub/nsec; Phase 4)
- **BIP-137 message signing + recovery** (Bitcoin; shipped Recovery)

---

## Phase Dependencies & Sequencing

1. Core data models (key types, ceremony state)
2. macOS app (fastest iteration) → iOS → other platforms
3. Reference samples land alongside the relevant primitive phases

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Platforms supported | 5 (iOS, macOS, iPadOS, visionOS, tvOS) |
| L2 flows demonstrated | ARK/Cube covenant + Lightning PTLC |
| MuSig2 + adaptor API coverage | 100% of public API demonstrated |

---

## Backlog (future apps)

CLI tools deferred to [backlog.md](backlog.md): MuSig2 CLI, ECDSA signing CLI, Schnorr verifier, address generator.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| SwiftUI cross-platform differences | Inconsistent UX | Isolate platform-specific code; test early |
| Key security in a demo app | Misuse for real funds | Clear warnings; "demo mode" flag |
| Depends on Phase 6 adaptor wrapper | Blocked PTLC demo | Sequence after Phase 6; MuSig2 flows land first |
