# Shared Sources

This directory contains Swift source files shared between the **P256K** and **ZKP** targets.

## How It Works

The `SharedSourcesPlugin` (SPM build plugin) flattens all `.swift` files from this directory (including subdirectories) into each target's build directory before compilation. This enables code sharing without symlinks, ensuring cross-platform compatibility.

> **Technical Note**: SPM doesn't recursively include subdirectories from plugin output, so the plugin uses `find + cp` to flatten 63 files into a single directory for compilation.

## Directory Structure

```
Sources/
├── Shared/              ← You are here
│   ├── *.swift          ← Core shared files (43) — you can modify these
│   └── swift-crypto/    ← 20 .swift + LICENSE.txt/NOTICE.txt — auto-managed, do not edit
├── P256K/               ← P256K-specific code
└── ZKP/                 ← ZKP-specific code
```

## Core Shared Files (43)

Files you can modify. These compile into both P256K and ZKP targets:

- Root files: Combine, Context, DH, ECDH, EdDSA, Errors, HashDigest, SafeCompare, SHA256, Utility, Zeroization
- `ECDSA/`, `Keys/`, `MuSig/`, `Recovery/`, `Schnorr/`, `UInt256/` — scheme- and type-grouped files
- `ASN1/` — project-owned copies of the vendir-excluded swift-crypto files (`ObjectIdentifier`, `SEC1PrivateKey`, `SubjectPublicKeyInfo`); their upstream originals live at `Sources/Crypto/ASN1/` — see "Syncing local files with upstream" in `Sources/AGENTS.md`

## Dependencies (swift-crypto/)

Auto-synced from `apple/swift-crypto` via `vendir.yml`. **Do not edit directly.**

These provide cryptographic primitives (SecureBytes, Digest, ASN1, etc.) used by the core files.

> **Invariant**: `LICENSE.txt`/`NOTICE.txt` ride with the synced code and stay inert only because SharedSourcesPlugin copies `*.swift`. Any replacement for the plugin must keep that file-type filter.

## Guidelines

- **Add shared code here** if it's used by both P256K and ZKP targets
- **Use `#if canImport`** for target-specific conditional compilation
- **Promote code** from `Sources/ZKP/` using `git mv` when ready to share

## Promoting Code to Shared

```bash
# Move a file from ZKP to Shared
git mv Sources/ZKP/NewFeature.swift Sources/Shared/NewFeature.swift

# Rebuild to verify both targets compile
swift build
```

The plugin automatically includes the new file in both targets on next build.
