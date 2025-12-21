# Feature Specification: Test Architecture under Projects/

**Feature Branch**: `003-test-architecture`  
**Created**: 2025-12-15  
**Status**: Draft  
**Input**: User description: "Architect a robust testing structure under Projects/ with separate test targets for BIP-340 Schnorr vectors, Wycheproof vectors, CVE tests, and native secp256k1 tests"

## Clarifications

### Session 2025-12-15

- Q: Where should shared TestVectorAssertions.swift utility live? → A: Shared source directory (`Projects/Sources/TestShared/`) included in each test target's sources
- Q: How should missing/malformed test vector files be handled? → A: Fail fast with clear error message
- Q: What is the test execution time budget? → A: 60 seconds per target on CI
- Q: How should unsupported test vector features be handled? → A: Filter at load time based on flags, with documented skip reasons for each excluded category

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run BIP-340 Schnorr Test Vectors (Priority: P1)

As a library maintainer, I want to validate Schnorr signature implementation against official BIP-340 test vectors so that I can ensure cryptographic correctness before releases.

**Why this priority**: Schnorr signatures are a core cryptographic primitive. BIP-340 vectors are the authoritative source for correctness validation. This is the highest-value test coverage.

**Independent Test**: Can be fully tested by running `tuist test SchnorrVectorTests` and delivers confidence that signing/verification matches the Bitcoin specification.

**Acceptance Scenarios**:

1. **Given** the SchnorrVectorTests target exists with BIP-340 JSON vectors loaded, **When** I run the test target, **Then** all official test vectors pass with clear diagnostic output on any failure.
2. **Given** a vector with an invalid signature, **When** verification is attempted, **Then** the test confirms rejection and reports expected vs actual values.

---

### User Story 2 - Run Wycheproof Edge Case Vectors (Priority: P2)

As a library maintainer, I want to validate ECDSA and ECDH implementations against Wycheproof test vectors so that I can ensure the library handles cryptographic edge cases and attack vectors correctly.

**Why this priority**: Wycheproof vectors cover edge cases that normal testing misses (low-order points, boundary values, malformed inputs). Critical for security but secondary to core algorithm correctness.

**Independent Test**: Can be fully tested by running `tuist test WycheproofTests` and delivers assurance that edge cases are handled securely.

**Acceptance Scenarios**:

1. **Given** the WycheproofTests target exists with ECDH and ECDSA Bitcoin JSON vectors loaded, **When** I run the test target, **Then** all applicable vectors pass.
2. **Given** a vector marked as "invalid" in Wycheproof data, **When** the operation is attempted, **Then** the library correctly rejects it.

---

### User Story 3 - Run Security Regression Tests (Priority: P3)

As a library maintainer, I want to run tests for known cryptographic vulnerability classes so that I can ensure the library correctly rejects attack patterns across all operations.

**Why this priority**: Security tests provide regression coverage for known vulnerability classes (point validation, signature malleability, invalid curve attacks, etc.). Important for security assurance but tests are code-defined rather than vector-driven.

**Independent Test**: Can be fully tested by running `tuist test SecurityTests` and delivers documented proof of vulnerability class mitigation.

**Acceptance Scenarios**:

1. **Given** the SecurityTests target exists with test cases for documented vulnerability classes, **When** I run the test target, **Then** all security mitigations are validated.
2. **Given** a twisted curve attack input (invalid curve point), **When** ECDH is attempted, **Then** the library rejects the input.
3. **Given** a high-s ECDSA signature, **When** verification is attempted, **Then** the library rejects as non-canonical.

---

### User Story 4 - Run Native secp256k1 C Tests (Priority: P4) ✅ COMPLETE

As a library maintainer, I want to run the native libsecp256k1 C test suite so that I can validate the vendored C library functions correctly on all platforms.

**Why this priority**: Native tests validate the C library independently of Swift wrappers. Lower priority because Swift wrapper tests already exercise most code paths.

**Independent Test**: Can be fully tested by running the native test executable and delivers confidence in the vendored C library build.

**Status**: Complete — `libsecp256k1Tests` commandLineTool builds and runs successfully (16 tests pass).

**Acceptance Scenarios**:

1. **Given** the native secp256k1 tests are built as a command-line tool, **When** I execute it, **Then** all native tests pass. ✅
2. **Given** the test runs on a new platform, **When** native tests complete, **Then** platform-specific issues are identified. ✅

---

### User Story 5 - Run MuSig2 Test Vectors (Priority: P2)

As a library maintainer, I want to validate MuSig2 multi-signature implementation against official BIP-0327 test vectors so that I can ensure the multi-signature protocol functions correctly.

**Why this priority**: MuSig2 is a critical multi-signature protocol for Bitcoin. BIP-0327 vectors are the authoritative source for correctness validation. High-value test coverage for an advanced feature.

**Independent Test**: Can be fully tested by running `tuist test MuSig2VectorTests` and delivers confidence that key aggregation, nonce handling, signing, and verification match the Bitcoin specification.

