# Feature Specification: SPM Pre-Build Plugin for Shared Code

**Feature Branch**: `001-spm-shared-code-plugin`  
**Created**: 2025-12-08  
**Status**: In Progress  
**Input**: User description: "Create a Swift Package Manager plugin that allows shared code to be included in both P256K and ZKP targets without manual duplication"

## Clarifications

### Session 2025-12-08

- Q: What happens when a shared file has a naming conflict with a target-specific file? → A: Build error with clear message listing the conflict
- Q: What happens if a shared file imports a target-specific module? → A: Allow it; Swift compiler handles via existing `#if canImport` patterns
- Q: What is the minimum Swift/SPM version requirement? → A: Swift 5.9+ (stable `prebuildCommand` support)
- Q: Should `Sources/Shared/` support nested subdirectories? → A: Yes, preserve directory structure when copying
- Q: How should Tuist share code from `Sources/Shared/`? → A: Single directory symlink `Projects/Sources/Shared → ../../Sources/Shared` (Tuist is macOS-only)
- Q: How to handle existing 20 file symlinks in `Sources/P256K/` and `Projects/Sources/P256K/`? → A: Delete all; Tuist will reference the new directory symlink

### Revision 2025-12-08: Simplified Plugin Approach

- **Issue**: SPM prebuild plugins cannot use executables built from the same package (Xcode error)
- **Solution**: Use system `rsync` command instead of custom SharedSourcesCopier executable
- **Impact**: Removed custom executable, tests, and conflict detection (compiler catches duplicates)
- **Windows**: Deferred — placeholder `#if os(Windows)` added for future implementation

### Revision 2025-12-09: Flattening and swift-crypto Consolidation

- **Issue**: SPM doesn't recursively include subdirectories from plugin output directory
- **Solution**: Plugin uses `find + cp` to flatten all `.swift` files into a single output directory
- **Rationale**: Flattening enables simpler SPM integration; 43 files (20 core + 23 swift-crypto) compile correctly
- **swift-crypto**: Consolidated extraction from 3 locations → `Sources/Shared/swift-crypto/` only (see `subtree.yaml`)
- **Symlinks**: Reduced from 20+ file symlinks → 3 directory symlinks in `Projects/` for Tuist compatibility

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build Shared Code Across Targets (Priority: P1)

As a library maintainer, I want shared Swift source files to compile into both P256K and ZKP targets from a single source location, so that I maintain one canonical implementation without duplication or symlinks.

**Why this priority**: Core value proposition — eliminates the fundamental problem of code duplication and symlink brittleness.

**Independent Test**: Can be fully tested by running `swift build` and verifying both P256K and ZKP targets compile successfully with shared code included.

**Acceptance Scenarios**:

1. **Given** a Swift file exists in `Sources/Shared/`, **When** I run `swift build`, **Then** both P256K and ZKP targets compile successfully with that file's symbols available.
2. **Given** I modify a file in `Sources/Shared/`, **When** I rebuild, **Then** both targets reflect the change without manual intervention.
3. **Given** the project is cloned fresh on a new machine, **When** I run `swift build`, **Then** the build succeeds without any symlink setup steps.

---

### User Story 2 - Windows Build Compatibility (Priority: P1)

As a contributor building on Windows, I want the shared code mechanism to work without filesystem symlinks, so that I can build the library without special permissions or developer mode.

**Why this priority**: Symlinks require elevated privileges on Windows, blocking cross-platform contributions.

**Independent Test**: Can be tested by building on Windows (or simulating via CI) and confirming no symlink-related errors occur.

**Acceptance Scenarios**:

1. **Given** the project is checked out on Windows, **When** I run `swift build`, **Then** the build succeeds without symlink errors.
2. **Given** Git is configured without symlink support, **When** I clone the repository, **Then** all source files are regular files (no symlinks in `Sources/Shared/`).

---

### User Story 3 - Clear Code Organization (Priority: P2)

As a developer exploring the codebase, I want to immediately understand which code is shared between targets vs. target-specific, so that I can navigate and modify the correct files.

**Why this priority**: Improves maintainability and onboarding; current symlinks obscure the sharing relationship.

**Independent Test**: Can be tested by examining directory structure and verifying shared vs. target-specific code is clearly separated.

**Acceptance Scenarios**:

1. **Given** I open the `Sources/` directory, **When** I look at the structure, **Then** I see a clear `Shared/` directory containing all shared code.
2. **Given** I want to know if a file is shared, **When** I check its location, **Then** `Sources/Shared/` means shared; `Sources/P256K/` or `Sources/ZKP/` means target-specific.

---

### User Story 4 - Promote Code to Shared (Priority: P2)

As a developer, I want to promote a ZKP-only file to shared status using a simple file move, so that the promotion workflow is explicit and version-control friendly.

**Why this priority**: Supports the "ZKP-first development → promote to shared" workflow described in the roadmap.

