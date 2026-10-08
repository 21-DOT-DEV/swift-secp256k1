# Tasks — 002 · Replace git-subtree vendoring with vendir

Ordered work for [the plan](./plan.md); measured evidence in
[research.md](./research.md).

Format: `- [x] TNNN [P?] what lands · files`. One checkbox is one reviewable
change — one commit-shaped unit inside this single pull request. `[P]` marks a
task with no prerequisites. **Group headers name the review slice** — the
section of the PR's diff a reviewer reads in one pass — and each closes on a
**checkpoint** stating what must be true before the next slice starts. An
authored diff over ~300 changed lines per commit or pull request gets split or
the task justifies why not — generated output (synced vendored trees,
`vendir.lock.yml`, the `Vendor/` deletion) is exempt from the count. The
maintainer's commit order inside the PR follows the groups, so `git log` reads
the same way. Tick the box in the same change that lands the task.

## The vendir config

- [x] T001 [P] Write `vendir.yml` — five `directories:` entries with `git:`
  sources per plan §3: `Sources/libsecp256k1` (+`COPYING` in includePaths,
  `depth: 1`, `ref: v0.7.1`), `Sources/libsecp256k1_zkp` (+`COPYING`,
  `ref: 08d1cd0…`, `depth: 0`), `Sources/Shared/swift-crypto` (+`LICENSE.txt`
  +`NOTICE.txt`, `ref: 4.5.0`, `depth: 1`), `Projects/Sources/libsecp256k1Tests`
  (upstream-layout bundle narrowed to the compilable `*.c`/`*.h` closure plus
  `contrib/lax_der_*` — the filter itself keeps build-system files and the
  vector JSONs out — +`COPYING`/`WYCHEPROOF_COPYING`, `depth: 1`,
  `excludePaths` drops the seven `main()`-carrying `src/*.c` per plan §3),
  `Projects/Resources/WycheproofTests/secp256k1` (`src/wycheproof/*.json` —
  globbed so future upstream vectors ride ref bumps — plus
  `WYCHEPROOF_COPYING`, `newRootPath: src/wycheproof`, `depth: 1`);
  `ignorePaths` on each C-library entry names its `include/Utility.h` +
  `src/Utility.c` — vendir carries existing destination files across the wipe
  natively (on-disk bytes, so uncommitted edits too; research.md §2 verified);
  `legalPaths: []` everywhere; the three secp256k1 refs share one
  `&secp256k1-ref` YAML anchor (vendir 0.46.2 and Renovate 44.142.1 both
  verified — research.md §4/§5); `skipInitSubmodules: true` on all five
  (vendir runs `git submodule update --init --recursive` by default; no
  upstream has a `.gitmodules`, so output is unchanged and a future
  submodule can't widen the sync); `minimumRequiredVersion: 0.46.2`
  · `vendir.yml` *(the `libsecp256k1Tests` entry was narrowed to the
  deduplicated header-tree shape by T002 — see its task text)*

**Checkpoint:** `vendir.yml` exists and parses — parse-clean only, since
vendir drops unknown keys silently; §3's key-allowlist check is the real
validator. `vendir sync` resolves every entry once the next group runs it;
nothing downstream exists yet to break.

## The generated trees and their provenance

- [x] T002 Amend `vendir.yml`'s `libsecp256k1Tests` entry to the deduped
  shape — the complete header tree (`include/**/*.h`, `src/**/*.h`, which
  keeps upstream's relative-include topology resolving own-dir) plus the
  test-only `.c` harness (`src/tests.c`, `src/unit_test.c`,
  `contrib/lax_der_*`) — rather than the full compilable closure; the
  library's `.c` files resolve to the shipped tree (`secp256k1.c` via
  `HEADER_SEARCH_PATHS`, the two `precomputed_*.c` via the target's
  `sources:` list — folds T006's repoint in here so the checkpoint's suite
  run provably exercises shipped bytes). Run `vendir sync`; remove the two
  `Vendor/`-backed JSON symlinks at `Projects/Resources/WycheproofTests/`
  (vendir owns only the new `secp256k1/` subdir); narrow
  `Project.swift`'s `libsecp256k1Tests` `sources:` to three literal files
  (`Sources/libsecp256k1Tests/src/tests.c` +
  `../Sources/libsecp256k1/src/precomputed_ecmult{,_gen}.c` — a `**` glob
  would compile vendored-but-inert `unit_test.c`/`lax_der_*.c` on top of
  `tests.c`'s text-includes and the link fails on duplicate symbols) and
  fix its "symlinked from Vendor/" comment; add `exclude: ["COPYING"]` to
  both C targets in `Package.swift` — the sync drops `COPYING` inside both
  target roots and an un-excluded file warns on every build; `diff -r`
  each destination against the pre-migration tree — verified: zero
  modified tracked files, plus exactly the declared additions (the three
  `libsecp256k1Tests` symlinks were deleted by vendir's wipe itself) ·
  vendored paths, `vendir.yml`, `Projects/Project.swift`,
  `Projects/Resources/libsecp256k1Tests/Shared.xcconfig`, `Package.swift`
- [x] T003 _Folded into T002 — `vendir.lock.yml` is the provenance record
  of the same `vendir sync`; committing it apart would leave a commit
  whose vendored trees have no in-history provenance (`vendir sync
  --locked` cannot reproduce them). Tick this box in T002's commit._ ·
  `vendir.lock.yml`, `.gitignore`

**Checkpoint:** every vendored destination reproduces byte-for-byte (modulo
the declared license/symlink deltas), `vendir.lock.yml` pins a
resolved SHA for each of the five entries, and `tuist generate`, a
`libsecp256k1Tests` build, and a `WycheproofTests` run are green — the run
proves the vendored JSONs flatten into the test bundle's root, which
`TestVectorLoader` (`forResource:` with no subdirectory) depends on (T002
landed the narrowing) — and `swift build` emits no unhandled-file
warnings (T002's `exclude: ["COPYING"]`). *Verified 2026-10-08: zero
modified tracked files; upstream suite exits 0 in ~216s against the
shipped tree; Wycheproof 7/7.*

## Consumers re-pointed at the new trees

- [ ] T004 `Package.swift`: drop `swift-plugin-subtree` from
  `developmentDependencies` (`Package.resolved` is gitignored — the
  plugin's transitive closure just leaves local resolution); the
  `exclude: ["COPYING"]` lines landed back in T002 — the sync puts `COPYING`
  inside both target roots and SPM warns on unexcluded files · `Package.swift`
- [x] T005 _Folded into T002 — the `Project.swift` sources narrowing must land
  in the same commit as the tree it scopes, or that commit doesn't build;
  tick this box in T002's commit.
  (`WycheproofTests` resources glob unchanged — the new subdir is inside it.)_
- [x] T006 _Folded into T002 — under the deduped bundle the repoint targets
  the shipped tree, not the bundle: `HEADER_SEARCH_PATHS` →
  `$(SRCROOT)/../Sources/libsecp256k1{,/src,/include}`. Landing it here is
  what lets the checkpoint's suite run prove the shipped-bytes claim rather
  than still resolving through `Vendor/`._ ·
  `Projects/Resources/libsecp256k1Tests/Shared.xcconfig`
- [ ] T007 `xcframework-release.yml`: `cp Vendor/secp256k1/COPYING` →
  `Sources/libsecp256k1/COPYING`; the same step also copies
  `Sources/Shared/swift-crypto/{LICENSE.txt,NOTICE.txt}` into the zip as
  `LICENSE-swift-crypto.txt`/`NOTICE-swift-crypto.txt`, and the unzip-verify
  step asserts both ship — the framework compiles swift-crypto code, so
  Apache-2.0 attribution belongs in the binary artifact (a compliance gap
  that predates this branch) · `.github/workflows/xcframework-release.yml`

**Checkpoint:** `swift build`, `swift test`, and `tuist generate` pass against
the new trees — every consumer path re-plumbed and the stale symlinks already
gone (T002), so `Vendor/` is now dead weight awaiting teardown.

## Teardown — `Vendor/`, `subtree.yaml`, the workflows

- [ ] T008 Delete `Vendor/` wholesale (~50MB tracked; the ~565MB `.build`
  under `Vendor/swift-crypto` is untracked) and `subtree.yaml` — history keeps
  both; the `Vendor/`-backed JSON symlinks are already gone (T002) · deletions
- [ ] T009 Delete `.github/workflows/update-subtree.yml` and
  `.github/workflows/check-subtree-updates.yml` — interim update recipe moves
  into `AGENTS.md` · deletions

**Checkpoint:** a repo-wide `Vendor/`/`subtree` search returns only doc
comments (swept next group) and history notes — nothing that resolves a path;
the two JSON symlinks are gone and the real files resolve; build still green.

## Docs and metadata

- [ ] T010 Root `AGENTS.md`: rewrite the "Extraction flow" bullet for vendir
  (config, `ignorePaths`-preserved shims, manual bump recipe on
  `vendor/<name>-<ref>` branches with the `dependencies` label — include the
  plan-§3 lock-diff check, and note `minimumRequiredVersion` is a floor:
  run the version `vendir-check.yml` pins, since a newer release's lock
  format could drift; and warn that `vendir sync` deletes files in managed
  paths not covered by `ignorePaths` — anything uncommitted there doesn't
  survive); Boundaries now
  read "vendored paths under `Sources/`/`Projects/`", the patch guidance keeps
  its shape; add a vendir install line (`brew install carvel-dev/carvel/vendir`)
  to Commands · `AGENTS.md`
- [ ] T011 `Sources/AGENTS.md` extraction note points at `vendir.yml`;
  `Sources/Shared/README.md` Vendor reference updated, plus a `*.swift`-only
  invariant: `swift-crypto/`'s `LICENSE.txt`/`NOTICE.txt` stay inert only
  because the plugin copies `*.swift` — any SharedSourcesPlugin replacement
  must keep that filter; the
  `Vendor/AGENTS.md` drift-check runbook folds into `Sources/AGENTS.md` as
  "locate the original via `gh api repos/<repo>/contents/<path>?ref=<tag>`" ·
  `Sources/AGENTS.md`, `Sources/Shared/README.md`
- [ ] T012 `Development/constitution.md` dev-deps list drops
  `swift-plugin-subtree` (§Development only bullet) · `Development/constitution.md`
- [ ] T013 `.gitattributes`: drop the `Vendor/**` and `subtree.yaml` lines;
  `vendir.yml` + `vendir.lock.yml` gain `export-ignore` (the lock also
  `linguist-generated` — same shape as `subtree.yaml`/`Package.resolved`);
  mark `Projects/Sources/libsecp256k1Tests/**`,
  `Projects/Resources/WycheproofTests/secp256k1/**`, and
  `Sources/Shared/swift-crypto/**` linguist-vendored (the last closes a
  pre-existing gap — the tree was vendored under subtree but never marked);
  `.swiftformat` / `.swiftlint.yml` drop `--exclude Vendor/**` /
  `- Vendor/**` (the `**/swift-crypto/**` excludes stay) · `.gitattributes`,
  `.swiftformat`, `.swiftlint.yml`
- [ ] T014 Rewrite the 36 `Vendor/…` doc-comment mentions across
  `Sources/Shared/**` and `Projects/Sources/SecurityTests/` to
  upstream-relative references (`secp256k1 v0.7.1, src/…`) — mechanical
  sweep, no wording judgment calls — and add the migration's `CHANGELOG.md`
  `[Unreleased]` entry · `Sources/Shared/**`, `Projects/Sources/**`,
  `CHANGELOG.md`

**Checkpoint:** docs tell the vendir story consistently — `vale Development/`
clean, and no doc comment or guide references `Vendor/` outside history notes.

## The CI gate

- [ ] T015 [P] Add `.github/workflows/vendir-check.yml` per plan §3 —
  `ubuntu-slim`, `permissions: {}`, `persist-credentials: false` on
  checkout, `env:` blocks per `.github/AGENTS.md`;
  `curl` + hard-coded `VENDIR_SHA256` + `sha256sum -c` install; trigger on
  PRs touching `vendir*.yml`, the five vendored destinations, or the
  workflow itself, plus the weekly `schedule:` and `workflow_dispatch:`.
  The six checks are §3's verbatim — remote-resolution before the sync,
  `yq 'explode(.)'` for all config/lock *value* reads (the allowlist
  scans keys un-exploded — that also catches `<<:` merge keys),
  `--ignored=matching` on
  the porcelain check. Switch `vendir.yml`'s future-tense gate comments
  ("lands later", "will pin/assert/guard") to present tense; note the
  gate in
  `.github/AGENTS.md`'s conventions list ·
  `.github/workflows/vendir-check.yml`, `.github/AGENTS.md`

**Checkpoint:** the gate exercises itself — this PR touches `vendir.yml` and the
vendored paths, so `vendir-check.yml` ran on it and passed (advisory, not
required).

## Verification and merge

- [x] T016 [P] Spec 001 housekeeping: `status: In Progress` → `Implemented`,
  `updated:` → merge date, tick its T018; regenerate both index tables with
  `swift run --package-path Development/Tools plans`; confirm `--check` exits
  clean · `Development/Specs/001-development-docs/{plan,tasks}.md`,
  `Development/{Specs,ADRs}/README.md`
- [ ] T017 Full verification sweep per plan §5 — root `swift build`/`swift test`,
  Tuist generate + `libsecp256k1Tests` run, Wycheproof resource lookup,
  `vendir-check.yml` red/green on a stale-or-untracked-extraction probe,
  `plans --check` + `vale Development/` clean
- [ ] T018 Flip this spec's `status:` to `Implemented` and
  `Development/Roadmap/README.md`'s vendir-migration row to ✅ at merge —
  the field records a repository fact, not a claim about checks

**Checkpoint:** merge-time only — index tables regenerated, the spec's status
reflects what the repository now does.
