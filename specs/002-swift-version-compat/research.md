# Research: Swift Version Compatibility Table

**Feature**: 002-swift-version-compat  
**Date**: 2025-12-13

## Research Topics

### 1. GitHub Actions Swift Toolchain Setup

**Decision**: Use `swift-actions/setup-swift` action for Swift toolchain management

**Rationale**:
- Official Swift community action maintained by swift-actions org
- Supports all Swift versions 5.7+ on ubuntu-latest
- Handles toolchain caching automatically
- Used by SwiftNIO, Vapor, and other major Swift packages

**Alternatives Considered**:
- Manual toolchain download via `swiftly` - More complex, no caching benefits
- Docker containers with Swift - Slower startup, harder to matrix across versions
- macOS runners - More expensive, Linux sufficient for build testing

### 2. PR Creation from GitHub Actions

**Decision**: Use `peter-evans/create-pull-request` action

**Rationale**:
- Most popular and well-maintained PR creation action (10k+ stars)
- Works with built-in GITHUB_TOKEN
- Handles branch creation, commit, and PR in one step
- Supports updating existing PRs on re-runs

**Alternatives Considered**:
- `gh pr create` CLI - Requires additional authentication setup
- Custom script with GitHub API - More maintenance burden
- Direct push to main - Violates human review requirement (FR-006)

### 3. Compatibility Data Storage

**Decision**: Store in README.md directly as Markdown table

**Rationale**:
- Matches swift-crypto pattern exactly
- No additional files to maintain
- Visible to users without extra clicks
- Simple grep/sed can update the table

**Alternatives Considered**:
- Separate JSON file - Adds complexity, requires rendering step
- GitHub Release metadata - Not visible in README
- Wiki page - Less discoverable

### 4. Workflow Trigger Strategy

**Decision**: Trigger on release tags matching semver pattern

**Rationale**:
- Only runs when actual releases are created
- Excludes prereleases automatically via tag pattern
- Aligns with existing xcframework-release.yml pattern

**Alternatives Considered**:
- workflow_dispatch only - Requires manual trigger, easy to forget
- Push to main - Would run on every commit, wasteful
- Schedule (cron) - Delays compatibility info, not event-driven

### 5. Swift Version Matrix Evolution

**Decision**: Manual update to workflow file when new Swift versions release

**Rationale**:
- Swift major versions release ~annually (low frequency)
- Manual control prevents testing against unstable/beta toolchains
- Aligns with decision from `/speckit.clarify` session

**Alternatives Considered**:
- Auto-detect via API - Complex, might include unstable versions
- Config file - Adds indirection without significant benefit

## Existing Workflow Patterns

From `docker-image.yml`:
```yaml
- uses: actions/checkout@v6
  with:
    submodules: recursive
```

Patterns to follow:
- Use `actions/checkout@v6`
- Include `submodules: recursive` for libsecp256k1
- Use `ubuntu-latest` for Linux testing

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| actions/checkout | v6 | Repository checkout |
| swift-actions/setup-swift | v2 | Swift toolchain setup |
| peter-evans/create-pull-request | v6 | PR creation |

## Open Questions (Resolved)

All research questions resolved. Ready for Phase 1 design.
