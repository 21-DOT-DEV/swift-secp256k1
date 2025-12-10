# Tasks: SPM Pre-Build Plugin for Shared Code

**Input**: Design documents from `/specs/001-spm-shared-code-plugin/`  
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓

**Tests**: Full TDD — test tasks precede each implementation task  
**Organization**: Tasks grouped by user story for independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- All paths are absolute from repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure and prepare Package.swift for plugin

- [x] T001 [P] Create plugin directory structure at `Plugins/SharedSourcesPlugin/`
- [x] T002 [P] Create plugin executable directory at `Plugins/SharedSourcesCopier/`
- [x] T003 [P] Create shared sources directory at `Sources/Shared/`
- [x] T004 [P] Create test directory at `Tests/SharedSourcesPluginTests/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Migrate files from ZKP to Shared and remove existing symlinks

**⚠️ CRITICAL**: Plugin cannot function until files are migrated

- [x] T005 Move 20 shared Swift files from `Sources/ZKP/` to `Sources/Shared/` using `git mv`
- [x] T006 Remove 20 file symlinks from `Sources/P256K/` (Asymmetric.swift, Combine.swift, etc.)
- [x] T007 Update `Package.swift` with plugin target, executable target, and plugin dependencies on P256K/ZKP targets

**Checkpoint**: Repository structure ready — plugin implementation can begin

---

## Phase 3: User Story 1 - Build Shared Code Across Targets (Priority: P1) 🎯 MVP

**Goal**: Shared Swift source files compile into both P256K and ZKP targets from `Sources/Shared/`

**Independent Test**: Run `swift build` and verify both targets compile with shared code symbols available

### ~~Tests for User Story 1~~ (REMOVED - Simplified Approach)

> **REVISION 2025-12-08**: SPM prebuild plugins cannot use executables from same package.
> Switched to system `rsync` command. Custom executable and tests removed.
> Conflict detection deferred to Swift compiler (duplicate symbol errors).

- [x] ~~T008~~ REMOVED - Using system rsync, no custom code to test
- [x] ~~T009~~ REMOVED - Using system rsync, no custom code to test
- [x] ~~T010~~ REMOVED - Compiler catches conflicts via duplicate symbol errors
- [x] ~~T011~~ REMOVED - Integration verified via `swift build` directly

### Implementation for User Story 1 (Simplified)

- [x] T012 [US1] ~~Implement SharedSourcesCopier~~ → Rewrite Plugin.swift to use `rsync` via `/usr/bin/env`
- [x] ~~T013~~ REMOVED - Conflict detection deferred to compiler
- [x] T014 [US1] Implement SharedSourcesPlugin with `prebuildCommand` using rsync in `Plugins/SharedSourcesPlugin/Plugin.swift`
- [x] ~~T015~~ REMOVED - Using rsync, no custom error handling needed

**Checkpoint**: ✅ `swift build` compiles both P256K and ZKP targets with shared code

---

## Phase 4: User Story 2 - Windows Build Compatibility (Priority: P3 - DEFERRED)

**Goal**: ~~Shared code mechanism works without filesystem symlinks on Windows~~ DEFERRED

**Status**: Windows support deferred. Placeholder `#if os(Windows)` added to Plugin.swift.

> **Note**: The simplified rsync approach works on macOS and Linux. Windows implementation
> will require a separate solution (robocopy/xcopy) when Windows CI is available.

### Implementation for User Story 2 (Deferred)

- [ ] T016 [US2] DEFERRED - Implement Windows file copy using robocopy or xcopy
- [ ] T017 [US2] DEFERRED - Add Windows CI job to verify build
- [x] T018 [US2] Added `#if os(Windows)` placeholder in Plugin.swift
- [x] T019 [US2] Verified no symlinks in `Sources/` (symlinks removed in Phase 2)

**Checkpoint**: macOS/Linux builds work; Windows placeholder in place

---

## Phase 5: User Story 3 - Clear Code Organization (Priority: P2)

**Goal**: Developers immediately understand which code is shared vs. target-specific

**Independent Test**: Examine `Sources/` directory structure; `Shared/` contains shared code, `P256K/`/`ZKP/` contain target-specific only

### Verification for User Story 3

- [x] T020 [US3] Verified 20 shared files exist in `Sources/Shared/`
- [x] T021 [US3] Verified `Sources/P256K/` contains only `ASN1/` and `swift-crypto/`

### Implementation for User Story 3

- [x] T022 [US3] Added `Sources/Shared/README.md` explaining shared code purpose and promotion workflow
- [x] T023 [US3] Confirmed `Sources/P256K/` structure (no shared code, only target-specific subdirectories)

**Checkpoint**: Directory structure clearly communicates shared vs. target-specific code

---

## Phase 6: User Story 4 - Promote Code to Shared (Priority: P2)

**Goal**: Promote ZKP-only files to shared using simple `git mv`

**Independent Test**: Move a test file from `Sources/ZKP/` to `Sources/Shared/`; verify both targets compile

### Verification for User Story 4

- [x] T024 [US4] Verified promotion workflow (20 files already moved from ZKP to Shared in Phase 2)

### Implementation for User Story 4

- [x] T025 [US4] Updated `quickstart.md` for accuracy (rsync, 20 files, Windows deferred, compiler conflicts)
- [x] T026 [US4] Promotion workflow documented in `Sources/Shared/README.md` and `quickstart.md`

**Checkpoint**: Promotion workflow documented and tested

---

## Phase 7: User Story 5 - Tuist/Projects Compatibility (Priority: P3)

