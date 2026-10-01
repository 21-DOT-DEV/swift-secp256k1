# AGENTS.md (Tests)

This directory contains SwiftPM test targets using **Swift Testing** (`import Testing`, `@Test`, `@Suite`, `#expect`).

## Non-obvious patterns

- Some test files also `import XCTest` alongside Swift Testing for APIs not yet available in Swift Testing — preserve both imports.
- Some test files are trait-guarded with `#if Xcode || ENABLE_MODULE_*` (e.g., `UInt256Tests.swift` uses `#if Xcode || ENABLE_UINT256`).
- `XCFrameworkTests/` has no target in the root manifest by design — it compiles only via `Scripts/XCFrameworkTest/Package.swift`, which `Scripts/verify-p256k-xcframework.sh` stages to test the prebuilt `P256K.xcframework` binary target. Keep its `moduleDefines`/target settings in sync with the root `Package.swift`.

## Conventions

- Bug fixes should include a regression test.
- Keep test vectors and fixtures minimal and well-sourced.
- For Tuist/Xcode-based test targets, see `Projects/README.md`.
