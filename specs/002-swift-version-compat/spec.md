# Feature Specification: Swift Version Compatibility Table

**Feature Branch**: `002-swift-version-compat`  
**Created**: 2025-12-12  
**Status**: Complete  
**Input**: User description: "Swift version compatibility table for README with GitHub Actions CI workflow"

## Clarifications

### Session 2025-12-13

- Q: How should the workflow handle new Swift versions (e.g., 6.1)? → A: Manual update to workflow file
- Q: What authentication method for CI to create PRs? → A: Built-in GITHUB_TOKEN
- Q: Where should the Swift versions table appear in README? → A: After the Installation section
- Q: Should early releases (0.0.x) be included in the table? → A: Yes, all 48 stable releases from 0.0.1 onwards

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Swift Compatibility (Priority: P1)

A developer evaluating swift-secp256k1 visits the README to determine if the package supports their project's Swift version before adding it as a dependency.

**Why this priority**: This is the core value—developers need to know Swift compatibility before adopting the package. Without this information, developers may encounter build failures or avoid the package entirely.

**Independent Test**: Can be fully tested by viewing README.md and verifying the Swift versions table displays accurate, grouped version ranges with minimum Swift requirements.

**Acceptance Scenarios**:

1. **Given** a developer viewing README.md, **When** they scroll to the "Swift versions" section, **Then** they see a table showing swift-secp256k1 version ranges mapped to minimum Swift versions
2. **Given** a developer using Swift 5.9, **When** they consult the table, **Then** they can identify which swift-secp256k1 releases are compatible with their toolchain
3. **Given** a developer viewing the table, **When** they read the version ranges, **Then** the format matches swift-crypto's established pattern (e.g., `0.15.0 ..< 0.19.0`)

---

### User Story 2 - Automated Compatibility Testing on Release (Priority: P2)

When a maintainer tags a new release, the CI system automatically tests the release against supported Swift versions and proposes an update to the compatibility table.

**Why this priority**: Automation ensures the table stays current without manual effort, reducing maintenance burden and preventing stale documentation.

**Independent Test**: Can be fully tested by tagging a test release and verifying the CI workflow runs, tests against the Swift version matrix, and opens a PR with any table updates.

**Acceptance Scenarios**:

1. **Given** a new release is tagged, **When** the CI workflow triggers, **Then** the release is tested against Swift 5.7, 5.8, 5.9, 5.10, and 6.0
2. **Given** a CI workflow completes successfully, **When** a compatibility change is detected, **Then** a pull request is automatically opened with the updated table
3. **Given** a CI workflow completes, **When** the release is compatible with all tested Swift versions, **Then** no PR is opened (no change needed)

---

### User Story 3 - Bootstrap Historical Compatibility Data (Priority: P3)

A maintainer runs a one-time local script to determine minimum Swift version requirements for all existing stable releases, populating the initial compatibility table.

**Why this priority**: Required to establish the baseline table, but only runs once. Lower priority because it's a one-time bootstrapping task.

**Independent Test**: Can be fully tested by running the bootstrap script locally and verifying it outputs a CSV with release-to-Swift-version mappings for all stable releases.

**Acceptance Scenarios**:

1. **Given** the bootstrap script is executed, **When** it completes, **Then** a results file contains minimum Swift version for each tested release
2. **Given** the script tests a release, **When** determining minimum Swift version, **Then** it uses binary search to minimize the number of build attempts
3. **Given** all releases are tested, **When** results are analyzed, **Then** consecutive releases with identical requirements are grouped into ranges

---

### Edge Cases

- What happens when a release fails to build with all tested Swift versions? → Mark as "requires Swift > 6.0" or investigate build failure
- How does the system handle prereleases? → Prereleases are excluded from the compatibility table (production users don't pin to them)
- What happens when the CI workflow fails mid-run? → Workflow should be idempotent and re-runnable without side effects
- How are build failures distinguished from compatibility failures? → Network/transient failures should retry; genuine incompatibility should be recorded

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: README MUST contain a "Swift versions" section with a compatibility table following swift-crypto's format
- **FR-002**: The compatibility table MUST show swift-secp256k1 version ranges mapped to minimum Swift versions
- **FR-003**: Version ranges MUST use Swift range syntax (e.g., `0.15.0 ..< 0.19.0`, `0.21.0 ...`)
- **FR-004**: CI workflow MUST test new releases against Swift versions 5.7, 5.8, 5.9, 5.10, and 6.0
- **FR-005**: CI workflow MUST open a pull request when compatibility data changes
- **FR-006**: CI workflow MUST NOT modify README directly (human review required)
- **FR-007**: Bootstrap script MUST use binary search to efficiently find minimum Swift version
- **FR-008**: Only stable releases (no prereleases, alphas, betas, RCs) MUST appear in the table
- **FR-009**: CI workflow MUST be triggered on new release tags matching semantic versioning pattern
- **FR-010**: Swift version matrix MUST be manually updated in the workflow file when new Swift versions are released
- **FR-011**: CI workflow MUST use built-in GITHUB_TOKEN for authentication (no additional secrets required)
- **FR-012**: Swift versions section MUST be placed after the Installation section in README.md
- **FR-013**: Compatibility table MUST include all stable releases from 0.0.1 onwards

### Key Entities

- **Compatibility Table**: Markdown table in README showing version ranges and minimum Swift requirements
- **Release**: A tagged stable version of swift-secp256k1 (excludes prereleases)
- **Swift Version Matrix**: The set of Swift versions tested (5.7, 5.8, 5.9, 5.10, 6.0)
- **Compatibility Result**: Mapping of a release to its minimum supported Swift version

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: README contains a "Swift versions" section visible to all repository visitors
- **SC-002**: Table accurately reflects minimum Swift version for 100% of stable releases
- **SC-003**: New releases have compatibility data within 24 hours of tagging (via automated PR)
- **SC-004**: Binary search reduces build attempts to ≤3 per release (vs. 5 for linear search)
- **SC-005**: Zero manual intervention required for ongoing table maintenance after initial bootstrap

## Implementation Notes

### Approach Pivot (2025-12-13)

Original plan used binary search with build-testing to determine minimum Swift version. This failed because older Swift toolchains (5.2-5.5) cannot compile against modern macOS SDKs, producing false negatives.

**Final approach**: Extract `swift-tools-version` from each release's `Package.swift`. This is the authoritative source that SPM enforces—no build testing required.

### Phase 4 Skipped

CI workflow automation was specified but deliberately skipped after evaluating industry best practices:
- swift-tools-version is set manually by maintainer when releasing
- Manual README update takes ~10 seconds vs hours of CI maintenance  
- swift-crypto and other major packages use manual updates
- Automated PRs create review overhead for minimal benefit

## Assumptions

- Swift toolchains 5.7 through 6.0 are available in GitHub Actions runners
- **TDD Exception**: This CI/documentation feature uses build success/failure as its test mechanism rather than traditional unit tests. The builds themselves verify compatibility—no separate test suite needed. This aligns with Constitution Principle V intent (verifiable outcomes) while acknowledging that declarative YAML workflows and one-time scripts don't benefit from TDD patterns.
- Package build success is a reliable indicator of Swift version compatibility
- The swift-crypto table format is the accepted industry standard for Swift packages
- Grouped version ranges provide sufficient granularity for users (individual release compatibility not needed)
- GITHUB_TOKEN has sufficient permissions to create pull requests in this repository
