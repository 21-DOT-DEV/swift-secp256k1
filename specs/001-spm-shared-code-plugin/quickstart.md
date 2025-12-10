# Quickstart: SPM Shared Sources Plugin

**Date**: 2025-12-08  
**Feature**: 001-spm-shared-code-plugin

## Overview

The SharedSourcesPlugin automatically flattens all `.swift` files from `Sources/Shared/` (including subdirectories) into both P256K and ZKP targets at build time, eliminating the need for symlinks.

## For Library Users

**No changes required.** The plugin runs automatically during `swift build`. Shared code is compiled into both targets transparently.

## For Contributors

### Building the Project

```bash
# Clone and build (works on macOS, Linux)
git clone https://github.com/21-DOT-DEV/swift-secp256k1.git
cd swift-secp256k1
swift build
```

No additional setup required — no symlinks to create or special permissions needed.

### Understanding the Directory Structure

```
Sources/
├── Shared/               # Shared code (compiled into BOTH targets)
│   ├── *.swift           # 20 core shared files
│   └── swift-crypto/     # 23 dependency files (auto-extracted)
├── P256K/                # P256K-specific code only
└── ZKP/                  # ZKP-specific code only
```

**Rule of thumb**:
- `Sources/Shared/` = Code used by both P256K and ZKP
- `Sources/P256K/` = Code only for P256K target
- `Sources/ZKP/` = Code only for ZKP target

### Promoting Code from ZKP to Shared

When ZKP-experimental code is ready for the stable P256K target:

```bash
# Move file from ZKP to Shared
git mv Sources/ZKP/NewFeature.swift Sources/Shared/NewFeature.swift

# Rebuild to verify
swift build

# Commit
git add -A
git commit -m "Promote NewFeature to shared"
```

### Creating New Shared Code

```bash
# Create new file directly in Shared/
touch Sources/Shared/MyNewFile.swift

# Edit the file...

# Build verifies it compiles in both targets
swift build
```

### Handling Conflicts

If you accidentally have the same filename in both `Sources/Shared/` and a target directory, the Swift compiler will report duplicate symbol errors:

```
error: redefinition of 'SomeType'
note: previous definition is here
```

**Fix**: Rename or remove one of the conflicting files in either `Sources/Shared/` or the target directory.

## For Maintainers

### How the Plugin Works

1. SPM invokes `SharedSourcesPlugin` before compiling each target
2. Plugin uses `find + cp` to flatten all `.swift` files from `Sources/Shared/` into a build directory
3. SPM includes that build directory in the target's sources
4. Compiler sees all 43 shared files as part of each target

> **Why flattening?** SPM doesn't recursively include subdirectories from plugin output, so the plugin flattens the directory structure.

### Plugin Location

```
Plugins/
└── SharedSourcesPlugin/
    └── Plugin.swift
```

### Tuist/Projects Configuration

Tuist uses 3 directory symlinks (macOS-only, consolidated from 20+ file symlinks):

```
Projects/Sources/Shared -> ../../Sources/Shared
Projects/Sources/P256KTests -> ../../Tests/ZKPTests
Projects/Sources/libsecp256k1Tests -> ../../Tests/libsecp256k1zkpTests
```

The `Project.swift` includes this in the P256K target sources:

```swift
.target(
    name: "P256K",
    sources: ["Sources/P256K/**", "Sources/Shared/**"],
    // ...
)
```

### Debugging Build Issues

To see what the plugin is doing:

```bash
# Verbose build output
swift build -v

# Clean and rebuild
swift package clean
swift build
```

Plugin output files are in:
```
.build/plugins/outputs/secp256k1/<target>/SharedSourcesPlugin/
```

## Frequently Asked Questions

**Q: Do I need to do anything special on Windows?**  
A: Windows support is currently deferred. The plugin uses POSIX `find` and `cp` commands available on macOS and Linux. A Windows-compatible implementation (robocopy/xcopy) is planned.

**Q: Can I use `#if canImport` in shared files?**  
A: Yes. The existing patterns like `#if canImport(libsecp256k1_zkp)` continue to work.

**Q: What if `Sources/Shared/` is empty?**  
A: The plugin handles this gracefully — build proceeds with no shared files.

**Q: Does this affect build performance?**  
A: Negligible impact (< 5%). File copying via `find + cp` is fast for 43 files.
