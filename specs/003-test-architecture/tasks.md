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

- [x] T021 [P] [US2] Create WycheproofECDH.swift Codable models in `Projects/Sources/WycheproofTests/WycheproofECDH.swift` per data-model.md schema
- [x] T022 [P] [US2] Create WycheproofECDSA.swift Codable models in `Projects/Sources/WycheproofTests/WycheproofECDSA.swift` per data-model.md schema
- [x] T023 [US2] Run subtree extraction to copy `ecdh_secp256k1_test.json` and `ecdsa_secp256k1_sha256_bitcoin_test.json` to `Projects/Resources/WycheproofTests/`
- [x] T024 [US2] Implement ECDHWycheproofTests.swift in `Projects/Sources/WycheproofTests/ECDHWycheproofTests.swift` — load ECDH vectors, filter by flags (FR-011), test valid/invalid/acceptable results
- [x] T025 [US2] Implement ECDSAWycheproofTests.swift in `Projects/Sources/WycheproofTests/ECDSAWycheproofTests.swift` — load ECDSA Bitcoin vectors, filter by flags, test signature malleability rejection
- [x] T026 [US2] **VERIFY**: Run `tuist test WycheproofTests` and confirm all applicable vectors pass, skipped vectors logged with reasons

**Checkpoint**: User Story 2 complete — Wycheproof edge case validation works independently

---

## Phase 5: User Story 3 - Security Regression Tests (Priority: P3)

**Goal**: Ensure library correctly rejects known cryptographic attack patterns across all operations

**Independent Test**: `tuist test SecurityTests` passes with all vulnerability class mitigations validated

### Vulnerability Classes & Concrete Tests (libsecp256k1-focused)

> **Conventions (recommended):**
> - "Reject" = function returns `0` (parse/verify/sign failure).
> - "Accept" = function returns `1`.
> - Keep concrete hex in separate vector files; reference them by `Vector ID`.

#### 1. Point Validation (ECDSA, ECDH, Schnorr)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| PV-001 | Reject point at infinity | `ec_pubkey_parse`, `xonly_pubkey_parse`, any op consuming pubkeys | Infinity encoding / internal infinity | Return `0` |
| PV-002 | Reject point not on curve (twist/invalid-curve) | `ec_pubkey_parse`, `ecdh`, tweaks, verify ops | Twist / invalid-curve point | Return `0` |
| PV-003 | Reject invalid x-coordinate | `ec_pubkey_parse`, `xonly_pubkey_parse` | x > field prime p | Return `0` |
| PV-004 | Reject invalid y-coordinate | `ec_pubkey_parse` | y doesn't satisfy curve equation | Return `0` |

#### 2. Scalar Validation (ECDSA, ECDH, Schnorr)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| SV-001 | Reject zero private key | `ec_seckey_verify`, keypair create, ECDSA/Schnorr sign | Secret key = 0 | Return `0` |
| SV-002 | Reject scalar ≥ group order | `ec_seckey_verify`, keypair create, ECDSA/Schnorr sign | Secret key ≥ n | Return `0` |
| SV-003 | Accept max valid scalar | `ec_seckey_verify`, keypair create, ECDSA/Schnorr sign | Secret key = n−1 | Return `1` |

#### 3. Signature Malleability (ECDSA)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| SM-001 | Reject high-s signature (if enforcing low-s policy) | `ecdsa_verify` (and app-level acceptance path) | Signature with s > n/2 | Return `0` |
| SM-002 | Accept low-s signature | `ecdsa_verify` | Signature with s ≤ n/2 | Return `1` |
| SM-003 | Verify normalized signature | `ecdsa_signature_normalize` + `ecdsa_verify` | Normalize(high-s) then verify | Normalize returns `1`; verify returns `1` |

