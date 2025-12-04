# Phase 1: Testing Foundation

**Goal**: Establish robust, exhaustive testing infrastructure for cryptographic correctness  
**Status**: 🔜 Planned  
**Last Updated**: 2025-12-03  
**Depends On**: Phase 0 (SPM Plugin)  
**Blocks**: Phase 2 (CI), Phase 4 (new primitives)

---

## Features

### Test Architecture under Projects/

**Purpose & User Value**:  
Architect a robust and exhaustive testing structure under `Projects/` with specific test targets in `Projects/Project.swift`. This provides a dedicated space for integration tests, test vector validation, and platform-specific testing separate from the main package tests.

**Success Metrics**:
- New test targets added to `Projects/Project.swift`
- Clear separation between unit tests (package) and integration tests (Projects/)
- Test targets run on all supported platforms via Tuist

**Dependencies**:
- Phase 0 (SPM Plugin) for potential shared test utilities

**Notes**:
- Extends existing `P256KTests` and `libsecp256k1Tests` targets
- Consider separate targets for: Schnorr vectors, Wycheproof, CVE tests, native secp256k1 tests

---

### BIP-340 Schnorr Test Vectors

**Purpose & User Value**:  
Implement BIP-340 official test vectors under `Projects/` to validate Schnorr signature implementation correctness. Vectors imported as JSON file for maintainability and upstream sync.

**Success Metrics**:
- 100% of BIP-340 official test vectors pass
- Vectors loaded from JSON (not hardcoded)
- Test failures provide clear diagnostic output (expected vs actual)
- Covers: signing, verification, batch verification, edge cases

**Dependencies**:
- Test architecture (above)

**Notes**:
- JSON source: https://github.com/bitcoin/bips/blob/master/bip-0340/test-vectors.csv (convert to JSON)
- Include negative test cases (invalid signatures, wrong public keys)

---

### Wycheproof Test Vectors

**Purpose & User Value**:  
Implement Google Wycheproof test vectors from vendored `Vendor/secp256k1/src/wycheproof/` to validate ECDSA and ECDH implementations against known edge cases and attack vectors.

**Success Metrics**:
- 100% of applicable Wycheproof vectors pass
- ECDH vectors (`ecdh_secp256k1_test.json`) fully covered
- ECDSA Bitcoin vectors (`ecdsa_secp256k1_sha256_bitcoin_test.json`) fully covered
- Edge cases (low-order points, boundary values) explicitly tested

**Dependencies**:
- Test architecture (above)

**Notes**:
- Vectors already vendored at `Vendor/secp256k1/src/wycheproof/`
- Parse JSON directly; use existing `.h` files as reference

---

### secp256k1 CVE Tests

**Purpose & User Value**:  
Research and implement tests for known secp256k1-related CVEs to ensure the library is not vulnerable to historical attacks. Includes twisted curve attack on ECDH.

**Success Metrics**:
- Enumerated list of relevant CVEs documented
- Test case for each applicable CVE
- Twisted curve ECDH attack explicitly tested and rejected
- Clear documentation of what each test validates

**Dependencies**:
- Test architecture (above)

**Notes**:
- First task: "Research and enumerate relevant secp256k1 CVEs"
- Known: twisted curve attack on ECDH (invalid curve points)
- Check libsecp256k1 changelog for security fixes

---

### Native secp256k1 and secp256k1-zkp Tests

**Purpose & User Value**:  
Run the native C test suites from libsecp256k1 (under `Projects/`) and libsecp256k1-zkp (via `Package.swift`) to ensure the vendored libraries function correctly on all platforms.

**Success Metrics**:
- Native secp256k1 tests pass on all platforms
- Native secp256k1-zkp tests pass on all platforms
- Tests integrated into CI pipeline
- Clear mapping between native test failures and Swift wrapper issues

**Dependencies**:
- Test architecture (above)

**Notes**:
- secp256k1 tests: `Vendor/secp256k1/src/tests.c`
- Consider running `tests_exhaustive.c` on schedule (slow but thorough)
- zkp tests via existing `libsecp256k1zkpTests` target

---

## Phase Dependencies & Sequencing

```
Test Architecture ──► BIP-340 Vectors ──► Wycheproof Vectors
       │                                         │
       └──► CVE Research ──► CVE Tests ◄─────────┘
       │
       └──► Native secp256k1 Tests
       └──► Native secp256k1-zkp Tests
```

1. **Test Architecture** — first (unblocks all others)
2. **BIP-340 Vectors** and **Native Tests** — can run in parallel
3. **Wycheproof Vectors** — after architecture
4. **CVE Research** — can start early (research task)
5. **CVE Tests** — after research complete

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| BIP-340 vector pass rate | 100% |
| Wycheproof vector pass rate | 100% |
| CVEs enumerated and tested | All known |
| Native test pass rate | 100% |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Test vector format changes upstream | Tests break silently | Pin to specific upstream versions; automate sync checks |
| CVE research incomplete | Unknown vulnerabilities | Cross-reference multiple sources (NVD, libsecp256k1 issues, Bitcoin Core) |
| Native tests platform-specific failures | False negatives on some platforms | Investigate platform differences; document known issues |
