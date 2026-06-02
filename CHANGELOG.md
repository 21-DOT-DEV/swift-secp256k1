# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.23.2] - 2026-05-22

### Added

- `WorkingWithKeys` DocC article consolidating the previous `KeyFormats`, `SerializingKeys`, and `TweakingKeys` articles into a single key-handling guide covering compressed/uncompressed/x-only encoding, PEM/DER serialization, and additive/multiplicative tweak operations (#1128)
- `ECDSASigningAndBitcoinTransactions` DocC article covering DER and compact encoding, low-S normalization, and a BIP-143 sighash recipe (#1128)
- Taproot key-path spend example using `SHA256.taggedHash(tag: "TapSighash", ...)` and BIP-341 reference in the Schnorr documentation (#1128)
- `SharedSourcesPlugin` trust note in the README installation section (#1106)

### Changed

- Moved CocoaPods, Arena, and Xcode plugin-trust instructions out of `README.md` into the Getting Started article; trimmed the README install section to a minimal SPM snippet and a link to the full guide (#1128)
- Tightened DocC terminology across the catalog (e.g., "public key" → "verifying key" where used for verification; "envelope" → "wrapper"/"form" for ASN.1 structures; "party" → "co-signer" in MuSig2 contexts) and replaced plain-text BIP/RFC/paper references with inline markdown links (#1126)
- Updated Docker base image from Swift 6.3.1 to 6.3.2 (#1119)
- Dropped the scheduled trigger from `check-subtree-updates.yml`; subtree updates now run only on manual dispatch or push (#1116)

## [0.23.1] - 2026-04-29

### Added

- DocC catalog articles: `KeyFormats`, `MuSig2MultiSignatures`, `RecoveringPublicKeys`, and `SecurityConsiderations` covering key representations, BIP-327 multi-signatures, ECDSA public-key recovery, and context randomization / nonce reuse / constant-time guidance (#1079)
- `EllipticCurveDiffieHellman` and `SilentPayments` DocC articles with cross-linked examples; DocC links added throughout the README usage snippets (#1103)
- `ChoosingP256KvsZKP` article and expanded `ZKP` landing page in the ZKP DocC catalog (#1096)
- `docc-release.yml` workflow to build and upload DocC archives on tagged releases (#1096)
- DocC validation job in `apple-builds.yml` (`generate-documentation --warnings-as-errors`) (#1096)
- Expanded `///` doc comments across `Sources/Shared/` with upstream citations to libsecp256k1/secp256k1-zkp headers and BIPs 32/137/146/322/324/327/340/341/352, plus `Topics` sections on major types (#1096)

### Changed

- `Package.swift` now excludes development-only dependencies (SwiftFormat, SwiftLint, Tuist, Lefthook, swift-plugin-subtree, swift-docc-plugin) at tagged releases via `Context.gitInformation?.currentTag`, so consumers resolving a tagged version no longer download dev tooling (#1082)
- Hardened workflow `env` usage in `xcframework-release.yml` and `update-subtree.yml` by moving `${{ github.ref_name }}` / `${{ inputs.subtree_name }}` into step-level env blocks (#1082)
- Refreshed all six `AGENTS.md` files to focus on non-inferable content (commands, gotchas, boundaries) (#1082)
- Adopted org-level community health defaults: project now relies on `21-DOT-DEV/.github` for `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md`; project-specific contributor onboarding moved to `AGENTS.md` (#1088)
- Bumped `SECURITY.md` Supported Versions from `0.22.x` to `0.23.x` (#1088)
- Updated vendored swift-crypto from 4.3.0 to 4.5.0 (#1072, #1086, #1094)
- Updated vendored secp256k1-zkp to latest upstream (#1069)
- Updated Docker base image from Swift 6.3.0 to 6.3.1 (#1090)
- Updated `swift-docc-plugin` dev dependency from 1.4.6 to 1.5.0 (#1098)
- Updated `actions/upload-artifact` from 4 to 7 and `actions/download-artifact` from 4 to 8 in benchmark workflows (#1066, #1067)

### Fixed

- DocC: rewrite `SharedSourcesPlugin` paths in release archives so generated documentation resolves source files correctly (#1101)

### Removed

- Top-level `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md` (served from `21-DOT-DEV/.github` going forward) (#1088)

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

## [0.21.1] - 2025-04-29

### Changed

- Added Apple-platform availability guards around `UInt256` and `Asymmetric` APIs in the `ZKP` target so the package builds on Linux where those types are unavailable (#718)
- Extended `bitrise.yml` with platform-specific test invocations (#718)

## [0.21.0] - 2025-04-27

### Added

- `UInt256` fixed-width integer type in the `ZKP` target with arithmetic, modular, and `FixedWidthInteger` conformances; enables `P256K.Signing.PrivateKey(_:)` initialization from a 256-bit integer literal (#561)

## [0.20.0] - 2025-04-24

### Added

- `P256K.xcframework` distribution and CocoaPods support: tagged releases now publish a pre-built XCFramework via `xcframework-release.yml`, and `swift-secp256k1.podspec` is pushed to the CocoaPods Trunk (#671)
- Swift Testing migration for remaining XCTest cases; XCFramework-targeted test suite (#671)

### Changed

- **Breaking:** Renamed the primary module from `secp256k1` to `P256K` and the C-bindings module from `secp256k1_bindings` to `libsecp256k1`. Consumers must update `import secp256k1` to `import P256K` and replace `secp256k1.` type-prefixes with `P256K.` (#671)
- ZKP module directories renamed from `zkp`/`zkp_bindings` to `ZKP`/`libsecp256k1_zkp` to match the new naming convention (#671)

## [0.19.0] - 2025-04-13

### Added

- `Asymmetric` format-conversion helper for translating between compressed and uncompressed public-key representations (#707) — first contribution from @zeugmaster

## [0.18.1] - 2025-03-20

### Changed

- Made `secp256k1.MuSig.aggregate` and `Nonce.pubnonce` / `Nonce.secnonce` public so downstream consumers can drive aggregation and nonce exchange directly (#696) — first contribution from @RubenWaterman
- Added VS Code development configurations (`.vscode/launch.json`, `settings.json`, `tasks.json`) for `swift build`/`swift test` debugging (#615)

## [0.18.0] - 2024-10-16

### Added

- Swift APIs for MuSig2 (BIP-327): `secp256k1.MuSig` namespace with `aggregate`, partial-signature signing/verification, and `Nonce` generation/aggregation; `secnonce` is non-`Copyable` to prevent reuse (#560)

### Changed

- Bumped `swift-tools-version` from 5.8 to 6.0
- README expanded with MuSig2 usage examples (#560)