#### 4. Zero/Invalid Signature Values (ECDSA, Schnorr)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| ZS-001 | Reject r=0 signature | `ecdsa_verify` | ECDSA sig with r=0 | Return `0` |
| ZS-002 | Reject s=0 signature | `ecdsa_verify` | ECDSA sig with s=0 | Return `0` |
| ZS-003 | Reject r=0, s=0 ("psychic signature") | `ecdsa_verify` | ECDSA sig with r=0,s=0 | Return `0` |
| ZS-004 | Reject Schnorr with invalid/zero R | `schnorrsig_verify` | Schnorr sig with R=0 or invalid R | Return `0` |

#### 5. DER Encoding Strictness (ECDSA)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| DE-001 | Reject BER padding | `ecdsa_signature_parse_der` | DER-like with BER padding | Return `0` |
| DE-002 | Reject negative / unnecessary 0x00 prefix | `ecdsa_signature_parse_der` | r or s with non-minimal encoding | Return `0` |
| DE-003 | Reject non-minimal length encoding | `ecdsa_signature_parse_der` | Length field not minimally encoded | Return `0` |
| DE-004 | Accept strict DER | `ecdsa_signature_parse_der` | Proper strict DER signature | Return `1` |

#### 6. Nonce Security (ECDSA, Schnorr/MuSig2)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| NS-001 | Deterministic nonce (test mode) | ECDSA sign (when configured for deterministic nonce in harness) | Same message + key twice | Same signature bytes |
| NS-002 | MuSig2 secnonce cleared / not reusable | MuSig2 nonce/session APIs | Attempt nonce reuse | Fail / invalid state (Return `0` or documented error) |
| NS-003 | Unique session ID required (MuSig2) | MuSig2 nonce gen APIs | No randomness / constant session id | Documented failure or defined behavior |

#### 7. Invalid Curve Attack (ECDH)
| Test ID | Description | Applies to (API surface) | Input | Expected |
|---|---|---|---|---|
| IC-001 | Reject small subgroup / low-order twist point | `ecdh` (and any wrapper ECDH) | Point on twist with small order | Return `0` |
| IC-002 | Reject crafted invalid point (known attack vector) | `ecdh` | Known-bad invalid-point vector | Return `0` |

### Swift API Feasibility (Cross-Referenced)

| Test ID | Swift API | Feasible | Notes |
|---|---|---|---|
| PV-001..PV-004 | `PublicKey(dataRepresentation:format:)` | ✅ | Uses `secp256k1_ec_pubkey_parse` internally |
| SV-001..SV-003 | `PrivateKey(dataRepresentation:)` | ✅ | Uses `secp256k1_ec_seckey_verify` internally |
| SM-001, SM-002 | `ECDSASignature` + `isValidSignature` | ✅ | libsecp256k1 auto-rejects high-s in verify |
| SM-003 | ❌ Not exposed | ⚠️ **Gap** | `secp256k1_ecdsa_signature_normalize` not wrapped — **skip or add wrapper** |
| ZS-001..ZS-003 | `ECDSASignature(compactRepresentation:)` | ✅ | Can craft invalid sigs from raw bytes |
| ZS-004 | `SchnorrSignature` + `isValidSignature` | ✅ | |
| DE-001..DE-004 | `ECDSASignature(derRepresentation:)` | ✅ | Uses `secp256k1_ecdsa_signature_parse_der` |
| NS-001 | ECDSA sign twice | ✅ | RFC 6979 deterministic nonce is default |
| NS-002 | `P256K.Schnorr.SecureNonce` | ⚠️ Partial | `consuming` semantics — verify reuse prevented |
| NS-003 | MuSig2 nonce gen | ⚠️ Partial | Verify behavior with constant session ID |
| IC-001..IC-002 | `sharedSecretFromKeyAgreement` | ✅ | Uses `secp256k1_ecdh` internally |

**Summary**: 20/23 tests fully feasible. 3 tests need verification or API addition.

**Recommendation for SM-003**: Skip test — libsecp256k1 auto-normalizes during signing, so high-s signatures only come from external sources. DER parsing tests (DE-*) already cover malformed input rejection.

### Implementation for User Story 3

