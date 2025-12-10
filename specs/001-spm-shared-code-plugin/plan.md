# Implementation Plan: SPM Pre-Build Plugin for Shared Code

**Branch**: `001-spm-shared-code-plugin` | **Date**: 2025-12-08 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-spm-shared-code-plugin/spec.md`

## Summary

Create an SPM `BuildToolPlugin` that copies files from `Sources/Shared/` into each target's build directory before compilation, eliminating the need for symlinks. The plugin uses system `rsync` command (via `/usr/bin/env`) for file operations on macOS and Linux. Windows support is deferred with a placeholder. Migration includes removing existing symlinks and updating Tuist configuration.

> **Revision 2025-12-08**: Simplified from custom executable to rsync due to SPM limitation
> (prebuild plugins cannot use executables built from the same package).

## Technical Context

**Language/Version**: Swift 5.9+ (required for stable `prebuildCommand` support)  
**Primary Dependencies**: System `rsync` command (standard on macOS/Linux)  
**Storage**: N/A (build-time file operations only)  
**Testing**: Manual verification via `swift build` (no custom code to unit test)  
**Target Platform**: macOS, Linux (Windows deferred)  
**Project Type**: SPM plugin within existing monorepo  
**Performance Goals**: < 5% build time impact compared to symlink approach  
**Constraints**: Must work without symlinks; must preserve existing `#if canImport` patterns  
**Scale/Scope**: 20 shared files initially; plugin scoped to this repository only

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Scope & Bitcoin Standards** | PASS | Tooling change; does not affect cryptographic scope |
| **II. Cryptographic Correctness** | PASS | No cryptographic changes; file copying only |
| **III. Key & Secret Handling** | PASS | No secret handling in plugin |
| **IV. API Design & Safety** | PASS | Internal tooling; no public API changes |
| **V. Spec-First & TDD** | PASS | Spec complete; tests planned (unit + integration) |
| **VI. Cross-Platform CI** | PASS | Plugin designed for macOS, Linux, Windows |
| **VII. Open Source Excellence** | PASS | Simplifies codebase; improves discoverability |

**Zero-Dependency Check**: PASS — Plugin uses system `rsync` command, no Swift dependencies added.

## Project Structure

### Documentation (this feature)

```text
specs/001-spm-shared-code-plugin/
├── plan.md              # This file
├── research.md          # Phase 0: SPM BuildToolPlugin research
├── data-model.md        # Phase 1: Plugin data flow
├── quickstart.md        # Phase 1: Developer guide
├── contracts/           # N/A (internal tooling, no API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
# Plugin implementation (simplified - uses rsync)
Plugins/
└── SharedSourcesPlugin/
    └── Plugin.swift              # BuildToolPlugin using rsync via /usr/bin/env

# Shared sources (new directory)
Sources/
├── Shared/                       # NEW: Canonical location for shared code
│   ├── Asymmetric.swift
│   ├── Combine.swift
│   ├── Context.swift
│   ├── DH.swift
│   ├── ECDH.swift
│   ├── ECDSA.swift
│   ├── EdDSA.swift
│   ├── Errors.swift
│   ├── HashDigest.swift
│   ├── MuSig.swift
│   ├── Nonces.swift
│   ├── P256K.swift
│   ├── Recovery.swift
│   ├── SafeCompare.swift
│   ├── Schnorr.swift
│   ├── SHA256.swift
│   ├── Tweak.swift
│   ├── UInt256.swift
│   ├── Utility.swift
│   └── Zeroization.swift
├── P256K/                        # Target-specific code only (symlinks removed)
│   ├── ASN1/
│   └── swift-crypto/
└── ZKP/                          # Target-specific code only

# Tuist project (updated)
Projects/
├── Project.swift                 # Updated: sources include Shared/
└── Sources/
    ├── Shared -> ../../Sources/Shared  # NEW: Directory symlink (macOS-only)
    └── P256K/                    # File symlinks removed
        ├── ASN1/
        └── swift-crypto/

# Tests (no plugin-specific tests - using system rsync)
Tests/
└── (existing tests verify shared code compiles correctly)
```

**Structure Decision**: Plugin lives in `Plugins/SharedSourcesPlugin/` following SPM convention. Shared sources move to `Sources/Shared/`. Plugin uses system `rsync` for file copying. Tuist uses a single directory symlink rather than 20 file symlinks.

## Planning Decisions

### From Clarifying Questions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Plugin complexity | Minimal using system `rsync` | SPM prebuild cannot use built executables; rsync is robust and available |
| Testing strategy | Manual `swift build` verification | No custom code to test; rsync is battle-tested |
| Migration execution | Atomic in feature branch | Ensures repository never in inconsistent state; easier to review/revert |

## Complexity Tracking

> No constitution violations requiring justification.