**Goal**: Shared code plugin works with Tuist configuration in `Projects/`

**Independent Test**: Run `tuist generate` in `Projects/`; Xcode project includes shared code in P256K target

### Verification for User Story 5

- [x] T027 [US5] Verified `Projects/` has only 3 directory symlinks (Shared/, P256KTests/, libsecp256k1Tests/)
- [x] T028 [US5] Verified all file symlinks consolidated into directory symlinks

### Implementation for User Story 5

- [x] T029 [US5] Removed 20+ file symlinks from `Projects/Sources/`
- [x] T030 [US5] Created 3 directory symlinks: `Shared/`, `P256KTests/`, `libsecp256k1Tests/`
- [x] T031 [US5] Updated `Projects/Project.swift` to include `Sources/Shared/**` in P256K target sources
- [x] T032 [US5] Verified `tuist generate` succeeds (43 shared files accessible via symlinks)

**Checkpoint**: Tuist/XCFramework builds work with shared code

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [x] T033 [P] ~~Update main README.md~~ → All docs consolidated in `Sources/Shared/README.md`
- [x] T034 [P] ~~Update CONTRIBUTING.md~~ → Promotion workflow documented in `Sources/Shared/README.md`
- [x] T035 Run full CI pipeline on all platforms (macOS: ✅ 45 tests pass, Linux: deferred to CI, Windows: deferred)
- [x] T036 Run `swift build` clean build and measure build time impact (~12s clean build, acceptable)
- [x] T037 Validate quickstart.md instructions end-to-end (43 files, 3 symlinks verified)
- [x] T038 Code review and cleanup (plugin code reviewed, documentation updated)

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup) ──────────────────────┐
                                      ▼
Phase 2 (Foundational) ───────────────┤ BLOCKS all user stories
                                      ▼
┌─────────────────────────────────────┴─────────────────────────────────────┐
│                           User Stories (can run in priority order)        │
│                                                                           │
│  Phase 3 (US1: Build) ─► Phase 4 (US2: Windows) ─► Phase 5 (US3: Org)    │
│                                                          │                │
│                                    Phase 6 (US4: Promote) ◄──────────────┤
│                                                          │                │
│                                    Phase 7 (US5: Tuist) ◄────────────────┤
└───────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                            Phase 8 (Polish)
```

### User Story Dependencies

| Story | Depends On | Can Start After |
|-------|------------|-----------------|
| US1 (Build) | Foundational | Phase 2 complete |
| US2 (Windows) | US1 | Phase 3 complete |
| US3 (Organization) | Foundational | Phase 2 complete (parallel with US1) |
| US4 (Promotion) | US1 | Phase 3 complete |
| US5 (Tuist) | US1 | Phase 3 complete |

### Within Each User Story

1. Tests MUST be written FIRST and FAIL before implementation
2. Implementation tasks in sequence
3. Checkpoint verification before moving to next story

### Parallel Opportunities

**Phase 1 (Setup)**:
- T001, T002, T003, T004 can ALL run in parallel (different directories, all marked [P])

**Phase 3 (US1 Tests)**:
- T008, T009, T010 can run in parallel (different test files)

**Phase 8 (Polish)**:
- T033, T034 can run in parallel (different files)

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all US1 tests in parallel (TDD: write first, verify they fail):
Task T008: "Unit test for recursive file enumeration"
Task T009: "Unit test for file copying with structure preservation"
Task T010: "Unit test for conflict detection"

# Then implement sequentially:
Task T012: "Implement SharedSourcesCopier executable"
Task T013: "Implement conflict detection logic"
Task T014: "Implement SharedSourcesPlugin"
Task T015: "Add clear error messages"
```

---

## Implementation Strategy

### Atomic Delivery (All Stories)

Per planning decision, all changes are delivered atomically in one PR:

1. **Phase 1**: Setup directories
2. **Phase 2**: Migrate files, remove symlinks, update Package.swift
3. **Phase 3**: Implement plugin (US1 - core functionality)
4. **Phase 4**: Verify Windows compatibility (US2)
5. **Phase 5**: Verify organization clarity (US3)
6. **Phase 6**: Document promotion workflow (US4)
7. **Phase 7**: Update Tuist configuration (US5)
8. **Phase 8**: Polish and validate

### Validation Checkpoints

| Checkpoint | Validation |
|------------|------------|
| After Phase 2 | `git status` shows no symlinks in Sources/ |
| After Phase 3 | `swift build` compiles both targets (43 files flattened) |
| After Phase 4 | CI passes on macOS/Linux (Windows deferred) |
| After Phase 7 | `tuist generate && xcodebuild` succeeds; only 3 dir symlinks in Projects/ |
| After Phase 8 | Full CI green, build time < 5% impact |

---

## Summary

| Metric | Value |
|--------|-------|
| **Total Tasks** | 38 |
| **Setup Tasks** | 4 |
| **Foundational Tasks** | 3 |
| **US1 Tasks** | 8 |
| **US2 Tasks** | 4 |
| **US3 Tasks** | 4 |
| **US4 Tasks** | 3 |
| **US5 Tasks** | 6 |
| **Polish Tasks** | 6 |
| **Parallel Opportunities** | 16 tasks marked [P] |

---

## Notes

- All paths are relative to repository root `/Users/csjones/Developer/swift-secp256k1/`
- TDD: Write tests first, verify they fail, then implement
- Commit after each logical task group
- Stop at any checkpoint to validate independently
- Atomic PR: all changes in one branch, one review
