# Shared Sources

This directory contains Swift source files shared between the **P256K** and **ZKP** targets.

## How It Works

The `SharedSourcesPlugin` (SPM build plugin) flattens all `.swift` files from this directory (including subdirectories) into each target's build directory before compilation. This enables code sharing without symlinks, ensuring cross-platform compatibility.

> **Technical Note**: SPM doesn't recursively include subdirectories from plugin output, so the plugin uses `find + cp` to flatten 43 files into a single directory for compilation.

## Directory Structure

```
Sources/
├── Shared/              ← You are here
│   ├── *.swift          ← Core shared files (20) — you can modify these
│   └── swift-crypto/    ← Dependency files (23) — auto-managed, do not edit
├── P256K/               ← P256K-specific code
└── ZKP/                 ← ZKP-specific code
```

## Core Shared Files (20)

Files you can modify. These compile into both P256K and ZKP targets:

- Asymmetric, Combine, Context, DH, ECDH, ECDSA, EdDSA
- Errors, HashDigest, MuSig, Nonces, P256K, Recovery
- SafeCompare, Schnorr, SHA256, Tweak, UInt256, Utility, Zeroization

## Dependencies (swift-crypto/)

Auto-extracted from `Vendor/swift-crypto` via `subtree.yaml`. **Do not edit directly.**

These provide cryptographic primitives (SecureBytes, Digest, ASN1, etc.) used by the core files.

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
