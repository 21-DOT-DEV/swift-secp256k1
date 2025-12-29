# Feature Specification: swift-crypto 4.2.0 Update

**Feature Branch**: `004-swift-crypto-update`  
**Created**: 2025-12-26  
**Status**: Implemented  
**Input**: Update vendored swift-crypto via subtree plugin from 3.11.1 to 4.2.0. Resolve breaking availability attribute changes in `Sources/Shared/` on case-by-case basis.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Library Consumer Compatibility (Priority: P1)

As a developer using swift-secp256k1 as a dependency, I need the library to continue working without changes to my code after the swift-crypto vendor update, so that I can benefit from upstream improvements without breaking my application.

**Why this priority**: Breaking changes to consumers would violate semantic versioning and cause adoption friction. This is the primary success criterion.

**Independent Test**: Build any existing project that depends on swift-secp256k1 before and after the update — all public APIs remain source-compatible.

**Acceptance Scenarios**:

1. **Given** a project depending on swift-secp256k1 v0.x, **When** the library is updated with swift-crypto 4.2.0, **Then** the project compiles without modification
2. **Given** existing unit tests in the swift-secp256k1 repository, **When** the update is applied, **Then** all tests pass on all supported platforms

---

### User Story 2 - Cross-Platform Build Integrity (Priority: P1)

As a library maintainer, I need the swift-crypto update to maintain build compatibility on all supported platforms (macOS, iOS, watchOS, tvOS, visionOS, Linux), so that the library's cross-platform promise is preserved.

**Why this priority**: Cross-platform support is a core value proposition. Linux compatibility is especially critical for server-side Swift users.

**Independent Test**: Run full test matrix across all platforms via CI or local verification.

**Acceptance Scenarios**:

1. **Given** the swift-crypto 4.2.0 update applied, **When** building on macOS, **Then** the package compiles successfully
2. **Given** the swift-crypto 4.2.0 update applied, **When** building on Linux, **Then** the package compiles successfully
3. **Given** the Projects/ Tuist configuration, **When** building all targets, **Then** all targets compile and tests pass

---

### User Story 3 - Availability Attribute Resolution (Priority: P2)

As a library maintainer, I need to resolve any breaking availability attribute changes introduced by swift-crypto 4.2.0, handling each affected file appropriately based on its dependencies (e.g., files using `StaticBigInt` retain higher minimum versions).

**Why this priority**: This is the expected breaking change that requires case-by-case resolution. Important but mechanical once discovery is complete.

**Independent Test**: Compile the package after updating swift-crypto; iterate on availability fixes until all errors are resolved.

**Acceptance Scenarios**:

1. **Given** swift-crypto 4.2.0 requires `@available(macOS 10.15, iOS 13, ...)` on some APIs, **When** applying to `Sources/Shared/`, **Then** files are updated based on their actual SDK dependencies
2. **Given** `UInt256.swift` depends on `StaticBigInt` (macOS 13.3+), **When** resolving availability, **Then** its attributes remain unchanged at `@available(macOS 13.3, iOS 16.4, ...)`
3. **Given** a file that only uses swift-crypto types without `StaticBigInt`, **When** resolving availability, **Then** it may adopt broader availability if appropriate

---

### Edge Cases

- **File imports swift-crypto transitively**: Some files may not directly import swift-crypto but use types that do. Discovery-based approach (compile errors) will surface these.
- **Conflicting availability requirements**: A file may use both `StaticBigInt` and swift-crypto types with different minimums. Use the more restrictive (higher) minimum version.
- **Linux-only code paths**: Linux doesn't use `@available` attributes. Ensure conditional compilation doesn't introduce platform-specific regressions.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Subtree update MUST use the swift-plugin-subtree tooling to update `Vendor/swift-crypto` from 3.11.1 to 4.2.0
- **FR-002**: The `subtree.yaml` configuration MUST be automatically updated by the subtree CLI (no manual edits)
- **FR-003**: All extractions for swift-crypto MUST be re-run after the subtree update
- **FR-004**: Breaking availability changes MUST be resolved using a discovery-based approach (compile, identify errors, fix iteratively)
- **FR-005**: Files depending on `StaticBigInt` MUST retain their current higher availability attributes
- **FR-006**: No modifications MUST be made to `Package.swift` beyond what the subtree plugin handles automatically
- **FR-007**: No platform limitations MUST be added to `Package.swift`
- **FR-008**: All existing tests MUST pass after the update is complete
- **FR-009**: All availability attribute fixes MUST be committed as a single atomic commit after the subtree update
- **FR-010**: Update MUST be documented in CHANGELOG.md following [keepachangelog.com](https://keepachangelog.com/) format
- **FR-011**: If CHANGELOG.md does not exist, it MUST be created following keepachangelog.com conventions

### Blocker Conditions (Rollback Triggers)

If any of these conditions arise, the update MUST be abandoned:

- **BL-001**: Update requires changes to public API signatures (breaking change for library consumers)
- **BL-002**: Update breaks Linux platform compatibility
- **BL-003**: Update requires modifications to `Package.swift` beyond the subtree update scope

### Key Entities

- **Vendor/swift-crypto**: Vendored copy of Apple's swift-crypto library, managed via subtree
- **subtree.yaml**: Configuration file defining subtree sources, commits, and extraction mappings
- **Sources/Shared/**: Directory containing shared code that may be affected by availability changes

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `subtree.yaml` shows swift-crypto at tag 4.2.0 with updated commit hash
- **SC-002**: Package builds successfully on macOS with `swift build`
- **SC-003**: Package builds successfully on Linux
- **SC-004**: All SPM test targets pass (`swift test`)
- **SC-005**: All Projects/ Tuist targets build and their tests pass
- **SC-006**: No changes to public API signatures (verified via API diff or manual review)
- **SC-007**: `Package.swift` contains no new platform restrictions

## Assumptions

- The swift-crypto 4.2.0 availability change primarily affects `@available` attributes, not API signatures
- The subtree plugin will handle the mechanical update of `Vendor/swift-crypto` correctly
- Files in `Sources/Shared/` that need availability changes can be identified via compile errors
- Existing CI infrastructure can verify cross-platform compatibility

## Clarifications

### Session 2025-12-26

- Q: How should availability attribute changes be committed? → A: Single atomic commit for all availability fixes after subtree update
- Q: Should this update be documented in changelog? → A: Yes, add CHANGELOG.md entry; create CHANGELOG.md if missing following keepachangelog.com format
