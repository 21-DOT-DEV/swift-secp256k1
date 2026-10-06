# Phase 9.5: Command-Line Tool

**Goal**: Scriptable terminal access to the package's primitives and encodings, distributed via Homebrew  
**Horizon**: 🟡 Next  
**Status**: 🔜 Planned  
**Reach**: ★★★☆☆ — developers, scripting/CI  
**Depends On**: Phase 4 (encodings — address/npub output); Phase 6 optional (adaptor ceremonies)  
**Funding**: Inside the 2026 funding window — Q5 (months 13–15) of the shared 2026 roadmap  
**Last Updated**: 2026-08-01

Promoted from the [backlog](backlog.md) on 2026-08-01: the deferred CLI apps (MuSig2 CLI, address generator, ECDSA signing CLI, Schnorr verifier) merge into one executable. Scheduled in the 2026 funding round as scriptable access for developers and a low-friction demo surface for the encodings and primitives shipped in year one.

---

## Features

### Core CLI

**Purpose & User Value**: Key generation, signing (ECDSA + Schnorr), verification, and address/npub encoding from the terminal — scriptable access without writing Swift.

**Success Metrics**:
- One CLI executable with keygen / sign / verify / encode subcommands
- Address and npub output matches the Phase 4 encoding vectors
- Zero runtime dependencies maintained (Constitution)

### MuSig2 Ceremony Mode

**Purpose & User Value**: Command-line MuSig2 ceremony for scripting (the backlog's medium-priority item): key aggregation, nonce exchange, partial signing, aggregation.

**Success Metrics**:
- Ceremony state export/import between steps, so scripts can drive each stage
- Matches the existing MuSig2 test vectors

### Homebrew Formula

**Purpose & User Value**: `brew install` distribution — the demo surface for the year's shipped primitives.

**Success Metrics**:
- Formula published in a tap; `brew install` produces a working binary on macOS
- Versioned releases track package tags

---

## Phase Dependencies & Sequencing

1. **Core CLI** — after Phase 4 encodings (address/npub output)
2. **MuSig2 ceremony mode** — rides shipped MuSig2; adaptor flows optional after Phase 6
3. **Homebrew formula** — with the first tagged CLI release

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Homebrew install → working binary | Pass on macOS |
| Encoding output vs Phase 4 vectors | 100% match |
| External dependencies added | 0 |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Key material on a CLI | Misuse for real funds | Clear warnings; documented test-usage patterns (Constitution III) |
| Scope creep into wallet territory | Delay | Primitives + encodings only; no chain or wallet logic |
