# Implementation Plan: Test Architecture under Projects/

**Branch**: `003-test-architecture` | **Date**: 2025-12-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-test-architecture/spec.md`

## Summary

Establish a robust testing infrastructure under `Projects/` with four dedicated test targets (SchnorrVectorTests, WycheproofTests, CVETests, NativeSecp256k1Tests) to validate cryptographic correctness against official test vectors and known vulnerabilities. Test vectors loaded as bundle resources with verbose diagnostic assertions.

## Technical Context

**Language/Version**: Swift 6.0+, C89 (for native tests)  
**Primary Dependencies**: Tuist (ProjectDescription), XCTest, P256K (library under test)  
**Storage**: JSON files (test vectors) as bundle resources  
**Testing**: XCTest with custom assertion helpers  
**Target Platform**: iOS 18+, macOS 15+, watchOS 11+, tvOS 18+, visionOS 2+ (all platforms)  
**Project Type**: Test infrastructure (extends existing Projects/ structure)  
**Performance Goals**: Each test target completes within 60 seconds on CI  
**Constraints**: Zero runtime dependencies; test utilities shared via source inclusion  
**Scale/Scope**: ~15 BIP-340 vectors, ~1000 Wycheproof vectors, CVE regression suite, native C test binary

**Research Resolved** (see [research.md](./research.md)):
- ✅ Native C tests: Tuist commandLineTool (primary) → Package.swift fallback; minimal spike in Setup phase
- ✅ BIP-340 conversion: Simple script (Python/Swift) to convert CSV→JSON; one-time task
- ✅ Wycheproof schema: Swift Codable models defined in [data-model.md](./data-model.md)
- ✅ CVE enumeration: 10+ CVEs identified from Wycheproof data (see research.md Section 4)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| **I. Scope & Bitcoin Standards** | ✅ PASS | Test vectors align with BIP-340, Wycheproof (Bitcoin-specific), libsecp256k1 |
| **II. Cryptographic Correctness** | ✅ PASS | Feature validates correctness via published test vectors (core requirement) |
| **III. Key & Secret Handling** | ✅ PASS | Test vectors use published keys; no secret generation in test infrastructure |
| **IV. API Design & Safety** | ✅ PASS | Test utilities follow Swift conventions; verbose errors aid debugging |
| **V. Spec-First & TDD** | ✅ PASS | Spec created first; tests written before implementation (TDD by design) |
| **VI. Cross-Platform CI** | ✅ PASS | All test targets support all platforms; 60s timeout enforces determinism |
| **VII. Open Source Excellence** | ✅ PASS | Clear documentation; shared utilities follow DRY principle |

**Gate Result**: ✅ **PASSED** — No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/003-test-architecture/
├── plan.md              # This file
├── research.md          # Phase 0: Research findings
├── data-model.md        # Phase 1: JSON schemas + Swift Codable models
├── quickstart.md        # Phase 1: Quick start guide
├── contracts/           # Phase 1: Swift protocol interfaces
│   └── TestVectorProtocols.swift
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Projects/
├── Project.swift                    # Tuist manifest (add new targets here)
├── Sources/
│   ├── TestShared/                  # NEW: Shared test utilities
│   │   ├── TestVectorAssertions.swift
│   │   └── TestVectorLoader.swift
│   │   # NOTE: Hex utilities reused from Sources/Shared/swift-crypto/.../PrettyBytes.swift
│   ├── SchnorrVectorTests/          # NEW: BIP-340 test target sources
│   │   └── SchnorrVectorTests.swift
│   ├── WycheproofTests/             # NEW: Wycheproof test target sources
│   │   ├── ECDHWycheproofTests.swift
│   │   └── ECDSAWycheproofTests.swift
│   ├── CVETests/                    # NEW: CVE regression test sources
│   │   └── CVETests.swift
│   └── NativeSecp256k1Tests/        # NEW: Native C test wrapper (if Tuist approach)
│       └── NativeTestRunner.swift
├── Resources/
│   ├── SchnorrVectorTests/          # NEW: BIP-340 JSON vectors
│   │   └── bip340-vectors.json
│   ├── WycheproofTests/             # NEW: Wycheproof JSON vectors (via subtree)
│   │   ├── ecdh_secp256k1_test.json
│   │   └── ecdsa_secp256k1_sha256_bitcoin_test.json
│   ├── CVETests/                    # NEW: xcconfig only (no JSON vectors - tests are code-defined)
│   │   ├── Debug.xcconfig
│   │   └── Release.xcconfig
│   └── [other existing resources]
└── [existing targets: P256K, P256KTests, libsecp256k1Tests, XCFrameworkApp]

subtree.yaml                         # UPDATE: Add Wycheproof extraction rules
```

**Structure Decision**: Extends existing `Projects/` structure with new test targets. Shared utilities in `Projects/Sources/TestShared/` included by each test target (not a separate framework). Test vectors as bundle resources in `Projects/Resources/[TargetName]/`.

## Complexity Tracking

> No constitution violations. No complexity justification needed.
