# AGENTS.md (Sources)

This directory contains the library implementation (Swift targets and C bindings).

## What lives here

- Swift targets:
  - `P256K` and `ZKP`
  - shared Swift support code
- C binding targets:
  - `libsecp256k1`
  - `libsecp256k1_zkp`

## Key gotchas

- This package uses **SwiftPM traits** to enable/disable secp256k1 modules.
- Xcode does not resolve `.when(traits:)` for Swift settings; Swift sources use `#if Xcode || ENABLE_MODULE_*` guards as a workaround.

## Extractions

Some paths under `Sources/` are generated via extraction from vendored upstream sources. Before making changes in these areas, check `subtree.yaml` to confirm the extraction mapping and avoid unintended divergence:

- `Sources/libsecp256k1/`
- `Sources/libsecp256k1_zkp/`
- `Sources/Shared/swift-crypto/`

## Validation

- Run `swift test` after changes.
