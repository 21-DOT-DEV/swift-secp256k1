# Workflow Schema: Swift Version Compatibility

**Feature**: 002-swift-version-compat  
**Date**: 2025-12-13

This document defines the GitHub Actions workflow design (replaces data-model.md for this CI/documentation feature).

## Workflow Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Release Tag    │────▶│  Test Matrix     │────▶│  Update README  │
│  (trigger)      │     │  Swift 5.7-6.0   │     │  (via PR)       │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Workflow: `swift-version-compat.yml`

### Trigger

```yaml
on:
  push:
    tags:
      - '[0-9]+.[0-9]+.[0-9]+'  # Matches semver: 0.21.1, 1.0.0, etc.
```

**Excludes**: Prereleases (no `-alpha`, `-beta`, `-rc` suffix matching)

### Jobs

#### Job 1: `test-compatibility`

**Purpose**: Test the tagged release against Swift version matrix

**Matrix**:
```yaml
strategy:
  matrix:
    swift-version: ['5.7', '5.8', '5.9', '5.10', '6.0']
  fail-fast: false  # Continue testing all versions even if one fails
```

**Steps**:
1. Checkout repository
2. Setup Swift toolchain (via swift-actions/setup-swift)
3. Build package with `swift build`
4. Record result (pass/fail) as job output

**Outputs**:
- `min-swift-version`: Minimum Swift version that builds successfully

#### Job 2: `update-readme`

**Purpose**: Update README.md if compatibility data changed

**Depends on**: `test-compatibility`

**Conditions**: Only runs if minimum Swift version determined

**Steps**:
1. Checkout repository
2. Parse test results from previous job
3. Update Swift versions table in README.md
4. Create PR if changes detected

### Workflow Inputs/Outputs

| Input | Source | Description |
|-------|--------|-------------|
| Tag name | `github.ref_name` | Release version being tested |
| Swift versions | Hardcoded matrix | Versions to test against |

| Output | Destination | Description |
|--------|-------------|-------------|
| Compatibility result | Job output | Min Swift version for release |
| Pull request | GitHub | PR with README updates |

## README Table Format

Location: After "Installation" section in README.md

```markdown
### Swift versions

The most recent versions of swift-secp256k1 support Swift 6 and newer. The minimum Swift version supported by swift-secp256k1 releases are detailed below:

swift-secp256k1     | Minimum Swift Version
--------------------|----------------------
`0.0.1  ..< 0.10.0` | 5.7
`0.10.0 ..< 0.15.0` | 5.8
`0.15.0 ..< 0.19.0` | 5.9
`0.19.0 ..< 0.21.0` | 5.10
`0.21.0 ...`        | 6.0
```

*Note: Actual ranges will be determined by bootstrap script results*

## Update Algorithm

When a new release is tagged:

1. Test against all Swift versions in matrix
2. Find minimum passing version
3. Compare to current table:
   - If same as previous release → extend current range (no change needed)
   - If different → start new range, update table
4. If table changed → create PR

## Security Considerations

- Uses built-in `GITHUB_TOKEN` (no additional secrets)
- PR requires human approval before merge (FR-006)
- Workflow only triggered by maintainer-created tags
- No external API calls beyond GitHub

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Build fails all Swift versions | Log warning, do not update table |
| Network timeout | GitHub Actions retry (built-in) |
| PR creation fails | Workflow fails, maintainer notified |
| Table parse error | Workflow fails with descriptive error |
