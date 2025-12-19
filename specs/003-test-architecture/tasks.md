# Tasks: Test Architecture under Projects/

**Input**: Design documents from `/specs/003-test-architecture/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: Minimal verification tasks included (one integration check per target)

**Organization**: Tasks grouped by user story for independent implementation and testing

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- All paths are absolute from repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, shared utilities, and native C test spike

- [x] T001 Create directory structure: `Projects/Sources/TestShared/`, `Projects/Sources/SchnorrVectorTests/`, `Projects/Sources/WycheproofTests/`, `Projects/Sources/CVETests/`, `Projects/Sources/NativeSecp256k1Tests/`
- [x] T002 Create directory structure: `Projects/Resources/SchnorrVectorTests/`, `Projects/Resources/WycheproofTests/`, `Projects/Resources/CVETests/`
- [x] T003 [P] ~~Implement HexDump.swift~~ **SKIP**: Reuse existing `Sources/Shared/swift-crypto/.../PrettyBytes.swift` and `Sources/Shared/Utility.swift` hex utilities — include in TestShared sources or import via module
- [x] T004 [P] Implement TestVectorLoader.swift in `Projects/Sources/TestShared/TestVectorLoader.swift` per TestVectorLoader protocol
- [x] T005 [P] Implement TestVectorAssertions.swift in `Projects/Sources/TestShared/TestVectorAssertions.swift` per TestVectorAssertion protocol
- [x] T006 **SPIKE**: Test Tuist commandLineTool for native C tests — create minimal target in `Projects/Project.swift` pointing to `Vendor/secp256k1/src/tests.c` with VERIFY flag → **RESULT: SUCCESS** (via subtree extraction of precomputed tables)
- [x] T007 Document spike results: Tuist commandLineTool works with subtree extraction → **Decision: Use subtree.yaml extraction for tests.c + precomputed tables** (see `spike-native-tests.md`)

**Checkpoint**: Shared utilities ready, native C approach determined

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Tuist target definitions and test vector resources that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T008 Add SchnorrVectorTests unit test target to `Projects/Project.swift` with sources from `Projects/Sources/TestShared/**` and `Projects/Sources/SchnorrVectorTests/**`, resources from `Projects/Resources/SchnorrVectorTests/**`
- [x] T009 Add WycheproofTests unit test target to `Projects/Project.swift` with sources from `Projects/Sources/TestShared/**` and `Projects/Sources/WycheproofTests/**`, resources from `Projects/Resources/WycheproofTests/**`
- [x] T010 Add CVETests unit test target to `Projects/Project.swift` with sources from `Projects/Sources/TestShared/**` and `Projects/Sources/CVETests/**`, resources from `Projects/Resources/CVETests/**`
- [x] T011 Add NativeSecp256k1Tests target to `Projects/Project.swift` (commandLineTool or unit test wrapper based on T006 spike result) → **Already done as libsecp256k1Tests**
- [x] T012 [P] Create xcconfig files for SchnorrVectorTests: `Projects/Resources/SchnorrVectorTests/Debug.xcconfig` and `Release.xcconfig`
- [x] T013 [P] Create xcconfig files for WycheproofTests: `Projects/Resources/WycheproofTests/Debug.xcconfig` and `Release.xcconfig`
- [x] T014 [P] Create xcconfig files for CVETests: `Projects/Resources/CVETests/Debug.xcconfig` and `Release.xcconfig`
- [x] T015 Update `subtree.yaml` to extract Wycheproof JSON files from `Vendor/secp256k1/src/wycheproof/` to `Projects/Resources/WycheproofTests/`
- [x] T016 Run `tuist generate` and verify all targets appear in generated Xcode project

**Checkpoint**: All Tuist targets defined, `tuist generate` succeeds

---

## Phase 3: User Story 1 - BIP-340 Schnorr Test Vectors (Priority: P1) 🎯 MVP

**Goal**: Validate Schnorr signature implementation against official BIP-340 test vectors

**Independent Test**: `tuist test SchnorrVectorTests` passes with all vectors

### Implementation for User Story 1

- [x] T017 [P] [US1] Create BIP340Vector.swift Codable model in `Projects/Sources/SchnorrVectorTests/BIP340Vector.swift` per data-model.md schema
- [x] T018 [US1] Convert BIP-340 CSV to JSON: download from `github.com/bitcoin/bips/blob/master/bip-0340/test-vectors.csv`, convert using simple Python/Swift script per research.md schema, save to `Projects/Resources/SchnorrVectorTests/bip340-vectors.json`
- [x] T019 [US1] Implement SchnorrVectorTests.swift in `Projects/Sources/SchnorrVectorTests/SchnorrVectorTests.swift` — load vectors, iterate, call P256K Schnorr APIs, use TestVectorAssertions for diagnostics
- [x] T020 [US1] **VERIFY**: Run `tuist test SchnorrVectorTests` and confirm all BIP-340 vectors pass with verbose output on any failure

**Checkpoint**: User Story 1 complete — BIP-340 Schnorr validation works independently

---

## Phase 4: User Story 2 - Wycheproof Edge Case Vectors (Priority: P2)

**Goal**: Validate ECDSA and ECDH implementations against Wycheproof test vectors

**Independent Test**: `tuist test WycheproofTests` passes with all applicable vectors

### Implementation for User Story 2

- [ ] T021 [P] [US2] Create WycheproofECDH.swift Codable models in `Projects/Sources/WycheproofTests/WycheproofECDH.swift` per data-model.md schema
- [ ] T022 [P] [US2] Create WycheproofECDSA.swift Codable models in `Projects/Sources/WycheproofTests/WycheproofECDSA.swift` per data-model.md schema
- [ ] T023 [US2] Run subtree extraction to copy `ecdh_secp256k1_test.json` and `ecdsa_secp256k1_sha256_bitcoin_test.json` to `Projects/Resources/WycheproofTests/`
- [ ] T024 [US2] Implement ECDHWycheproofTests.swift in `Projects/Sources/WycheproofTests/ECDHWycheproofTests.swift` — load ECDH vectors, filter by flags (FR-011), test valid/invalid/acceptable results
- [ ] T025 [US2] Implement ECDSAWycheproofTests.swift in `Projects/Sources/WycheproofTests/ECDSAWycheproofTests.swift` — load ECDSA Bitcoin vectors, filter by flags, test signature malleability rejection
- [ ] T026 [US2] **VERIFY**: Run `tuist test WycheproofTests` and confirm all applicable vectors pass, skipped vectors logged with reasons

**Checkpoint**: User Story 2 complete — Wycheproof edge case validation works independently

---

## Phase 5: User Story 3 - CVE Regression Tests (Priority: P3)

**Goal**: Ensure library is not vulnerable to known secp256k1 CVEs

**Independent Test**: `tuist test CVETests` passes with all CVE mitigations validated

### Implementation for User Story 3

- [ ] T027 [US3] Create CVETestCase.swift in `Projects/Sources/CVETests/CVETestCase.swift` — define struct for CVE ID, description, test input, expected behavior
- [ ] T028 [US3] Implement CVETests.swift in `Projects/Sources/CVETests/CVETests.swift` with test cases for CVEs identified in research.md:
  - Invalid curve attack (twisted curve ECDH)
  - Signature malleability (s > n/2)
  - Zero signature values (r=0, s=0)
  - BER vs DER encoding
  - Arithmetic edge cases
- [ ] T029 [US3] Document each CVE test with inline comments explaining the vulnerability and expected rejection behavior
- [ ] T030 [US3] **VERIFY**: Run `tuist test CVETests` and confirm all CVE mitigations pass

**Checkpoint**: User Story 3 complete — CVE regression coverage works independently

---

## Phase 6: User Story 4 - Native secp256k1 C Tests (Priority: P4)

**Goal**: Run native libsecp256k1 C test suite to validate vendored library

**Independent Test**: Native test binary executes and passes on all platforms

### Implementation for User Story 4

- [ ] T031 [US4] Based on T006/T007 spike: Finalize native test target configuration in `Projects/Project.swift` (Tuist commandLineTool or Swift wrapper invoking Package.swift executable)
- [ ] T032 [US4] If Tuist approach: Configure C settings (VERIFY define, header search paths pointing to `Vendor/secp256k1/src/`)
- [ ] T033 [US4] If Package.swift fallback: Create `Projects/Package.swift` with executableTarget for `secp256k1-tests`
- [ ] T034 [US4] Implement NativeTestRunner.swift in `Projects/Sources/NativeSecp256k1Tests/NativeTestRunner.swift` — wrapper that executes native binary and reports results
- [ ] T035 [US4] **VERIFY**: Run native tests on macOS and confirm pass; document any platform-specific issues

**Checkpoint**: User Story 4 complete — Native C test validation works independently

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and CI readiness

- [ ] T036 [P] Update `Projects/README.md` with test target descriptions and usage instructions
- [ ] T037 [P] Verify FR-005 compliance: run all test targets on all platforms (iPhone, iPad, Mac, Apple Watch, Apple TV, Apple Vision) via `tuist test --device` for each destination
- [ ] T038 Verify each test target completes within 60-second budget (SC-008)
- [ ] T039 Run quickstart.md validation: execute all commands and verify outputs match documentation
- [ ] T040 Final code review: ensure all files follow Swift conventions, no TODOs remain

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ──────────────────────────────────────────────────────────────►
                 │
                 ▼
Phase 2: Foundational ───────────────────────────────────────────────────────►
                 │
                 ├──► Phase 3: US1 (P1) ──► Phase 4: US2 (P2) ──► Phase 5: US3 (P3) ──► Phase 6: US4 (P4)
                 │         │                    │                     │                     │
                 │         ▼                    ▼                     ▼                     ▼
                 │    [Independent]        [Independent]         [Independent]         [Independent]
                 │
                 └──────────────────────────────────────────────────────────────────────────────────────►
                                                                                                         │
                                                                                                         ▼
                                                                                              Phase 7: Polish
```

### User Story Dependencies

| Story | Depends On | Can Parallel With |
|-------|------------|-------------------|
| US1 (P1) | Phase 2 complete | US2, US3, US4 (after Phase 2) |
| US2 (P2) | Phase 2 complete | US1, US3, US4 (after Phase 2) |
| US3 (P3) | Phase 2 complete | US1, US2, US4 (after Phase 2) |
| US4 (P4) | Phase 2 complete + T006/T007 spike | US1, US2, US3 (after Phase 2) |

### Within Each User Story

1. Models/Codable structs first (parallelizable)
2. Resource files (JSON vectors)
3. Test implementation
4. Verification run

### Parallel Opportunities

**Phase 1 (Setup)**:
- T003, T004, T005 can run in parallel (different files)

**Phase 2 (Foundational)**:
- T012, T013, T014 can run in parallel (different xcconfig directories)

**Phase 3+ (User Stories)**:
- All user stories can run in parallel after Phase 2 completes
- Within US2: T021, T022 can run in parallel (different model files)

---

## Parallel Example: Phase 2 xcconfig Tasks

```bash
# These can all run simultaneously:
Task T012: "Create xcconfig files for SchnorrVectorTests"
Task T013: "Create xcconfig files for WycheproofTests"  
Task T014: "Create xcconfig files for CVETests"
```

## Parallel Example: User Stories After Phase 2

```bash
# With multiple developers, all can start simultaneously:
Developer A: Phase 3 (US1 - BIP-340 Schnorr)
Developer B: Phase 4 (US2 - Wycheproof)
Developer C: Phase 5 (US3 - CVE Tests)
Developer D: Phase 6 (US4 - Native C Tests)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T007)
2. Complete Phase 2: Foundational (T008-T016)
3. Complete Phase 3: User Story 1 (T017-T020)
4. **STOP and VALIDATE**: `tuist test SchnorrVectorTests` passes
5. MVP delivered — BIP-340 validation working

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. Add US1 → BIP-340 Schnorr validation (MVP!)
3. Add US2 → Wycheproof edge cases
4. Add US3 → CVE regression coverage
5. Add US4 → Native C library validation
6. Each story adds coverage without breaking previous stories

### Suggested MVP Scope

**Minimum viable**: Phase 1 + Phase 2 + Phase 3 (User Story 1)
- Delivers BIP-340 Schnorr test vector validation
- Proves infrastructure works
- ~17 tasks to MVP

---

## Task Summary

| Phase | Tasks | Parallelizable |
|-------|-------|----------------|
| Phase 1: Setup | 7 | 3 |
| Phase 2: Foundational | 9 | 3 |
| Phase 3: US1 (P1) | 4 | 1 |
| Phase 4: US2 (P2) | 6 | 2 |
| Phase 5: US3 (P3) | 4 | 0 |
| Phase 6: US4 (P4) | 5 | 0 |
| Phase 7: Polish | 5 | 2 |
| **Total** | **40** | **11** |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verification tasks (T020, T026, T030, T035) confirm each story works before moving on
- T006/T007 spike in Setup determines US4 implementation approach
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
