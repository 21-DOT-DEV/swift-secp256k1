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

- [ ] T001 [P] Write `vendir.yml` — five `directories:` entries with `git:`
  sources per plan §3: `Sources/libsecp256k1` (+`COPYING` in includePaths,
  `depth: 1`, `ref: v0.7.1`), `Sources/libsecp256k1_zkp` (+`COPYING`,
  `ref: 08d1cd0…`, `depth: 0`), `Sources/Shared/swift-crypto` (+`LICENSE.txt`,
  `ref: 4.5.0`, `depth: 1`), `Projects/Sources/libsecp256k1Tests`
  (upstream-layout bundle, `depth: 1`, `excludePaths` drops the seven
  `main()`-carrying `src/*.c` and `src/wycheproof/*.json` per plan §3),
  `Projects/Resources/WycheproofTests/secp256k1` (two JSONs +
  `WYCHEPROOF_COPYING`, `newRootPath: src/wycheproof`, `depth: 1`);
  `ignorePaths` on each C-library entry names its `include/Utility.h` +
  `src/Utility.c` — vendir carries existing destination files across the wipe
  natively (on-disk bytes, so uncommitted edits too; research.md §2 verified);
  `legalPaths: []` everywhere; `minimumRequiredVersion: 0.46.1` · `vendir.yml`

**Checkpoint:** `vendir.yml` exists and parses — `vendir sync` resolves every
entry once the next group runs it; nothing downstream exists yet to break.

## The generated trees and their provenance

- [ ] T002 Run `vendir sync`; `git rm` the two `Vendor/`-backed JSON symlinks
  at `Projects/Resources/WycheproofTests/` (vendir owns only the new
  `secp256k1/` subdir — removing the stale links here keeps every commit
  buildable); `diff -r` each destination against the pre-migration tree —
  expect empty modulo the new `COPYING`/`LICENSE.txt` files, the removed
  symlink pair, and the two new `Projects/` destinations, where the three
  `libsecp256k1Tests` symlinks
  become real files (vendir deletes the symlinks itself when it wipes its
  path) · vendored paths
- [ ] T003 Track `vendir.lock.yml`; `.gitignore` gains `.vendir-tmp*` — the
  lock is the provenance record and Renovate's prerequisite · `vendir.lock.yml`,
  `.gitignore`

**Checkpoint:** every vendored destination reproduces byte-for-byte (modulo
the declared license/symlink deltas), and `vendir.lock.yml` pins a
resolved SHA for each of the five entries.

## Consumers re-pointed at the new trees

- [ ] T004 `Package.swift`: drop `swift-plugin-subtree` from
  `developmentDependencies`; add `exclude: ["COPYING"]` to the `libsecp256k1`
  and `libsecp256k1_zkp` targets (`Package.resolved` is gitignored — the
  plugin's transitive closure just leaves local resolution) · `Package.swift`
- [ ] T005 `Projects/Project.swift`: narrow `libsecp256k1Tests` sources to the
  three-file compile set `src/{tests,precomputed_ecmult,precomputed_ecmult_gen}.c`
  (why that pair and nothing else: plan §3); fix the "symlinked from
  Vendor/" comment; `WycheproofTests` resources glob unchanged (subdir is
  inside it) · `Projects/Project.swift`
- [ ] T006 `Projects/Resources/libsecp256k1Tests/Shared.xcconfig`:
  `HEADER_SEARCH_PATHS` repoint `$(SRCROOT)/../Vendor/secp256k1{,/src,/include}`
  → `$(SRCROOT)/Sources/libsecp256k1Tests{,/src,/include}` (same triple —
  root serves `contrib/`, the rest cover `src/`/`include/`) ·
  `Projects/Resources/libsecp256k1Tests/Shared.xcconfig`
- [ ] T007 `xcframework-release.yml`: `cp Vendor/secp256k1/COPYING` →
  `Sources/libsecp256k1/COPYING` · `.github/workflows/xcframework-release.yml`

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
  plan-§3 lock-diff check); Boundaries now
  read "vendored paths under `Sources/`/`Projects/`", the patch guidance keeps
  its shape; add a vendir install line (`brew install carvel-dev/carvel/vendir`)
  to Commands · `AGENTS.md`
- [ ] T011 `Sources/AGENTS.md` extraction note points at `vendir.yml`;
  `Sources/Shared/README.md` Vendor reference updated; the
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
  path-filtered on `vendir*.yml`, the five vendored destinations, and the
  workflow itself; `ubuntu-slim`, `permissions: {}`, `env:` blocks per
  `.github/AGENTS.md`; `curl` + hard-coded `VENDIR_SHA256` + `sha256sum -c`
  install; run `vendir sync` then the scoped `git status --porcelain` check;
  note the gate in `.github/AGENTS.md`'s conventions list ·
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
- [ ] T018 Flip this spec's `status:` to `Implemented` at merge — the field
  records a repository fact, not a claim about checks

**Checkpoint:** merge-time only — index tables regenerated, the spec's status
reflects what the repository now does.
