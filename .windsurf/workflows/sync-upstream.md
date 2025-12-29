---
description: Cross-reference modified local files with their upstream originals in Vendor/ directories, identify syncable changes, and propose edits to align with upstream patterns while preserving local customizations.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). The user may specify:
- A single file path (e.g., `@[Sources/Shared/DH.swift]`)
- A directory path (e.g., `Sources/Shared/`)
- Multiple files separated by spaces

## Outline

Goal: Analyze differences between modified local files and their upstream originals in vendored dependencies, categorize changes, and propose specific edits to sync safe changes while preserving local customizations.

### Step 1: Identify Target Files

1. **If user provided file(s)**: Use the specified path(s)
2. **If user provided directory**: List relevant source files in that directory
3. **If no input**: Prompt user to specify files or directory to analyze

### Step 2: Locate Upstream Originals

For each target file, attempt to find the upstream original:

1. **Search strategy**:
   - Extract filename from path
   - Search in `Vendor/` directories for matching filename
   - Use: `find Vendor/ -name "<filename>" -type f`

2. **If multiple matches found**: 
   - Present options to user
   - Ask which upstream file to compare against

3. **If no match found**:
   - Mark file as "No upstream found"
   - Note: File may be fully custom (not derived from vendor)

### Step 3: Generate Comparison Table

Create a summary table of all files to analyze:

```
## Cross-Reference Summary

| Local File | Upstream Original | Status |
|------------|-------------------|--------|
| `Sources/Local/FileA.swift` | `Vendor/lib/.../FileA.swift` | 🔍 Analyzing |
| `Sources/Local/CustomFile.swift` | (custom - no upstream) | ⏭️ Skip |
```

### Step 4: Analyze Each File Pair

For each local ↔ upstream pair, perform detailed comparison:

#### 4a. Read Both Files
- Read the local (modified) file completely
- Read the upstream (original) file completely

#### 4b. Categorize Differences

Identify changes in these categories:

| Category | Pattern to Detect | Typically Syncable? |
|----------|-------------------|---------------------|
| **Imports** | Import statement changes, conditional imports | ✅ Yes |
| **Availability** | `@available(...)` attributes | ✅ Yes |
| **Protocol Conformance** | `Sendable`, `Hashable`, etc. | ✅ Yes |
| **Concurrency** | `@preconcurrency`, `nonisolated`, `async` | ✅ Yes |
| **Conditional Compilation** | `#if` / `#endif` wrappers | ✅ Yes |
| **Access Control** | `public`, `internal`, `private` changes | ⚠️ Review |
| **Documentation** | Doc comments, file headers | ⚠️ Review |
| **Implementation** | Function bodies, algorithms | ❌ Preserve local |
| **Custom Extensions** | Local-only types and code | ❌ Preserve local |

#### 4c. Identify Preservation Zones

Mark sections that should NOT be synced:
- Custom type definitions unique to local project
- Local-specific implementations
- Project-specific integrations
- Custom initializers, properties, or methods

### Step 5: Present Findings

For each file, output a detailed analysis:

```
## Analysis: Sources/Local/FileA.swift

**Upstream**: `Vendor/library/Sources/FileA.swift`

### Syncable Changes

| Category | Upstream Pattern | Current Local | Action |
|----------|------------------|---------------|--------|
| Imports | Conditional import pattern | Simple import | 🔄 Sync |
| Protocol | `TypeA: Sendable` | Missing conformance | 🔄 Sync |
| Availability | `@available(...)` on type | Missing attribute | 🔄 Sync |

### Preservation Zones (Do Not Sync)

| Section | Reason |
|---------|--------|
| Custom property `foo` | Local customization |
| Extension for `CustomType` | Project-specific type |

### Proposed Edits

1. **Update imports** (lines X-Y):
   - Show specific code change

2. **Add protocol conformance** (line Z):
   - Show specific code change
```

### Step 6: User Confirmation

After presenting all findings:

1. **Ask user**: "Would you like me to apply these proposed edits? (yes/no/select)"
   - `yes` - Apply all proposed syncable changes
   - `no` - End workflow, user will handle manually
   - `select` - Let user choose which edits to apply

2. **If applying edits**:
   - Apply changes one file at a time
   - Verify build after each file (language-appropriate build command)
   - Report success/failure for each

### Step 7: Final Summary

After all operations:

```
## Sync Summary

| File | Changes Applied | Build Status |
|------|-----------------|--------------|
| FileA.swift | 3 edits | ✅ Pass |
| FileB.swift | 5 edits | ✅ Pass |
| FileC.swift | 2 edits | ✅ Pass |

**Total**: 10 edits across 3 files
**Build**: All files compile successfully
```

---

## Important Guidelines

1. **Never auto-apply without confirmation**: Always show proposed changes first
2. **Preserve local customizations**: Project-specific code must not be overwritten
3. **Build verification**: After applying changes, verify the project still builds
4. **Incremental approach**: Apply changes file-by-file for easier rollback
5. **Document changes**: Note what was synced for future reference
6. **Language agnostic**: Adapt patterns to the project's language (Swift, TypeScript, etc.)

---

## Example Invocations

```
# Single file
/sync-upstream @[Sources/Shared/DH.swift]

# Multiple files
/sync-upstream Sources/Shared/FileA.swift Sources/Shared/FileB.swift

# Entire directory
/sync-upstream Sources/Shared/

# With explicit upstream path
/sync-upstream @[Sources/Local/File.swift] --upstream @[Vendor/lib/Sources/File.swift]
```
