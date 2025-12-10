# Shared Sources

This directory contains Swift source files shared between the **P256K** and **ZKP** targets.

## How It Works

The `SharedSourcesPlugin` (SPM build plugin) copies these files to each target's build directory before compilation. This enables code sharing without symlinks, ensuring cross-platform compatibility.

## Directory Structure

```
Sources/
├── Shared/          ← You are here (shared code)
├── P256K/           ← P256K-specific code (ASN1, swift-crypto)
└── ZKP/             ← ZKP-specific code
```

## Guidelines

- **Add shared code here** if it's used by both P256K and ZKP targets
- **Use `#if canImport`** for target-specific conditional compilation
- **Promote code** from `Sources/ZKP/` using `git mv` when ready to share

## Example: Promoting Code

```bash
# Move a file from ZKP to Shared
git mv Sources/ZKP/NewFeature.swift Sources/Shared/NewFeature.swift

# Rebuild to verify both targets compile
swift build
```

## Files (20)

All files here compile into both P256K and ZKP targets:

- Asymmetric, Combine, Context, DH, ECDH, ECDSA, EdDSA
- Errors, HashDigest, MuSig, Nonces, P256K, Recovery
- SafeCompare, Schnorr, SHA256, Tweak, UInt256, Utility, Zeroization
