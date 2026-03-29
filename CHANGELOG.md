# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Improved DocC doc comments across public API modules: refined summary lines, discussion sections, parameter/return/throws markup, and cross-references for `P256K.MuSig`, `P256K.Recovery`, `P256K.Signing`, `P256K.Schnorr`, `P256K.KeyAgreement`, and `P256K.Context`
- Added BIP-327 signing protocol order documentation and nonce reuse warnings to `P256K.MuSig` and `P256K.MuSig.Nonce`
- Added recovery-does-not-imply-verification caveat to `P256K.Recovery.ECDSASignature`

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
