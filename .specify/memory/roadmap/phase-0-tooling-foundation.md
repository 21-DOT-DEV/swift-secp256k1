# Phase 0: Tooling Foundation

**Goal**: Enable code sharing between P256K and ZKP products without duplication  
**Status**: 🔜 Planned  
**Last Updated**: 2025-12-03  
**Blocks**: Phase 1, Phase 4 (any code that benefits from sharing)

---

## Features

### SPM Pre-Build Plugin for Shared Code

**Purpose & User Value**:  
Create a Swift Package Manager plugin that allows shared code to be included in both `P256K` and `ZKP` targets without manual duplication. This enables the ZKP-first development workflow (prototype in ZKP, promote to P256K) while maintaining a single source of truth for shared implementations.

**Success Metrics**:
- Shared code compiles into both P256K and ZKP targets from single source
- No manual file copying required when promoting APIs
- Build times not significantly impacted (< 5% increase)
- Plugin works with both SPM and Tuist (Projects/)

**Dependencies**:
- None (foundation phase)

**Notes**:
- Plugin scoped to this repository only (not a published package)
- Should integrate with existing `Projects/Project.swift` Tuist configuration
- Consider how this affects XCFramework builds

---

## Phase Dependencies & Sequencing

1. **SPM Plugin Implementation** — single feature, must complete before Phase 1

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Shared code works in both targets | Yes |
| Build time impact | < 5% increase |
| Tuist compatibility | Yes |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| SPM plugin API limitations | May not support all sharing patterns | Research SPM plugin capabilities early; fall back to symlinks if needed |
| Tuist integration complexity | Could delay Projects/ test targets | Implement SPM-only first, Tuist support as follow-up |
