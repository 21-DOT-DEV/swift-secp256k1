# AGENTS.md (Projects)

This directory contains Tuist-managed targets for additional validation (including XCFramework workflows).

## Generate the Xcode project

```bash
swift package --disable-sandbox tuist generate -p Projects/ --no-open
```

## Preferred: Tuist build/test (matches CI)

```bash
swift package --disable-sandbox tuist build P256K -p Projects/ --platform ios
swift package --disable-sandbox tuist test XCFramework-Workspace -p Projects/ --platform ios
```

## Fallback: xcodebuild test (macOS)

```bash
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme <TargetName> -destination 'platform=macOS'
```

## Running libsecp256k1Tests (upstream C suite)

`libsecp256k1Tests` is a `.commandLineTool`, not a test bundle — `tuist test` and `xcodebuild test` will not run it. See `Projects/README.md` → "Run libsecp256k1Tests" for the build-and-execute commands.

## Notes

- Tuist is a conditional dev dependency — `swift package tuist ...` commands only work in a non-tagged checkout (see root `AGENTS.md` → Non-obvious patterns).
- Prefer updating `Projects/README.md` if the workflow changes.
