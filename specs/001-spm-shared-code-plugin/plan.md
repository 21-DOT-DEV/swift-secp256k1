# Implementation Plan: SPM Pre-Build Plugin for Shared Code

**Branch**: `001-spm-shared-code-plugin` | **Date**: 2025-12-08 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-spm-shared-code-plugin/spec.md`

## Summary

Create an SPM `BuildToolPlugin` that copies files from `Sources/Shared/` into each target's build directory before compilation, eliminating the need for symlinks. The plugin uses `find + cp` to flatten all `.swift` files (including nested subdirectories like `swift-crypto/`) into a single output directory. Windows support is deferred with a placeholder.

> **Revision 2025-12-08**: Simplified from custom executable to system commands due to SPM limitation
> (prebuild plugins cannot use executables built from the same package).
>
> **Revision 2025-12-09**: Changed from `rsync` to `find + cp` for Docker/Linux compatibility.
> Plugin now flattens all `.swift` files because SPM doesn't recursively include subdirectories from plugin output.

## Technical Context

**Language/Version**: Swift 5.9+ (required for stable `prebuildCommand` support)  
**Primary Dependencies**: POSIX `find` and `cp` commands (standard on macOS/Linux)  
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

**Zero-Dependency Check**: PASS — Plugin uses POSIX `find` and `cp` commands, no Swift dependencies added.

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
# Plugin implementation (simplified - uses find + cp for flattening)
Plugins/
└── SharedSourcesPlugin/
    └── Plugin.swift              # BuildToolPlugin using find + cp via /bin/sh

# Shared sources (new directory)
Sources/
├── Shared/                       # NEW: Canonical location for shared code
│   ├── *.swift                  # 20 core shared files
│   ├── README.md                 # Documentation
│   └── swift-crypto/             # Dependency files (extracted via subtree.yaml)
│       └── Sources/Crypto/...    # 23 swift-crypto files
├── P256K/                        # Target-specific code only
│   └── Placeholder.swift
└── ZKP/                          # Target-specific code only
    └── Placeholder.swift

# Tuist project (updated)
Projects/
├── Project.swift                 # Updated: sources include Shared/
└── Sources/
    ├── Shared -> ../../Sources/Shared      # Directory symlink (macOS-only)
    ├── P256KTests -> ../../Tests/ZKPTests  # Directory symlink
    └── libsecp256k1Tests -> ...            # Directory symlink

# Tests (no plugin-specific tests - using system rsync)
Tests/
└── (existing tests verify shared code compiles correctly)
```

**Structure Decision**: Plugin lives in `Plugins/SharedSourcesPlugin/` following SPM convention. Shared sources (20 core + 23 swift-crypto) are in `Sources/Shared/`. Plugin flattens all `.swift` files via `find + cp`. Tuist uses 3 directory symlinks (consolidated from 20+ file symlinks).

## Planning Decisions

### From Clarifying Questions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Plugin complexity | Minimal using `find + cp` | SPM prebuild cannot use built executables; find/cp are POSIX standard |
| Testing strategy | Manual `swift build` verification | No custom code to test; rsync is battle-tested |
| Migration execution | Atomic in feature branch | Ensures repository never in inconsistent state; easier to review/revert |

## Complexity Tracking

> No constitution violations requiring justification.
