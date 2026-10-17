# AGENTS.md (swift-secp256k1)

A Swift 6.1 wrapper around libsecp256k1 (and secp256k1-zkp) for the Bitcoin and Nostr ecosystems. Supports macOS 15+, iOS 18+, watchOS 11+, tvOS 18+, and visionOS 2+. Uses Swift 6 strict concurrency (`swiftLanguageModes: [.v6]`).

## Commands

- Build: `swift build`
- Test: `swift test`
- Format: `swift package swiftformat .` (dev checkout only)
- Lint: `swift package swiftlint` (dev checkout only)
- Install Lefthook hooks (one-time, dev checkout only): `lefthook install`
- Install vendir (needed only to re-sync vendored sources): `brew install carvel-dev/carvel/vendir` — it tracks latest, so check `vendir version` against the pinned version named in "Extraction flow" below (exact binaries live on the vendir GitHub releases page)
- Vendored-tree freshness gate: `Scripts/vendir-check.sh [check ...]` (bare run = all checks; needs vendir + yq). `allowlist` fails `vendir.yml` on keys or values outside the declared set (vendir drops unknown keys silently); `resolve` asserts each committed `ref:` resolves upstream to the lock's SHA (an unsynced `ref:` edit fails named); `sync` runs `vendir sync --locked` in a throwaway worktree of HEAD, then asserts a clean porcelain over the managed paths; `locksha` fails when entries sharing a `git.url` record different lock SHAs — the backstop for a literal typed in place of the shared `&secp256k1-ref` alias; `ignorepaths` probes `raw.githubusercontent.com` at each locked SHA and fails when a declared `ignorePaths` path exists upstream — the tripwire for a future upstream file being silently shadowed by a preserved shim (entries probe under `newRootPath/` when the contents entry re-roots; exact-404-only pass, and only after an "anchor" file committed outside the ignore list answers 2xx — a dead pin 404s identically to an absent file; an entry naming a committed directory is a local finding; 429/5xx and transport trouble retried via curl's own backoff, then reported couldn't-verify). All five assert committed state (HEAD, not the working tree) — safe on a dirty working tree, but useless as a pre-commit hook. Exit 0 clean / 1 any drift found (dominates) / 2 nothing found but a check couldn't run.
- Vendored-tree gate self-test: `Scripts/vendir-check-test.sh [substring]` — exercises `vendir-check.sh` against committed `mktemp` git fixtures (a PATH-stubbed spy `curl` covers the `ignorepaths` verdict branches hermetically; `file://` fixture remotes run under a per-case `VENDIR_CHECK_ALLOW_PROTOCOLS=file:https` widening), then asserts the gate passes on the real tree. `VENDIR_CHECK_TEST_OFFLINE=1` shrinks the real-tree leg to `allowlist locksha` for networkless runs.

## Non-obvious patterns

