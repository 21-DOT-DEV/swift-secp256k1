# Quickstart: Swift Version Compatibility

**Feature**: 002-swift-version-compat  
**Date**: 2025-12-13

## Overview

This feature adds a Swift version compatibility table to README.md and automates its maintenance via GitHub Actions.

## Initial Setup (One-Time Bootstrap)

### Prerequisites

1. **Install swiftly** (Swift toolchain manager):
   ```bash
   curl -L https://swiftlang.github.io/swiftly/swiftly-install.sh | bash
   swiftly init
   ```

2. **Install required Swift toolchains**:
   ```bash
   swiftly install 5.7 5.8 5.9 5.10 6.0
   ```

### Run Bootstrap Script

```bash
cd /path/to/swift-secp256k1
./scripts/swift-version-compat.sh
```

**Expected output**:
- Progress updates for each release tested
- ETA for completion
- Final grouped ranges table for README

**Runtime**: 30-60 minutes (tests ~20 releases × 2-3 Swift versions each)

### Add Results to README

1. Copy the "Grouped Ranges for README.md" output from the script
2. Add to README.md after the "Installation" section
3. Delete the bootstrap script and results file:
   ```bash
   rm scripts/swift-version-compat.sh
   rm swift-compat-results.csv
   ```

## Ongoing Maintenance

After initial setup, the GitHub Actions workflow handles everything automatically:

1. **Tag a new release** → Workflow triggers
2. **Workflow tests** → Against Swift 5.7-6.0 matrix
3. **If compatibility changes** → PR opened automatically
4. **Review and merge** → Table stays current

### Manual Workflow Trigger (Optional)

If you need to re-run compatibility testing:

```bash
gh workflow run swift-version-compat.yml
```

## Adding New Swift Versions

When a new Swift version is released (e.g., Swift 6.1):

1. Edit `.github/workflows/swift-version-compat.yml`
2. Add new version to matrix:
   ```yaml
   swift-version: ['5.7', '5.8', '5.9', '5.10', '6.0', '6.1']
   ```
3. Commit and push
4. Next release tag will test against the new version

## Troubleshooting

### Bootstrap script fails

**Symptom**: Script exits with error during testing

**Solutions**:
- Ensure all Swift toolchains installed: `swiftly list`
- Check network connectivity (fetches from GitHub)
- Run with verbose output: `bash -x scripts/swift-version-compat.sh`

### GitHub Actions workflow fails

**Symptom**: Workflow fails on release tag

**Solutions**:
- Check Actions tab for error details
- Verify Swift version available in GitHub runners
- Check GITHUB_TOKEN permissions (needs `contents: write`, `pull-requests: write`)

### PR not created

**Symptom**: Workflow succeeds but no PR appears

**Possible causes**:
- Compatibility unchanged from previous release (expected behavior)
- PR already exists for this update
- Check workflow logs for "No changes detected"

## File Locations

| File | Purpose |
|------|---------|
| `README.md` | Contains Swift versions table |
| `.github/workflows/swift-version-compat.yml` | Automation workflow |
| `specs/002-swift-version-compat/` | Feature documentation |
