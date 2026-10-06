# Phase 2: CI & Quality Gates

**Goal**: Establish continuous quality assurance with coverage, security scanning, fuzzing, and robust error testing  
**Horizon**: 🔵 Now (continuous enabler)  
**Status**: 🔜 Planned  
**Last Updated**: 2026-06-05  
**Depends On**: Phase 1 (Testing Foundation)  
**Blocks**: primitive phases (4–11) — safe to add new crypto code

**Progress (2026-06-05)**: Platform CI (`apple-builds`, `docker-builds`), benchmark CI (`benchmark-main`/`benchmark-pr`), and release automation (`docc-release`, `xcframework-release`, subtree sync) already exist — but **none of this phase's actual deliverables are started**: no Coveralls/codecov coverage, no CodeQL, no fuzz target, no `#expect(exitsWith:)` exit tests. A rich `SecurityTests` target already exists under `Projects/` (DER, InvalidCurve, PointValidation, ScalarValidation, SignatureMalleability, ZeroSignature, Nonce), partially covering this phase's security-testing intent.

---

## Features

### Code Coverage with Coveralls

**Purpose & User Value**:  
Integrate Coveralls for code coverage tracking via GitHub Actions, with tiered thresholds ensuring critical cryptographic paths maintain high coverage while allowing realistic overall targets.

**Success Metrics**:
- Coveralls integration working on all PRs
- Coverage badge displayed in README
- Tiered thresholds enforced:
  - Critical paths (signing, verification, key handling): ≥90%
  - Core APIs (public P256K/ZKP): ≥80%
  - Overall floor: ≥70%
- Coverage trends visible over time

**Dependencies**:
- Phase 1 test infrastructure (tests must exist to measure coverage)

**Notes**:
- GitHub Actions integration
- Consider excluding generated C binding code from coverage
- Critical path identification requires manual annotation or path-based rules

---

### CodeQL Security Scanning

**Purpose & User Value**:  
Implement CodeQL security scanning for Swift code to catch common vulnerabilities. Start with standard queries, then add custom queries for Bitcoin/crypto-specific patterns.

**Success Metrics**:
- CodeQL runs on every PR
- Zero high/critical findings in main branch
- Standard Swift security queries active
- (Follow-up) Custom queries for:
  - Secret logging detection (`print`, `NSLog`, `os_log` with key material)
  - Hardcoded test keys in non-test code
  - Potential nonce reuse patterns

**Dependencies**:
- None (can start immediately, but most value after Phase 1)

**Notes**:
- Phase 2a: Standard Swift security scanning
- Phase 2b (follow-up): Custom Bitcoin/crypto queries
- Document false positive handling process

---

### Fuzz Testing

**Purpose & User Value**:  
Implement fuzz testing for cryptographic functions to discover edge cases and potential crashes that unit tests miss. Critical for security-sensitive code.

**Success Metrics**:
- Fuzzing infrastructure established
- Key functions fuzzed: signature parsing, key parsing, encoding/decoding
- Scheduled CI runs (not every PR)
- Crash reproduction documented
- Zero unfixed crash-inducing inputs in main branch

**Dependencies**:
- Phase 1 test infrastructure

**Notes**:
- Start with Swift's built-in fuzzing (`-sanitize=fuzzer`)
- Research task: evaluate Swift native vs OSS-Fuzz for long-term
- Suggested approach: "Research fuzzing approaches; implement Swift native for MVP; evaluate OSS-Fuzz for long-term"
- Focus on input parsing (most likely crash source)

---

### Exit Tests

**Purpose & User Value**:  
Implement Swift Testing's `#expect(exitsWith:)` to test precondition failures, fatal errors, and crash behavior—ensuring invalid inputs fail safely without leaking secrets.

**Success Metrics**:
- Exit tests for all public API preconditions
- Verified: crash messages don't leak secret material
- Tested scenarios:
  - Invalid key data → clean failure
  - Out-of-range scalars → clean failure
  - Malformed signatures → clean failure
- Tests pass on all platforms

**Dependencies**:
- Phase 1 test infrastructure

**Notes**:
- Aligns with Constitution Principle III (secrets MUST NOT appear in crash reports)
- Requires Swift Testing framework (already in use)
- Consider testing secure cleanup on abnormal exit

---

## Phase Dependencies & Sequencing

```
CodeQL (standard) ──────────────────────────────►
                                                 │
Phase 1 Complete ──► Coveralls ──► Coverage Thresholds
                          │
                          └──► Fuzz Research ──► Fuzz Implementation
                          │
                          └──► Exit Tests
                                    │
                                    └──► CodeQL Custom Queries (follow-up)
```

1. **CodeQL (standard)** — can start immediately
2. **Coveralls** — after Phase 1 tests exist
3. **Fuzz Research** — can start during Coveralls setup
4. **Exit Tests** — after basic test infrastructure
5. **Fuzz Implementation** — after research
6. **CodeQL Custom Queries** — follow-up after standard queries stable

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Coverage (critical paths) | ≥90% |
| Coverage (core APIs) | ≥80% |
| Coverage (overall) | ≥70% |
| CodeQL high/critical findings | 0 |
| Fuzz-discovered crashes fixed | 100% |
| Exit test coverage | All public API preconditions |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Coverage thresholds too aggressive | Blocks legitimate PRs | Start with warning-only; adjust thresholds based on baseline |
| Fuzzing finds many issues | Delays Phase 3+ | Prioritize by severity; security issues block, others can be tracked |
| Exit tests platform-specific | Inconsistent behavior | Test on all platforms; document platform differences |
| CodeQL false positives | Alert fatigue | Document suppression process; review suppressions periodically |
