# Data Model: SPM Pre-Build Plugin for Shared Code

**Date**: 2025-12-08  
**Feature**: 001-spm-shared-code-plugin

## Overview

This feature involves build-time file operations, not runtime data persistence. The "data model" describes the file structures and information flow during the build process.

## Entities

### 1. Shared Source Directory

**Location**: `Sources/Shared/`

**Structure**:
```
Sources/Shared/
├── *.swift           # Top-level Swift files
└── [subdirs]/        # Optional subdirectories (structure preserved)
    └── *.swift
```

**Attributes**:
- Contains Swift source files shared between P256K and ZKP targets
- May contain nested subdirectories
- No symlinks — all regular files
- Files may use `#if canImport` for target-specific behavior

---

### 2. Plugin Output Directory

**Location**: `.build/plugins/outputs/<package>/<target>/SharedSourcesPlugin/`

**Structure**: Mirrors `Sources/Shared/` exactly

**Attributes**:
- SPM-managed directory (created/cleaned by SPM)
- Contains copies of all files from `Sources/Shared/`
- Automatically included in target's compilation sources
- Separate directory per target (P256K, ZKP)

---

### 3. Target Source Directory

**Location**: `Sources/P256K/` or `Sources/ZKP/`

**Attributes**:
- Contains target-specific Swift files only
- After migration: no symlinks
- Potential conflict source (filenames checked against Shared/)

---

### 4. Conflict Report

**Type**: Error thrown during prebuild

**Attributes**:
| Field | Type | Description |
|-------|------|-------------|
| `targetName` | String | Name of target being built |
| `conflicts` | [String] | List of conflicting filenames |
| `sharedPath` | String | Path to Sources/Shared/ |
| `targetPath` | String | Path to target's source directory |

**Example**:
```
Error: Filename conflict detected in target 'P256K'
The following files exist in both Sources/Shared/ and Sources/P256K/:
  - Duplicate.swift
  - AnotherDuplicate.swift

Resolution: Remove or rename the conflicting files in one location.
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        swift build                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SharedSourcesPlugin                            │
│                   (prebuildCommand)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────┐         ┌──────────────────────┐
│  For target: P256K   │         │  For target: ZKP     │
└──────────────────────┘         └──────────────────────┘
              │                               │
              ▼                               ▼
┌──────────────────────┐         ┌──────────────────────┐
│ 1. Scan Sources/P256K│         │ 1. Scan Sources/ZKP  │
│ 2. Scan Sources/Shared         │ 2. Scan Sources/Shared
│ 3. Check conflicts   │         │ 3. Check conflicts   │
│ 4. Copy Shared/ →    │         │ 4. Copy Shared/ →    │
│    plugin output dir │         │    plugin output dir │
└──────────────────────┘         └──────────────────────┘
              │                               │
              ▼                               ▼
┌──────────────────────┐         ┌──────────────────────┐
│ .build/plugins/      │         │ .build/plugins/      │
│   outputs/.../P256K/ │         │   outputs/.../ZKP/   │
│   SharedSourcesPlugin│         │   SharedSourcesPlugin│
│     ├── *.swift      │         │     ├── *.swift      │
│     └── [subdirs]/   │         │     └── [subdirs]/   │
└──────────────────────┘         └──────────────────────┘
              │                               │
              ▼                               ▼
┌──────────────────────┐         ┌──────────────────────┐
│ Swift Compiler       │         │ Swift Compiler       │
│ Sources:             │         │ Sources:             │
│ - Sources/P256K/*    │         │ - Sources/ZKP/*      │
│ - plugin output/*    │         │ - plugin output/*    │
└──────────────────────┘         └──────────────────────┘
```

## State Transitions

This feature has no runtime state. Build-time states:

```
[Package Load] → [Plugin Discovery] → [Prebuild Phase] → [Compilation]
                                            │
                         ┌──────────────────┼──────────────────┐
                         ▼                  ▼                  ▼
                   [Scan Files]      [Check Conflicts]   [Copy Files]
                                            │
                              ┌─────────────┴─────────────┐
                              ▼                           ▼
                        [No Conflict]              [Conflict Found]
                              │                           │
                              ▼                           ▼
                      [Continue Build]            [Fail with Error]
```

## Validation Rules

| Rule | Enforcement |
|------|-------------|
| No filename conflicts between Shared/ and target dir | Prebuild check; build fails |
| Sources/Shared/ must exist | Plugin checks; warns if empty |
| Files in Shared/ must be valid Swift | Swift compiler (not plugin) |
| Subdirectory structure preserved | Plugin implementation |
