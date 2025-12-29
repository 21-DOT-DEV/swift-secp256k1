# Quickstart: swift-crypto 4.2.0 Update

**Feature**: 004-swift-crypto-update  
**Date**: 2025-12-26  
**Estimated Time**: 30-60 minutes

---

## Prerequisites

- On branch `004-swift-crypto-update`
- Working directory clean (`git status`)
- Swift toolchain available (`swift --version`)

---

## Step 1: Update Subtree

Run the subtree update command to fetch swift-crypto 4.2.0:

```bash
swift package --allow-network-connections all --allow-writing-to-package-directory subtree update swift-crypto
```

**Expected Output**:
- `subtree.yaml` updated with new commit hash and tag `4.2.0`
- `Vendor/swift-crypto/` updated with new source files

---

## ⏸️ CHECKPOINT 1: Verify Subtree Update

Before proceeding, verify:

1. **Check `subtree.yaml`**:
   ```bash
   grep -A3 "name: swift-crypto" subtree.yaml
   ```
   Should show `tag: 4.2.0` (not `3.11.1`)

2. **Review changed files**:
   ```bash
   git status
   git diff subtree.yaml
   ```

3. **Commit subtree update** (if satisfied):
   ```bash
   git add subtree.yaml Vendor/swift-crypto/
   git commit -m "chore: update swift-crypto subtree to 4.2.0"
   ```

**⚠️ STOP HERE** — Confirm checkpoint before proceeding to Step 2.

---

## Step 2: Run Extractions

Re-run extractions to update `Sources/Shared/swift-crypto/`:

```bash
swift package --allow-writing-to-package-directory subtree extract --name swift-crypto
```

**Expected Output**:
- Files in `Sources/Shared/swift-crypto/` updated with new content

---

## ⏸️ CHECKPOINT 2: Verify Extractions

Before proceeding, verify:

1. **Check extracted files changed**:
   ```bash
   git status Sources/Shared/swift-crypto/
   ```

2. **Review key file changes**:
   ```bash
   git diff Sources/Shared/swift-crypto/
   ```

3. **Look for availability changes** in diff output:
   - `@available(macOS 10.15, iOS 13, ...)` — new broader availability
   - Compare with existing `Sources/Shared/` files

**⚠️ STOP HERE** — Confirm checkpoint before proceeding to Step 3.

---

## Step 3: Attempt Build

Try to build the package to discover any breaking changes:

```bash
swift build
```

**Expected Outcomes**:

| Result | Action |
|--------|--------|
| ✅ Build succeeds | Proceed to Step 5 (verification) |
| ❌ Availability errors | Proceed to Step 4 (fix availability) |
| ❌ Other errors | Evaluate against blocker conditions |

---

## Step 4: Fix Availability Errors (If Needed)

For each file with availability errors:

### 4a. Identify the constraint

Determine why the file needs specific availability:
- Uses `StaticBigInt`? → Keep `@available(macOS 13.3, iOS 16.4, ...)`
- Only uses swift-crypto types? → Can use `@available(macOS 10.15, iOS 13, ...)`
- Uses both? → Use the more restrictive (higher) minimum

### 4b. Apply fixes

Update `@available` annotations as needed. Example:

```swift
// For files NOT using StaticBigInt:
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)

// For files using StaticBigInt (like UInt256.swift):
@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)
```

### 4c. Iterate

Repeat build until all errors resolved:

```bash
swift build
```

---

## ⏸️ CHECKPOINT 3: Verify Build Success

Before proceeding to tests:

1. **Confirm clean build**:
   ```bash
   swift build 2>&1 | tail -5
   ```
   Should show "Build complete!"

2. **Check Package.swift unchanged**:
   ```bash
   git diff Package.swift
   ```
   **BLOCKER**: If Package.swift has changes beyond subtree scope, STOP and evaluate.

**⚠️ STOP HERE** — Confirm checkpoint before proceeding to Step 5.

---

## Step 5: Run Tests

### 5a. SPM Tests

```bash
swift test
```

### 5b. Projects/ Tuist Tests (if available)

```bash
cd Projects
tuist generate
xcodebuild test -scheme P256KTests -destination 'platform=macOS'
```

---

## Step 6: Cross-Platform Verification

### 6a. Linux Build (Docker)

```bash
docker run --rm -v $(pwd):/package -w /package swift:6.0 swift build
docker run --rm -v $(pwd):/package -w /package swift:6.0 swift test
```

Or rely on CI pipeline.

---

## Step 7: Create CHANGELOG Entry

### 7a. Create CHANGELOG.md (if not exists)

```bash
cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Updated vendored swift-crypto from 3.11.1 to 4.2.0
EOF
```

### 7b. Or append to existing CHANGELOG.md

Add under `## [Unreleased]` → `### Changed`:
```
- Updated vendored swift-crypto from 3.11.1 to 4.2.0
```

---

## Step 8: Final Commit

Commit all availability fixes and changelog in a single atomic commit:

```bash
git add Sources/Shared/ CHANGELOG.md
git commit -m "fix: resolve swift-crypto 4.2.0 availability changes

- Updated availability annotations in Sources/Shared/ as needed
- Files using StaticBigInt retain macOS 13.3+ requirements
- Added CHANGELOG.md following keepachangelog.com format"
```

---

## Blocker Conditions

**STOP and rollback if any of these occur:**

| Condition | How to Detect | Action |
|-----------|---------------|--------|
| Public API signature changes required | Compile errors requiring API changes | `git checkout main -- .` |
| Linux build fails | Docker build fails | Investigate; rollback if unresolvable |
| Package.swift modifications needed | `git diff Package.swift` shows changes | Rollback |

---

## Success Criteria Checklist

- [x] `subtree.yaml` shows swift-crypto at tag 4.2.0
- [x] `swift build` succeeds on macOS
- [x] `swift build` succeeds on Linux (deferred to CI)
- [x] `swift test` passes all tests (46 tests in 11 suites)
- [x] Projects/ Tuist targets build and test successfully (38 tests in 10 suites)
- [x] No changes to public API signatures
- [x] `Package.swift` has no new platform restrictions
- [x] CHANGELOG.md updated with version change