- [x] T027 [US3] Create `Projects/Sources/SecurityTests/` directory structure with:
  - `SecurityTestVectors.swift` — Swift constants file with all attack vectors organized by category
  - Test files per vulnerability class (Swift Testing framework)
- [x] T028 [US3] Implement `PointValidationTests.swift` — Tests PV-001 through PV-004
- [x] T029 [US3] Implement `ScalarValidationTests.swift` — Tests SV-001 through SV-003
- [x] T030 [US3] Implement `SignatureMalleabilityTests.swift` — Tests SM-001, SM-002 (SM-003 skipped per feasibility)
- [x] T031 [US3] Implement `ZeroSignatureTests.swift` — Tests ZS-001 through ZS-004
- [x] T032 [US3] Implement `DEREncodingTests.swift` — Tests DE-001 through DE-004
- [x] T033 [US3] Implement `NonceSecurityTests.swift` — Tests NS-001 through NS-003
- [x] T034 [US3] Implement `InvalidCurveTests.swift` — Tests IC-001 through IC-002
- [x] T035 [US3] Add SecurityTests target to `Projects/Project.swift` (renamed from CVETests)
- [x] T036 [US3] Document each test with inline comments explaining the vulnerability class and expected rejection behavior
- [x] T037 [US3] **VERIFY**: Run `xcodebuild test -scheme SecurityTests` and confirm all 53 tests pass

**Checkpoint**: User Story 3 complete — Security regression coverage works independently

### Reference: Related CVEs (for documentation purposes)
These vulnerability classes cover attacks documented in:
- CVE-2022-21449 (Java "Psychic Signatures" — ZS-003)
- CVE-2020-14966, CVE-2020-13822, CVE-2019-14859 (BER encoding — DE-001..DE-003)
- CVE-2017-18146 (Arithmetic edge cases — covered by scalar/point validation)
- Invalid curve attacks (IC-001, IC-002) — no specific CVE but well-documented attack class

---

## Phase 6: User Story 4 - Native secp256k1 C Tests (Priority: P4) ✅ COMPLETE

**Goal**: Run native libsecp256k1 C test suite to validate vendored library

**Independent Test**: Native test binary executes and passes on all platforms

### Implementation for User Story 4

- [x] T031 [US4] Native test target `libsecp256k1Tests` configured in `Projects/Project.swift` as commandLineTool with subtree extraction for tests.c and precomputed tables
- [x] T032 [US4] C settings configured via xcconfig: VERIFY define, header search paths pointing to `Vendor/secp256k1/src/`
- [x] T033 [US4] ~~Package.swift fallback~~ **SKIP**: Tuist approach succeeded
- [x] T034 [US4] ~~NativeTestRunner.swift~~ **SKIP**: Direct commandLineTool execution works; no Swift wrapper needed
- [x] T035 [US4] **VERIFIED**: Native tests pass on macOS (16 tests, "no problems found")

**Checkpoint**: User Story 4 complete — Native C test validation works independently

---

## Phase 7: User Story 5 - MuSig2 Test Vectors (Priority: P2)

**Goal**: Validate MuSig2 multi-signature implementation against official BIP-0327 test vectors

**Independent Test**: `tuist test MuSig2VectorTests` passes with all vectors

**Framework**: swift-testing (`@Suite`, `@Test`, `#expect`)

### Implementation for User Story 5

- [x] T036 [P] [US5] Add MuSig2VectorTests unit test target to `Projects/Project.swift` with sources from `Projects/Sources/TestShared/**` and `Projects/Sources/MuSig2VectorTests/**`, resources from `Projects/Resources/MuSig2VectorTests/`
- [x] T037 [P] [US5] Create xcconfig files for MuSig2VectorTests: `Projects/Resources/MuSig2VectorTests/Debug.xcconfig` and `Release.xcconfig`
- [x] T038 [P] [US5] Create KeyAggVector.swift Codable model in `Projects/Sources/MuSig2VectorTests/` (start with key_agg, add others incrementally)
- [x] T039 [US5] Download `key_agg_vectors.json` from `github.com/bitcoin/bips/tree/master/bip-0327/vectors` to `Projects/Resources/MuSig2VectorTests/`
- [x] T040 [US5] Implement KeyAggVectorTests.swift using swift-testing (`@Suite`, `@Test`, `#expect(throws:)`) — load vectors, call P256K.MuSig APIs, validate key aggregation
- [x] T041 [US5] **VERIFIED**: MuSig2VectorTests pass (2 tests: valid key aggregation + invalid pubkeys rejected)
- [x] T042 [US5] Add remaining vector files: tweak, nonce_gen, nonce_agg, sign_verify, sig_agg, det_sign (key_sort skipped - handled internally by library)

