# AGENTS.md (swift-secp256k1)

A Swift 6.1 wrapper around libsecp256k1 (and secp256k1-zkp) for the Bitcoin and Nostr ecosystems. Supports macOS 15+, iOS 18+, watchOS 11+, tvOS 18+, and visionOS 2+. Uses Swift 6 strict concurrency (`swiftLanguageModes: [.v6]`).

## Commands

- Build: `swift build`
- Test: `swift test`
- Format: `swift package swiftformat .` (dev checkout only)
- Lint: `swift package swiftlint` (dev checkout only)

## Non-obvious patterns

- **Conditional dev deps**: `Package.swift` uses `Context.gitInformation?.currentTag` to exclude dev tools (SwiftFormat, SwiftLint, Tuist, etc.) at tagged releases. Consumers get zero transitive dev dependencies. Format/lint/Tuist commands only work in a non-tagged checkout.
- **Xcode trait workaround**: Xcode does not resolve `.when(traits:)` for Swift settings. Source files use `#if Xcode || ENABLE_MODULE_*` guards — preserve these when editing.
- **SharedSourcesPlugin**: Copies `Sources/Shared/*.swift` into both P256K and ZKP build directories. Changes to shared files affect both targets.
- **Extraction flow**: Vendor → Sources via subtree CLI. Do not edit extracted paths directly; changes are overwritten on next extraction. See `Vendor/AGENTS.md`.

## Boundaries

- **Never**: emit private keys or sensitive material; weaken constant-time code in vendored C sources; edit files under `Vendor/` directly; bypass Lefthook formatting/linting hooks.
- **Ask first**: add new third-party dependencies; broaden CI permissions.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for code style, branching, and commit guidelines. See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Scoped guidance

Directory-specific `AGENTS.md` files provide additional context:

- `Sources/AGENTS.md` — shared sources, extraction paths
- `Tests/AGENTS.md` — test framework, trait-guarded tests
- `Projects/AGENTS.md` — Tuist-managed XCFramework builds
- `Vendor/AGENTS.md` — vendored dependencies and subtree sync rules
- `.github/AGENTS.md` — CI workflows and Actions security policy

## Maintenance

- Keep scoped `AGENTS.md` files limited to deltas; avoid duplicating root guidance.
- Update when build/test workflows, toolchain versions, or CI runners change.
