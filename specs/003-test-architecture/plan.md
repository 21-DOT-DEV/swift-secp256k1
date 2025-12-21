# Implementation Plan: Test Architecture under Projects/

**Branch**: `003-test-architecture` | **Date**: 2025-12-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-test-architecture/spec.md`

## Summary

Establish a robust testing infrastructure under `Projects/` with five dedicated test targets (SchnorrVectorTests, WycheproofTests, SecurityTests, NativeSecp256k1Tests, MuSig2VectorTests) to validate cryptographic correctness against official test vectors and known vulnerability classes. Test vectors loaded as bundle resources with verbose diagnostic assertions.

## Technical Context

**Language/Version**: Swift 6.0+, C89 (for native tests)  
**Primary Dependencies**: Tuist (ProjectDescription), XCTest, P256K (library under test)  
**Storage**: JSON files (test vectors) as bundle resources  
**Testing**: XCTest with custom assertion helpers  
**Target Platform**: iOS 18+, macOS 15+, watchOS 11+, tvOS 18+, visionOS 2+ (all platforms)  
**Project Type**: Test infrastructure (extends existing Projects/ structure)  
**Performance Goals**: Each test target completes within 60 seconds on CI  
**Constraints**: Zero runtime dependencies; test utilities shared via source inclusion  
**Scale/Scope**: ~19 BIP-340 vectors, ~1000 Wycheproof vectors, ~23 security regression tests, native C test binary, ~50 BIP-0327 MuSig2 vectors

**Research Resolved** (see [research.md](./research.md)):
- ✅ Native C tests: Tuist commandLineTool (primary) → Package.swift fallback; minimal spike in Setup phase
- ✅ BIP-340 conversion: Simple script (Python/Swift) to convert CSV→JSON; one-time task
- ✅ Wycheproof schema: Swift Codable models defined in [data-model.md](./data-model.md)
- ✅ Vulnerability classes: 7 classes identified covering 23 concrete tests (see tasks.md Phase 5)

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
│   ├── TestShared/                  # Shared test utilities
│   │   ├── TestVectorAssertions.swift
│   │   └── TestVectorLoader.swift
│   │   # NOTE: Hex utilities reused from Sources/Shared/swift-crypto/.../PrettyBytes.swift
│   ├── SchnorrVectorTests/          # BIP-340 test target sources ✅
│   │   └── SchnorrVectorTests.swift
│   ├── WycheproofTests/             # Wycheproof test target sources ✅
│   │   ├── ECDHWycheproofTests.swift
│   │   └── ECDSAWycheproofTests.swift
│   ├── SecurityTests/               # Security regression test sources
│   │   ├── PointValidationTests.swift
│   │   ├── ScalarValidationTests.swift
│   │   ├── SignatureMalleabilityTests.swift
│   │   ├── ZeroSignatureTests.swift
│   │   ├── DEREncodingTests.swift
│   │   ├── NonceSecurityTests.swift
│   │   └── InvalidCurveTests.swift
│   ├── libsecp256k1Tests/           # Native C test sources ✅
│   │   └── tests.c (via subtree)
│   └── MuSig2VectorTests/           # NEW: BIP-0327 MuSig2 test sources
│       ├── BIP327Vector.swift       # Codable models for all vector types
│       └── MuSig2VectorTests.swift
├── Resources/
│   ├── SchnorrVectorTests/          # BIP-340 JSON vectors ✅
│   │   └── bip340-vectors.json
│   ├── WycheproofTests/             # Wycheproof JSON vectors (via subtree) ✅
│   │   ├── ecdh_secp256k1_test.json
│   │   └── ecdsa_secp256k1_sha256_bitcoin_test.json
│   ├── SecurityTests/               # xcconfig only (no JSON vectors - tests are code-defined)
│   │   ├── Debug.xcconfig
│   │   └── Release.xcconfig
│   ├── MuSig2VectorTests/           # NEW: BIP-0327 MuSig2 JSON vectors
│   │   ├── key_agg_vectors.json
│   │   ├── key_sort_vectors.json
│   │   ├── nonce_gen_vectors.json
│   │   ├── nonce_agg_vectors.json
│   │   ├── sign_verify_vectors.json
│   │   ├── sig_agg_vectors.json
│   │   ├── det_sign_vectors.json
│   │   └── tweak_vectors.json
│   └── [other existing resources]
└── [existing targets: P256K, P256KTests, libsecp256k1Tests, XCFrameworkApp]

subtree.yaml                         # UPDATE: Add Wycheproof extraction rules
```

**Structure Decision**: Extends existing `Projects/` structure with new test targets. Shared utilities in `Projects/Sources/TestShared/` included by each test target (not a separate framework). Test vectors as bundle resources in `Projects/Resources/[TargetName]/`.

## Complexity Tracking

> No constitution violations. No complexity justification needed.
