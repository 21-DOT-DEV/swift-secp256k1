# Tasks: Swift Version Compatibility Table

**Input**: Design documents from `/specs/002-swift-version-compat/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, workflow-schema.md ✅, quickstart.md ✅

**Tests**: Not included (builds serve as tests, manual verification sufficient)

**Organization**: Tasks ordered by **execution dependency**, not priority. US3 (P3) runs first because it generates data that US1 (P1) needs. Priority indicates user value; execution order reflects technical dependencies:
- **US3 (P3)**: Bootstrap → generates compatibility data (must run first)
- **US1 (P1)**: README table → requires US3 output (highest user value, but depends on US3)
- **US2 (P2)**: CI workflow → independent, but logically follows documentation

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Verify prerequisites and prepare environment

- [x] T001 Verify swiftly is installed and initialized
- [x] T002 Verify Swift toolchains 5.1-6.0 are installed via swiftly
- [x] T003 Verify bootstrap script is executable at scripts/swift-version-compat.sh

**Checkpoint**: Environment ready for bootstrap execution

---

## Phase 2: User Story 3 - Bootstrap Historical Data (Priority: P3) 🚀 FIRST

**Goal**: Run one-time local script to determine minimum Swift version for all historical releases

**Independent Test**: Script outputs CSV with release-to-Swift-version mappings; terminal shows grouped ranges

**Note**: US3 executes first because US1 depends on its output data

### Implementation for User Story 3

- [x] T004 [US3] Run bootstrap script: ./scripts/swift-version-compat.sh
- [x] T005 [US3] Verify swift-compat-results.csv contains all stable releases
- [x] T006 [US3] Review grouped ranges output for accuracy (if any release shows "NONE", investigate—likely requires Swift > 6.0 or has build issues unrelated to Swift version)
- [x] T007 [US3] Save grouped ranges output for README integration

**Checkpoint**: Historical compatibility data collected, ready to populate README

---

## Phase 3: User Story 1 - View Swift Compatibility (Priority: P1) 🎯 MVP

**Goal**: Add Swift versions table to README.md matching swift-crypto format

**Independent Test**: View README.md, scroll to Swift versions section, verify table displays grouped ranges

### Implementation for User Story 1

- [x] T008 [US1] Locate Installation section in README.md
- [x] T009 [US1] Add introductory text matching swift-crypto pattern in README.md
- [x] T010 [US1] Add markdown table with grouped ranges from bootstrap output in README.md
- [x] T011 [US1] Verify table formatting matches swift-crypto style (backtick ranges, pipe separators)
- [ ] T012 [US1] Commit README changes with descriptive message

**Checkpoint**: README now displays Swift compatibility table - core user value delivered

---

## Phase 4: User Story 2 - Automated CI Workflow (Priority: P2) ⏭️ SKIPPED

**Status**: SKIPPED - Not needed per industry best practices

**Rationale**:
- swift-tools-version is set manually by maintainer when releasing
- Manual README update takes ~10 seconds vs hours of CI maintenance
- swift-crypto and other major packages use manual updates
- Automated PRs create review overhead for minimal benefit

**Alternative**: Update README table manually when bumping swift-tools-version

---

## Phase 5: Cleanup & Polish

**Purpose**: Remove temporary files and finalize feature

- [x] T024 Delete bootstrap script: rm scripts/swift-version-compat.sh
- [x] T025 Delete results CSV: rm swift-compat-results.csv
- [x] T026 Verify scripts/ directory is clean (or remove if empty)
- [ ] T027 Commit cleanup with message "chore: remove bootstrap script after initial data collection"
- [x] T028 Update spec.md status from Draft to Complete
- [ ] T029 Final review of all changes before PR/merge

**Checkpoint**: Feature complete, temporary files removed, ready for merge

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ✅
    │
    ▼
Phase 2 (US3: Bootstrap) ✅ ──► Data required for Phase 3
    │
    ▼
Phase 3 (US1: README) ✅ ──► Core value delivered
    │
    ▼
Phase 4 (US2: CI Workflow) ⏭️ SKIPPED ──► Not needed per industry best practices
    │
    ▼
Phase 5 (Cleanup) ✅ ──► Feature finalized
```

### User Story Dependencies

- **US3 (Bootstrap)**: No dependencies - runs first to generate data
- **US1 (README)**: Depends on US3 output (grouped ranges data)
- **US2 (CI Workflow)**: Independent of US1/US3, but logically follows

### Parallel Opportunities

Limited parallelism due to data dependencies:
- T001, T002, T003 can run in parallel (setup verification)
- T013-T023 (US2) could theoretically start after T003, but better to have README done first for reference

---

## Implementation Strategy

### Recommended Order

1. **Setup (Phase 1)**: ~5 minutes
2. **Bootstrap (Phase 2)**: ~30-60 minutes (script runtime)
3. **README (Phase 3)**: ~10 minutes
4. **CI Workflow (Phase 4)**: ~30 minutes
5. **Cleanup (Phase 5)**: ~5 minutes

**Total estimated time**: 1.5-2 hours

### MVP Scope

**Minimum viable delivery**: Phases 1-3 (Setup + Bootstrap + README)
- Delivers core user value (visibility into Swift compatibility)
- CI automation (Phase 4) can follow separately

---

## Task Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | T001-T003 | Setup verification |
| 2 | T004-T007 | Bootstrap (US3) |
| 3 | T008-T012 | README table (US1) |
| 4 | T013-T023 | CI workflow (US2) |
| 5 | T024-T029 | Cleanup |

**Total**: 29 tasks
- US1: 5 tasks
- US2: 11 tasks
- US3: 4 tasks
- Setup: 3 tasks
- Cleanup: 6 tasks