**Independent Test**: Can be tested by moving a file and verifying both targets compile.

**Acceptance Scenarios**:

1. **Given** a file exists only in `Sources/ZKP/`, **When** I move it to `Sources/Shared/` via `git mv`, **Then** both P256K and ZKP targets can use its symbols after rebuild.
2. **Given** I promote a file to shared, **When** I review the git diff, **Then** it shows a clean file move (no duplication, no symlinks).

---

### User Story 5 - Tuist/Projects Compatibility (Priority: P3)

As a maintainer, I want the shared code plugin to work with the existing Tuist configuration in `Projects/`, so that XCFramework builds and test targets continue to function.

**Why this priority**: Required for full CI/CD pipeline and release builds, but lower priority than core SPM functionality.

**Independent Test**: Can be tested by running Tuist generate and building via Xcode.

**Acceptance Scenarios**:

1. **Given** a directory symlink exists at `Projects/Sources/Shared/` pointing to `Sources/Shared/`, **When** I run `tuist generate` in `Projects/`, **Then** the generated Xcode project includes shared code in the P256K target.
2. **Given** I build an XCFramework, **When** the build completes, **Then** shared code is compiled into the framework (not exposed as separate module).
3. **Given** the migration is complete, **When** I list `Projects/Sources/`, **Then** only 3 directory symlinks exist (`Shared/`, `P256KTests/`, `libsecp256k1Tests/`).

---

### Edge Cases

- **Naming conflict**: Build fails with clear error listing conflicts (per FR-006)
- **Empty `Sources/Shared/`**: Plugin proceeds with no files copied; build continues normally
- **Shared file imports target module**: Allowed; Swift compiler handles via `#if canImport` patterns
- **Build errors in shared files**: Reported in context of the target being built (errors appear twice, once per target)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Plugin MUST recursively copy files and subdirectories from `Sources/Shared/` to each target's build directory, preserving directory structure.
- **FR-002**: Plugin MUST integrate with SPM's `BuildToolPlugin` protocol using `prebuildCommand`.
- **FR-003**: Copied files MUST reside in SPM's managed plugin output directory, not polluting the source tree.
- **FR-004**: Plugin MUST NOT require any symlinks in the repository.
- **FR-005**: Plugin MUST support incremental builds (SPM's plugin output caching handles this automatically; no custom change detection required).
- **FR-006**: ~~Build MUST fail with a clear error message listing any filename conflicts~~ → Conflicts are caught by Swift compiler with duplicate symbol errors (simplified approach).
- **FR-007**: Plugin MUST work on macOS and Linux; Windows support is deferred (placeholder added).
- **FR-008**: Plugin MUST be scoped to this repository only (not published as a separate package).
- **FR-009**: Plugin MUST require Swift 5.9 or later.
- **FR-010**: Migration MUST delete all 20 file symlinks from `Sources/P256K/` and `Projects/Sources/P256K/`.
- **FR-011**: Migration MUST create a directory symlink `Projects/Sources/Shared/` pointing to `../../Sources/Shared`.
- **FR-012**: Tuist `Project.swift` MUST be updated to include `Sources/Shared/**` in the P256K target sources.

### Key Entities

- **Shared Source Directory**: `Sources/Shared/` — contains all Swift files shared between P256K and ZKP targets.
- **Plugin Output Directory**: SPM-managed directory (`.build/plugins/outputs/...`) where copied files are placed for compilation.
- **Target Configuration**: Each target (P256K, ZKP) declares dependency on the plugin to receive shared sources.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 20 currently-symlinked files compile successfully in both targets from `Sources/Shared/`.
- **SC-002**: Repository contains zero file symlinks in `Sources/` after migration.
- **SC-002a**: `Projects/` contains only 3 directory symlinks after migration (`Shared/`, `P256KTests/`, `libsecp256k1Tests/`), consolidated from 20+ file symlinks.
- **SC-003**: Build succeeds on Windows without symlink-related errors.
- **SC-004**: Build time impact is less than 5% compared to current symlink approach.
- **SC-005**: New contributor can build the project on first clone without additional setup steps.
- **SC-006**: XCFramework builds succeed with shared code included (not as separate module).

## Assumptions

- SPM's `BuildToolPlugin` with `prebuildCommand` provides sufficient capability for file copying before compilation.
- The existing 20 symlinked files have no target-specific conditional compilation that would prevent sharing.
- Tuist can follow the directory symlink at `Projects/Sources/Shared/` to include shared sources.
- Swift 5.9 is the minimum version for stable `prebuildCommand` support; the project currently uses Swift 6.0+ (per constitution), which exceeds this requirement.

## Out of Scope

- Automatic detection of which files should be shared (promotion is manual).
- Publishing the plugin as a standalone package for other projects.
- Conditional compilation within shared files is supported (existing `#if canImport` patterns for libsecp256k1 vs libsecp256k1_zkp continue to work).
