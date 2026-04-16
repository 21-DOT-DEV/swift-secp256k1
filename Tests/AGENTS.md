# AGENTS.md (Tests)

This directory contains SwiftPM test targets using **Swift Testing** (`import Testing`, `@Test`, `@Suite`, `#expect`).

## Non-obvious patterns

- Some test files also `import XCTest` alongside Swift Testing for APIs not yet available in Swift Testing — preserve both imports.
- Some test files are trait-guarded with `#if Xcode || ENABLE_MODULE_*` (e.g., `UInt256Tests.swift` uses `#if Xcode || ENABLE_UINT256`).

## Conventions

- Bug fixes should include a regression test.
- Keep test vectors and fixtures minimal and well-sourced.
- For Tuist/Xcode-based test targets, see `Projects/README.md`.