- **Conditional dev deps**: `Package.swift` uses `Context.gitInformation?.currentTag` to exclude dev tools (SwiftFormat, SwiftLint, Tuist, etc.) at tagged releases. Consumers get zero transitive dev dependencies. Format/lint/Tuist commands only work in a non-tagged checkout.
- **Xcode trait workaround**: Xcode does not resolve `.when(traits:)` for Swift settings. Source files use `#if Xcode || ENABLE_MODULE_*` guards — preserve these when editing.
- **SharedSourcesPlugin**: Copies `Sources/Shared/*.swift` into both P256K and ZKP build directories. Changes to shared files affect both targets. SPM plugin constraints that shaped it: prebuild commands cannot run executables built from the same package, plugin output directories do not recursively include subdirectories (hence the flattening), and build/CI shell steps prefer POSIX `find`/`cp`/`sh` over `rsync`/`install` — Linux and Docker images do not guarantee the latter.
- **Extraction flow**: upstream sources sync straight into `Sources/`/`Projects/` via vendir (`vendir.yml`, resolved SHAs in `vendir.lock.yml`) — five `git:` sources across three upstreams. Do not edit vendored paths directly: `vendir sync` wipes each managed path before copying, and only `ignorePaths` files — the four `Utility.{h,c}` shims — are carried across; uncommitted work elsewhere in a managed path is deleted. Bumping a pin is manual until the centralized org updater lands (ADR 0007): edit `ref:` → `vendir sync` → check the `vendir.lock.yml` diff (sync re-resolves every entry, so only the bumped dep's `sha:`s should move — the three secp256k1 entries share one YAML anchor and move in lockstep) → run the `libsecp256k1Tests` suite (see "Run libsecp256k1Tests" in `Projects/README.md`) → commit → PR on `vendor/<dep>-<ref>` with the `dependencies` label. `minimumRequiredVersion` is a floor, not a pin — run exactly `vendir` 0.46.2, the floor `vendir.yml` declares and the version `.github/workflows/vendir-check.yml` pins in CI; a newer release's lock format could drift.
- **Swift version compatibility**: `swift-tools-version` in `Package.swift` is the authoritative minimum — that is what SPM enforces. Read historical versions without checking out via `git show "<tag>:Package.swift"`. Do not build-test old toolchains to determine compatibility; older toolchains can fail against modern macOS SDKs for reasons unrelated to the package.
- **Cross-archive DocC xrefs**: `SharedSourcesPlugin` copies the same source into P256K and ZKP archives, so disambiguation hashes (`signature(for:)-XXXXX`) differ per archive. Prefer unqualified `` `signature(for:)` `` code spans in `///` doc comments over symbol xrefs that would need per-archive hashes. See precedent in `Sources/Shared/HashDigest.swift`, `Sources/Shared/ECDSA/ECDSA+Signature.swift`.
- **No `Snippets/` directory**: SwiftPM auto-discovered snippets (SE-0356) link every library product of the package. With two C-binding products (`libsecp256k1`, `libsecp256k1_zkp`) compiled from the same upstream source tree, any snippet produces duplicate C symbols at link time. Scoped snippet dependencies are a future direction per SE-0356; until SwiftPM ships them, documentation examples live as fenced ` ```swift` blocks inside catalog articles. Parked snippet sources from prior DocC work remain at `/tmp/swift-secp256k1-snippets-pending/P256K/` for future re-integration.
- **XCFramework toolchain pins**: The P256K XCFramework is built on Xcode 27 in both pipelines — Bitrise stack `osx-xcode-27.0.x`, GitHub image label `xcode-27` + `DEVELOPER_DIR=/Applications/Xcode_27.0.app/Contents/Developer`. Xcode 27's interface emitter writes the `P256K::P256K` module-selector spelling for the `enum P256K`/module `P256K` name collision (swiftlang#56573), pinned explicitly via `-enable-module-selectors-in-module-interface` in Release.xcconfig; binary consumers need Swift ≥6.3 to read it (the `P256K::` selectors fail pre-6.3 frontends). Interfaces ship exactly as the compiler writes them — no post-edit: `SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT` (Shared.xcconfig, matching Package.swift's upcoming features) keeps `import libsecp256k1` out of the public interface, and `-verify-emitted-module-interface` (Release.xcconfig — required because `SWIFT_INSTALL_OBJC_HEADER = YES` would otherwise force `-no-verify-emitted-module-interface`) typechecks every emitted interface during the archive itself — it typechecks against the build's own search paths, so it can't show what a consumer can import; the verifier's consumer builds prove that, since they have no `libsecp256k1` module. `Scripts/verify-p256k-xcframework.sh` is the second always-run gate: per-slice/per-arch export allowlist (leaked `_secp256k1_*` symbols bind silently to a consumer's own libsecp256k1 under `-dead_strip`; the prelink already whitelists exports via `Projects/Resources/P256K/exported-symbols.txt` — `_$s*` + `_P256KVersion*` only — so the gate tripwires the same contract rather than being the only defense) plus a real consumer build of the shipped artifact for every shipped platform — `swift test` on macOS and `xcodebuild build-for-testing` per platform in the caller's archive list, using the `Tests/XCFrameworkTests` suite and its zero-dependency manifest (`Scripts/XCFrameworkTest/Package.swift`).

## Code Style

Code is formatted and linted automatically via pre-commit hooks:

- **SwiftFormat** — `.swiftformat` config (4-space indentation, LF line breaks, alphabetized imports)
- **SwiftLint** — `.swiftlint.yml` config (140-char line length, extensive opt-in rules)
- **Lefthook** — runs both tools as git hooks. After cloning, run `lefthook install` to activate.

## Boundaries

- **Never**: emit private keys or sensitive material; weaken constant-time code in vendored C sources; edit vendored paths under `Sources/`/`Projects/` directly; bypass Lefthook formatting/linting hooks; stage or commit changes — leave the working tree unstaged for maintainer review (the maintainer commits manually, or an explicit instruction may say to commit).
- **Ask first**: add new third-party dependencies; broaden CI permissions.
- See the [21-DOT-DEV contributing guidelines](https://github.com/21-DOT-DEV/.github/blob/main/CONTRIBUTING.md) for branching and commit guidelines. See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Planning artifacts

Everything about how this project is developed lives under
[`Development/`](Development/README.md): the charter (`constitution.md`), the phase plan
(`Roadmap/`), one `plan.md` per feature (`Specs/`), and the decision records (`ADRs/`).
That folder's README is authoritative for what goes where and this file does not repeat
it.

Three rules are worth knowing before writing anything there. A plan is **corrected in
place** when review changes its design, never appended to with a note saying an earlier
section is now wrong. A decision that outlives its feature becomes an ADR. Plans carry
no status log, review log, or round-by-round history. And work decomposes into
**reviewable chunks** — task groups close on checkpoints, and an authored diff over
~300 changed lines per commit or pull request gets split or justified; generated
output (vendored trees, lock files, bulk deletions, mechanical sweeps) is exempt
from the count. A coherent document set that can't be split — a spec and its
companions landing together, say — is a legitimate justification; name it in the
PR description.

## Scoped guidance

Directory-specific `AGENTS.md` files provide additional context:

- `Sources/AGENTS.md` — shared sources, extraction paths
- `Tests/AGENTS.md` — test framework, trait-guarded tests
- `Projects/AGENTS.md` — Tuist-managed XCFramework builds
- `.github/AGENTS.md` — CI workflows and Actions security policy

## Maintenance

- Keep scoped `AGENTS.md` files limited to deltas; avoid duplicating root guidance.
- Update when build/test workflows, toolchain versions, or CI runners change.
- Update when new phases from [`Development/Roadmap/`](Development/Roadmap/README.md) are completed.
- Plan non-trivial features as `Development/Specs/NNN-slug/plan.md`, starting from
  `Development/Specs/_template/plan.md`. A feature's status lives in that plan's frontmatter
  and nowhere else; the index tables are generated by `Development/Tools`
  (`swift run --package-path Development/Tools plans`).
