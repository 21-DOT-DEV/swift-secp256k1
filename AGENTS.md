# AGENTS.md (swift-secp256k1)

A Swift 6.1 wrapper around libsecp256k1 (and secp256k1-zkp) for the Bitcoin and Nostr ecosystems. Supports macOS 15+, iOS 18+, watchOS 11+, tvOS 18+, and visionOS 2+. Uses Swift 6 strict concurrency (`swiftLanguageModes: [.v6]`).

## Commands

- Build: `swift build`
- Test: `swift test`
- Format: `swift package swiftformat .` (dev checkout only)
- Lint: `swift package swiftlint` (dev checkout only)
- Install Lefthook hooks (one-time, dev checkout only): `lefthook install`

## Non-obvious patterns

- **Conditional dev deps**: `Package.swift` uses `Context.gitInformation?.currentTag` to exclude dev tools (SwiftFormat, SwiftLint, Tuist, etc.) at tagged releases. Consumers get zero transitive dev dependencies. Format/lint/Tuist commands only work in a non-tagged checkout.
- **Xcode trait workaround**: Xcode does not resolve `.when(traits:)` for Swift settings. Source files use `#if Xcode || ENABLE_MODULE_*` guards — preserve these when editing.
- **SharedSourcesPlugin**: Copies `Sources/Shared/*.swift` into both P256K and ZKP build directories. Changes to shared files affect both targets.
- **Extraction flow**: Vendor → Sources via subtree CLI. Do not edit extracted paths directly; changes are overwritten on next extraction. See `Vendor/AGENTS.md`.
- **Cross-archive DocC xrefs**: `SharedSourcesPlugin` copies the same source into P256K and ZKP archives, so disambiguation hashes (`signature(for:)-XXXXX`) differ per archive. Prefer unqualified `` `signature(for:)` `` code spans in `///` doc comments over symbol xrefs that would need per-archive hashes. See precedent in `Sources/Shared/HashDigest.swift`, `Sources/Shared/ECDSA/ECDSA+Signature.swift`.
- **No `Snippets/` directory**: SwiftPM auto-discovered snippets (SE-0356) link every library product of the package. With two C-binding products (`libsecp256k1`, `libsecp256k1_zkp`) compiled from the same upstream source tree, any snippet produces duplicate C symbols at link time. Scoped snippet dependencies are a future direction per SE-0356; until SwiftPM ships them, documentation examples live as fenced ` ```swift` blocks inside catalog articles. Parked snippet sources from prior DocC work remain at `/tmp/swift-secp256k1-snippets-pending/P256K/` for future re-integration.

## Code Style

Code is formatted and linted automatically via pre-commit hooks:

- **SwiftFormat** — `.swiftformat` config (4-space indentation, LF line breaks, alphabetized imports)
- **SwiftLint** — `.swiftlint.yml` config (140-char line length, extensive opt-in rules)
- **Lefthook** — runs both tools as git hooks. After cloning, run `lefthook install` to activate.

## Boundaries

- **Never**: emit private keys or sensitive material; weaken constant-time code in vendored C sources; edit files under `Vendor/` directly; bypass Lefthook formatting/linting hooks.
- **Ask first**: add new third-party dependencies; broaden CI permissions.
- See the [21-DOT-DEV contributing guidelines](https://github.com/21-DOT-DEV/.github/blob/main/CONTRIBUTING.md) for branching and commit guidelines. See [SECURITY.md](SECURITY.md) for vulnerability reporting.

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