**Acceptance Scenarios**:

1. **Given** the MuSig2VectorTests target exists with BIP-0327 JSON vectors loaded, **When** I run the test target, **Then** all official test vectors pass with clear diagnostic output on any failure.
2. **Given** a vector with invalid key aggregation inputs, **When** aggregation is attempted, **Then** the test confirms rejection and reports expected vs actual values.
3. **Given** nonce generation and aggregation vectors, **When** the operations are performed, **Then** the computed values match the expected outputs.

---

### Edge Cases

- What happens when a test vector JSON file is malformed or missing? → **Fail fast** with clear error message indicating the missing/malformed file
- How does the system handle test vectors with unsupported features or flags? → **Filter at load time** based on vector flags, with documented skip reasons for each excluded category
- What happens when a native C test binary fails to build on a specific platform? → **Document blocker** in task output; skip native tests on that platform with warning; file issue for platform-specific investigation
- How are test failures reported when running in CI vs local development? → **Identical output format** — verbose diagnostics with hex dumps regardless of environment; CI captures stdout/stderr as-is

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Projects/Project.swift MUST define a `SchnorrVectorTests` unit test target for BIP-340 vectors ✅
- **FR-002**: Projects/Project.swift MUST define a `WycheproofTests` unit test target for ECDSA/ECDH edge cases ✅
- **FR-003**: Projects/Project.swift MUST define a `SecurityTests` unit test target for security vulnerability class regression
- **FR-004**: Native secp256k1 C tests MUST be runnable via Tuist commandLineTool target (primary) or dedicated Package.swift under Projects/ (fallback) ✅
- **FR-005**: All new test targets MUST support all platforms (iPhone, iPad, Mac, Apple Watch, Apple TV, Apple Vision)
- **FR-006**: Test vector JSON files MUST be loaded as bundle resources from `Projects/Resources/[TargetName]/` ✅
- **FR-007**: `subtree.yaml` MUST be updated to extract Wycheproof JSON files from `Vendor/secp256k1/src/wycheproof/` to `Projects/Resources/WycheproofTests/` ✅
- **FR-008**: Test failures MUST provide verbose diagnostic output including hex dumps and field-level breakdowns ✅
- **FR-009**: A shared `TestVectorAssertions.swift` utility MUST be located in `Projects/Sources/TestShared/` and included in each test target's sources, providing custom assertion helpers for cryptographic comparisons ✅
- **FR-010**: Each test target MUST have corresponding xcconfig files in `Projects/Resources/[TargetName]/` ✅
- **FR-011**: Test vector loaders MUST filter unsupported vectors at load time based on feature flags, with documented skip reasons for each excluded category ✅
- **FR-012**: Projects/Project.swift MUST define a `MuSig2VectorTests` unit test target for BIP-0327 MuSig2 vectors
- **FR-013**: BIP-0327 test vector JSON files MUST be downloaded to `Projects/Resources/MuSig2VectorTests/`

### Key Entities

- **Test Target**: A Tuist-defined unit test bundle with sources, resources, and platform destinations
- **Test Vector**: A JSON-encoded test case with inputs, expected outputs, and validity flags
- **Test Vector Assertion**: A custom XCTest assertion helper that provides verbose cryptographic diagnostics
- **Native Test Executable**: A command-line tool that runs the vendored C library's test suite

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All five test targets (SchnorrVectorTests, WycheproofTests, SecurityTests, NativeSecp256k1Tests, MuSig2VectorTests) are defined in Projects/Project.swift and generate successfully via `tuist generate`
- **SC-002**: BIP-340 test vectors achieve 100% pass rate when run via `tuist test SchnorrVectorTests` ✅
- **SC-003**: Wycheproof vectors achieve 100% pass rate for applicable ECDH and ECDSA Bitcoin tests ✅
- **SC-004**: Security test coverage validates all documented vulnerability classes (point validation, scalar validation, signature malleability, zero signatures, DER encoding, nonce security, invalid curve attacks)
- **SC-005**: Native secp256k1 tests pass on all supported platforms ✅
- **SC-006**: Test failure output provides sufficient diagnostic detail to identify the failing vector, expected value, and actual value without additional debugging ✅
- **SC-007**: Test targets run successfully on all platform destinations defined in Projects/Project.swift
- **SC-008**: Each test target completes execution within 60 seconds on CI runners
- **SC-009**: BIP-0327 MuSig2 test vectors achieve 100% pass rate for key aggregation, nonce handling, signing, and verification tests

## Assumptions

- BIP-340 test vectors will be converted from CSV to JSON format and stored in `Projects/Resources/SchnorrVectorTests/`
- Wycheproof JSON files exist in `Vendor/secp256k1/src/wycheproof/` and will be extracted via subtree.yaml
- CVE research completed in research.md (10+ CVEs identified from Wycheproof test data including twisted curve attack, signature malleability, zero signatures, BER encoding)
- Native C test compilation requirements (VERIFY flag, header paths) are compatible with Tuist's C settings
