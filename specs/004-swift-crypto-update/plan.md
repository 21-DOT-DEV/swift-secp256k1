# Implementation Plan: swift-crypto 4.2.0 Update

**Branch**: `004-swift-crypto-update` | **Date**: 2025-12-26 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/004-swift-crypto-update/spec.md`

## Summary

Update the vendored swift-crypto dependency from 3.11.1 to 4.2.0 using the subtree plugin, then resolve any breaking availability attribute changes in `Sources/Shared/` on a case-by-case basis. Files using `StaticBigInt` (e.g., `UInt256.swift`) retain their current higher availability requirements.

## Technical Context

**Language/Version**: Swift 6.0+  
**Primary Dependencies**: libsecp256k1, swift-crypto (vendored)  
**Storage**: N/A  
**Testing**: swift-testing, XCTest  
**Target Platform**: iOS 13+, macOS 10.15+, watchOS 6+, tvOS 13+, visionOS 1.0+, Linux  
**Project Type**: Swift Package (library)  
**Performance Goals**: N/A (dependency update)  
**Constraints**: No public API changes, no Package.swift modifications, Linux compatibility required  
**Scale/Scope**: ~20 files in Sources/Shared/swift-crypto/, ~20 files in Sources/Shared/

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Scope & Bitcoin Standards | ✅ Pass | swift-crypto is existing vendored dependency, not new |
| II. Cryptographic Correctness | ✅ Pass | No changes to cryptographic primitives |
| III. Key & Secret Handling | ✅ Pass | No changes to secret handling |
| IV. API Design & Safety | ✅ Pass | No public API changes (blocker condition) |
| V. Spec-First & TDD | ✅ Pass | Spec created, tests verify correctness |
| VI. Cross-Platform CI | ✅ Pass | Full test matrix required per spec |
| VII. Open Source Excellence | ✅ Pass | CHANGELOG.md to be created/updated |

**Gate Result**: ✅ PASS — No constitutional violations.

## Project Structure

### Documentation (this feature)

```text
specs/004-swift-crypto-update/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file
├── research.md          # Breaking changes analysis (complete)
├── quickstart.md        # Execution guide with checkpoints (complete)
├── checklists/
│   └── requirements.md  # Spec quality checklist (complete)
└── tasks.md             # Task list (complete)
```

### Source Code (affected paths)

```text
Vendor/swift-crypto/           # Updated by subtree plugin
Sources/Shared/swift-crypto/   # Extraction destination
Sources/Shared/                # May need availability fixes
├── UInt256.swift              # Keep higher availability (StaticBigInt)
├── *.swift                    # Evaluate case-by-case
subtree.yaml                   # Auto-updated by subtree CLI
CHANGELOG.md                   # Create or update
```

**Structure Decision**: No structural changes. This is a dependency update affecting vendored files and potentially availability annotations in existing shared code.

## Complexity Tracking

> No constitutional violations requiring justification.
