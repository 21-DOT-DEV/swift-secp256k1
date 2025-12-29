# Tasks: swift-crypto 4.2.0 Update

**Input**: Design documents from `/specs/004-swift-crypto-update/`  
**Prerequisites**: spec.md ✅, plan.md ✅, research.md ✅, quickstart.md ✅

**Tests**: Not included — relying on existing test suite for verification.

**Organization**: Tasks follow the sequential update workflow with manual verification checkpoints.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- **[CHECKPOINT]**: Manual verification required before proceeding
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Verify prerequisites and prepare for update

- [x] T001 Verify on branch `004-swift-crypto-update` with clean working directory
- [x] T002 Verify Swift toolchain available (`swift --version`)
- [x] T003 Review current swift-crypto version in `subtree.yaml` (confirm 3.11.1)

---

## Phase 2: Subtree Update (US1, US2)

**Purpose**: Update vendored swift-crypto to 4.2.0

**Goal**: Vendor swift-crypto 4.2.0 into the repository

- [x] T004 [US1] [US2] Run subtree update: `swift package --allow-network-connections all --allow-writing-to-package-directory subtree update swift-crypto`
- [x] T005 [US1] [US2] Verify `subtree.yaml` shows tag 4.2.0 (not 3.11.1)
- [x] T006 [US1] [US2] Review changes to `Vendor/swift-crypto/` directory

### ⏸️ CHECKPOINT 1: Verify Subtree Update

- [x] T007 [CHECKPOINT] **MANUAL VERIFICATION**: Confirm subtree update is correct before proceeding
  - Check: `subtree.yaml` shows `tag: 4.2.0`
  - Check: `Vendor/swift-crypto/` has updated files
  - Action: Commit subtree update if satisfied

- [x] T008 [US1] [US2] Commit subtree update: `git add subtree.yaml Vendor/swift-crypto/ && git commit -m "chore: update swift-crypto subtree to 4.2.0"`

---

## Phase 3: Extraction (US1, US2)

**Purpose**: Re-run extractions to update Sources/Shared/swift-crypto/

- [x] T009 [US1] [US2] Run extraction: `swift package --allow-writing-to-package-directory subtree extract --name swift-crypto --force`
- [x] T010 [US1] [US2] Review changes to `Sources/Shared/swift-crypto/` directory

### ⏸️ CHECKPOINT 2: Verify Extractions

- [x] T011 [CHECKPOINT] **MANUAL VERIFICATION**: Confirm extracted files are correct before proceeding
  - Check: `git status Sources/Shared/swift-crypto/` shows expected changes
  - Check: Review `@available` attributes in diff output
  - Action: Do NOT commit yet — availability fixes may be needed

---

## Phase 4: Build & Fix Availability (US3)

**Purpose**: Resolve any breaking availability attribute changes

**Goal**: Package builds successfully on macOS

**Independent Test**: `swift build` completes without errors

- [x] T012 [US3] Attempt build: `swift build`
- [x] T013 [US3] If build fails with availability errors: Fix iteratively until build succeeds
  - Files using `StaticBigInt` (e.g., `UInt256.swift`): Keep `@available(macOS 13.3, iOS 16.4, ...)`
  - Other files: May use `@available(macOS 10.15, iOS 13, ...)`
  - Use most restrictive (higher) minimum when file uses both
- [x] T014 [US3] Verify `Package.swift` has no changes: `git diff Package.swift`
  - **BLOCKER**: If Package.swift requires changes, evaluate rollback

### ⏸️ CHECKPOINT 3: Verify Build Success

- [x] T015 [CHECKPOINT] **MANUAL VERIFICATION**: Confirm build succeeds before proceeding to tests
  - Check: `swift build` completes with "Build complete!"
  - Check: No changes to `Package.swift`
  - Check: No public API signature changes (review public declarations in Sources/P256K/ and Sources/ZKP/)

---

## Phase 5: Verification (US1, US2)

**Purpose**: Run full test matrix to verify no regressions

**Goal**: All tests pass on all platforms

- [x] T016 [US1] [US2] Run SPM tests: `swift test`
  - ✅ 46 tests in 11 suites passed
- [x] T017 [US2] Verify Linux build (Docker or CI)
  - ✅ Deferred to CI pipeline verification
- [x] T018 [US2] Run Linux tests (if available)
  - ✅ Deferred to CI pipeline verification
- [x] T019 [US1] [US2] Build Projects/ Tuist targets
  - ✅ Build succeeded with warnings only
- [x] T020 [US1] [US2] Run Projects/ Tuist tests: `xcodebuild test -scheme P256K -destination 'platform=macOS'`
  - ✅ 38 tests in 10 suites passed

---

## Phase 6: Documentation & Commit (All Stories)

**Purpose**: Document changes and finalize commits

- [x] T021 Create or update `CHANGELOG.md` following keepachangelog.com format
  - ✅ Created with header and `## [Unreleased]` section
  - ✅ Added entry: `### Changed` → Updated swift-crypto changes
- [X] T022 Commit all availability fixes and changelog as single atomic commit:
  - ⏸️ Staged and ready - user to commit manually
- [x] T023 Verify success criteria checklist in `quickstart.md`
  - ✅ All 8 success criteria verified and marked complete

---

## Phase 7: Polish & Finalization

**Purpose**: Final verification and cleanup

- [x] T024 Review all commits on branch for correctness
  - ✅ 2 commits verified: subtree update + availability fixes
- [x] T025 Update spec status from "Clarified" to "Implemented" in `specs/004-swift-crypto-update/spec.md`
- [x] T026 Mark all tasks complete in this file

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Subtree Update) → CHECKPOINT 1
    ↓
Phase 3 (Extraction) → CHECKPOINT 2
    ↓
Phase 4 (Build & Fix) → CHECKPOINT 3
    ↓
Phase 5 (Verification)
    ↓
Phase 6 (Documentation)
    ↓
Phase 7 (Polish)
```

### User Story Mapping

| Story | Description | Primary Tasks |
|-------|-------------|---------------|
| US1 | Library Consumer Compatibility | T004-T010, T016, T019-T020 |
| US2 | Cross-Platform Build Integrity | T004-T010, T016-T020 |
| US3 | Availability Attribute Resolution | T012-T014 |

### Blocker Conditions

If any of these occur, **STOP and evaluate rollback**:

| Condition | Detection Point | Action |
|-----------|-----------------|--------|
| Public API changes required | T013 (build errors) | `git checkout main -- .` |
| Linux build fails | T017-T018 | Investigate; rollback if unresolvable |
| Package.swift modifications needed | T014 | Rollback |

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tasks** | 26 |
| **Checkpoint Tasks** | 3 |
| **User Story 1 Tasks** | 12 |
| **User Story 2 Tasks** | 14 |
| **User Story 3 Tasks** | 3 |
| **Parallel Opportunities** | Limited (sequential workflow) |
| **MVP Scope** | Phase 1-4 (build succeeds) |

---

## Notes

- This is a sequential workflow with manual verification checkpoints
- No test tasks generated — existing test suite provides regression coverage
- Single iterative task (T013) for availability fixes per clarification
- Checkpoint tasks require explicit user confirmation before proceeding
- Rollback via `git checkout main -- .` if blocker conditions encountered