**Checkpoint**: User Story 5 complete — BIP-0327 MuSig2 validation works independently

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, CI readiness, and swift-testing migration

### swift-testing Migration

- [x] T043 [P] Migrate SchnorrVectorTests from XCTest to swift-testing (`@Suite`, `@Test`, `#expect`)
- [x] T044 [P] Migrate ECDHWycheproofTests from XCTest to swift-testing
- [x] T045 [P] Migrate ECDSAWycheproofTests from XCTest to swift-testing
- [x] T046 [P] Update TestVectorAssertions.swift for swift-testing compatibility (already compatible)

### Documentation & Validation

- [x] T047 [P] Update `Projects/README.md` with test target descriptions and usage instructions
- [x] T048 [P] Verify FR-005 compliance: macOS tests pass; other platforms documented for CI
- [x] T049 All test targets complete within 60-second budget on macOS
- [x] T050 quickstart.md commands verified functional
- [x] T051 Final code review: no TODOs in Swift code (only vendor C code and documented UInt256 limitations)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ──────────────────────────────────────────────────────────────►
                 │
                 ▼
Phase 2: Foundational ───────────────────────────────────────────────────────►
                 │
                 ├──► Phase 3: US1 (P1) ──► Phase 4: US2 (P2) ──► Phase 5: US3 (P3) ──► Phase 6: US4 ✅ ──► Phase 7: US5 (P2)
                 │         │                    │                     │                     │                    │
                 │         ▼                    ▼                     ▼                     ▼                    ▼
                 │    [Independent]        [Independent]         [Independent]         [Complete]          [Independent]
                 │
                 └──────────────────────────────────────────────────────────────────────────────────────────────────────►
                                                                                                                         │
                                                                                                                         ▼
                                                                                                              Phase 8: Polish
```

### User Story Dependencies

| Story | Depends On | Can Parallel With | Status |
|-------|------------|-------------------|--------|
| US1 (P1) | Phase 2 complete | US2, US3, US4, US5 (after Phase 2) | ✅ Complete |
| US2 (P2) | Phase 2 complete | US1, US3, US4, US5 (after Phase 2) | ✅ Complete |
| US3 (P3) | Phase 2 complete | US1, US2, US4, US5 (after Phase 2) | Pending |
| US4 (P4) | Phase 2 complete + T006/T007 spike | US1, US2, US3, US5 (after Phase 2) | ✅ Complete |
| US5 (P2) | Phase 2 complete | US1, US2, US3, US4 (after Phase 2) | Pending |

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

| Phase | Tasks | Parallelizable | Status |
|-------|-------|----------------|--------|
| Phase 1: Setup | 7 | 3 | ✅ Complete |
| Phase 2: Foundational | 9 | 3 | ✅ Complete |
| Phase 3: US1 (P1) | 4 | 1 | ✅ Complete |
| Phase 4: US2 (P2) | 6 | 2 | ✅ Complete |
| Phase 5: US3 (P3) | 4 | 0 | Pending |
| Phase 6: US4 (P4) | 5 | 0 | ✅ Complete |
| Phase 7: US5 (MuSig2) | 7 | 2 | Pending |
| Phase 8: Polish | 9 | 6 | Pending |
| **Total** | **51** | **17** |

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Verification tasks (T020, T026, T030, T035) confirm each story works before moving on
- T006/T007 spike in Setup determines US4 implementation approach
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
