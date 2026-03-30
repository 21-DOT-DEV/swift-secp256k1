# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.23.0] - 2026-03-29

### Added

- `benchmark-main.yml` GitHub Actions workflow: records a `package-benchmark` baseline on every push to `main` and uploads it as a 90-day artifact
- `benchmark-pr.yml` GitHub Actions workflow: downloads the cached `main` baseline, runs benchmarks on the PR branch only, and fails on regressions (exit code 2)
- `UInt256` and `Int256` types in a dedicated `Sources/Shared/UInt256/` module (`UInt256.swift`, `UInt256+Representation.swift`, `UInt256+Arithmetic.swift`, `UInt256+FixedWidthInteger.swift`, `UInt256+Modular.swift`)
- `uint256` opt-in SPM trait (not enabled by default) gating all `UInt256`/`Int256` sources and tests behind `#if Xcode || ENABLE_UINT256`; consumers with a conflicting type or awaiting a future stdlib addition can omit it
- DocC documentation catalog with Getting Started guide, API reference, and `swift-docc-plugin` 1.4.6 dependency (#1060)
- `AGENTS.md` files for AI-assisted development guidance (#1038)
- `CONTRIBUTING.md` and `SECURITY.md` project documentation (#1037)

### Changed

- CI (`bitrise.yml`, `Dockerfile`) now runs `swift test --traits ecdh,musig,recovery,schnorrsig,uint256` to cover the `uint256`-gated code paths
- Reduced `throws` propagation and reorganized `Shared` sources into subdirectories (`ECDSA/`, `Keys/`, `MuSig/`, `Recovery/`, `Schnorr/`) (#1034)
- Improved DocC doc comments across public API modules: refined summary lines, discussion sections, parameter/return/throws markup, and cross-references for `P256K.MuSig`, `P256K.Recovery`, `P256K.Signing`, `P256K.Schnorr`, `P256K.KeyAgreement`, and `P256K.Context` (#1060)
- Enabled Swift upcoming features `MemberImportVisibility` and `InternalImportsByDefault` (#1057)
- Updated vendored swift-crypto from 4.2.0 to 4.3.0 (#1042)
- Updated vendored secp256k1-zkp to latest upstream (#1026, #1028, #1036, #1045, #1047, #1051, #1053)
- Updated Docker base image from Swift 6.2.4 to 6.3.0 (#1054)
- Updated Docker registry path from finestructure to SwiftPackageIndex (#1056)
- Marked SPM build stubs as vendored in `.gitattributes` (#1043)
- Updated README with improved structure, table of contents, and clarity (#1037)
- Updated `CODE_OF_CONDUCT.md` to version 2.1 (#1037)

## [0.22.0]

### Added

- Package traits ([SE-0450](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)) for conditional module compilation (Swift 6.1+)
- Automated subtree update workflows for secp256k1 and secp256k1-zkp vendored sources
- SharedSourcesPlugin build plugin replacing symlinks for cross-platform compatibility
- `Sendable` conformance to key types (`PrivateKey`, `PublicKey`, `XonlyKey`, `SharedSecret`)
- Security, Wycheproof, Schnorr vector, and MuSig2 vector test targets via Tuist

### Changed

- Bumped swift-tools-version from 6.0 to 6.1
- Updated vendored swift-crypto from 3.11.1 to 4.2.0
- Updated vendored secp256k1 to v0.7.1
- Updated vendored secp256k1-zkp to latest upstream
- Added `@available` attributes to resolve availability requirements from swift-crypto 4.2.0
- Updated imports to use `FoundationEssentials` conditional pattern matching upstream swift-crypto
- Synced ASN1 files (`ObjectIdentifier.swift`, `SEC1PrivateKey.swift`, `SubjectPublicKeyInfo.swift`) with upstream structure
- Synced utility files (`SafeCompare.swift`, `Zeroization.swift`, `DH.swift`) with upstream patterns
- Migrated platform CI builds from Bitrise to GitHub Actions
- Replaced git submodules with subtrees for vendored dependencies

### Removed

- `@_implementationOnly` attribute from libsecp256k1 imports
