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

- [x] T004 `Package.swift`: drop `swift-plugin-subtree` from
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
- [x] T007 `xcframework-release.yml`: `cp Vendor/secp256k1/COPYING` →
  `Sources/libsecp256k1/COPYING`; the same step also copies
  `Sources/Shared/swift-crypto/{LICENSE.txt,NOTICE.txt}` into the zip as
  `LICENSE-swift-crypto.txt`/`NOTICE-swift-crypto.txt`, and the unzip-verify
  step asserts all four license files ship non-empty and `cmp`s the three
  renamed copies against the vendored sources — the framework compiles
  swift-crypto code, so Apache-2.0 attribution belongs in the binary
  artifact (a compliance gap that predates this branch) ·
  `.github/workflows/xcframework-release.yml`

**Checkpoint:** `swift build`, `swift test`, and `tuist generate` pass against
the new trees — every consumer path re-plumbed and the stale symlinks already
gone (T002), so `Vendor/` is now dead weight awaiting teardown.

## Teardown — `Vendor/`, `subtree.yaml`, the workflows

- [x] T008 Delete `Vendor/` wholesale (~50MB tracked; the ~565MB `.build`
  under `Vendor/swift-crypto` is untracked) and `subtree.yaml` — history keeps
  both; the `Vendor/`-backed JSON symlinks are already gone (T002) ·
  deletions + dead-pointer strips in `AGENTS.md`, `Sources/AGENTS.md`, and
  `Sources/Shared/README.md` (no commit references a file it deletes)
- [x] T009 Delete `.github/workflows/update-subtree.yml` and
  `.github/workflows/check-subtree-updates.yml` — interim update recipe moves
  into `AGENTS.md` · deletions + remote cleanup (orphaned
  `subtree/secp256k1-zkp-*` branches on `origin`, closed PRs #1095/#1111,
  deleted 2026-10-08)

**Checkpoint:** a repo-wide `Vendor/`/`subtree` search returns only doc
comments (swept next group), dead config globs (dropped in T013), and
history notes — nothing resolves a path and no guide points at a deleted
file; the two JSON symlinks are gone and the real files resolve; build still
green. *Verified 2026-10-08: `swift build` + `swift test` green (39/39); the
sweep's only non-history matches are the scheduled T013/T014 leftovers.*

## Docs and metadata

- [x] T010 Root `AGENTS.md`: rewrite the "Extraction flow" bullet for vendir
  (config, `ignorePaths`-preserved shims, manual bump recipe on
  `vendor/<dep>-<ref>` branches with the `dependencies` label — include the
  plan-§3 lock-diff check, and note `minimumRequiredVersion` is a floor:
  run the version `vendir-check.yml` pins, since a newer release's lock
  format could drift; and warn that `vendir sync` deletes files in managed
  paths not covered by `ignorePaths` — anything uncommitted there doesn't
  survive); Boundaries now
  read "vendored paths under `Sources/`/`Projects/`", the `Vendor/AGENTS.md`
  Scoped-guidance bullet is dropped, and the vendored-code patch
  procedure moves to `Sources/AGENTS.md` (T011); add a vendir install
  line (`brew install carvel-dev/carvel/vendir`)
  to Commands *(the dead `Vendor/`/`subtree.yaml` pointers in the three
  guide files were already stripped and minimally repointed in the teardown
  commit — this task installs the vendir narrative, not stale-text removal)* ·
  `AGENTS.md`
- [x] T011 `Sources/AGENTS.md` extraction note points at `vendir.yml`;
  `Sources/Shared/README.md` Vendor reference updated, plus a `*.swift`-only
  invariant: `swift-crypto/`'s `LICENSE.txt`/`NOTICE.txt` stay inert only
  because the plugin copies `*.swift` — any SharedSourcesPlugin replacement
  must keep that filter; the
  `Vendor/AGENTS.md` drift-check runbook folds into `Sources/AGENTS.md` as
  "locate the original via `gh api repos/<repo>/contents/<path>?ref=<tag>`",
  and its "If you must patch" procedure folds too, vendir-adapted — a
  `vendir sync` wipes managed paths outside `ignorePaths`, so prefer
  upstreaming plus a `ref:` bump; a committed patch survives in history but
  the tree loses it on every sync, and moving a file into `ignorePaths`
  makes it shadow all future upstream changes
  *(both files' dead `subtree.yaml`/`Vendor/swift-crypto` pointers were
  already repointed to `vendir.yml` in the teardown commit)* ·
  `Sources/AGENTS.md`, `Sources/Shared/README.md`
- [x] T012 `Development/constitution.md` dev-deps list drops
  `swift-plugin-subtree` (§Development only bullet) · `Development/constitution.md`
- [x] T013 `.gitattributes`: drop the `Vendor/**` and `subtree.yaml` lines;
  `vendir.yml` + `vendir.lock.yml` gain `export-ignore` (the lock also
  `linguist-generated` — same shape as `subtree.yaml`/`Package.resolved`);
  mark `Projects/Sources/libsecp256k1Tests/**`,
  `Projects/Resources/WycheproofTests/secp256k1/**`, and
  `Sources/Shared/swift-crypto/**` linguist-vendored (the last closes a
  pre-existing gap — the tree was vendored under subtree but never marked);
  `.swiftformat` / `.swiftlint.yml` drop `--exclude Vendor/**` /
  `- Vendor/**` (the `**/swift-crypto/**` excludes stay) · `.gitattributes`,
  `.swiftformat`, `.swiftlint.yml`
- [x] T014 Rewrite the 36 `Vendor/…` doc-comment mentions across
  `Sources/Shared/**` and `Projects/Sources/SecurityTests/` to
  upstream-relative references (`secp256k1/include/…`,
  `secp256k1-zkp/include/…`, `secp256k1/src/…`) — mechanical
  sweep, no wording judgment calls — and add the migration's `CHANGELOG.md`
  `[Unreleased]` entry *(the "Dropped the scheduled trigger" line it was to
  fold in already shipped in 0.23.2 — release history stays untouched, so
  the entry stands alone; the shipped refs carry no version at all —
  `vendir.yml` owns the pins and a `v0.7.1` in every comment would rot on
  each ref bump — while markdown links keep their `master` URLs tracking
  living upstream)* ·
  `Sources/Shared/**`, `Projects/Sources/**`, `CHANGELOG.md`

**Checkpoint:** docs tell the vendir story consistently — `vale Development/`
clean, and no doc comment or guide references `Vendor/` outside history notes.

## The CI gate

- [ ] T015 _Split into T019–T026 on re-review — the gate grows
  incrementally rather than landing whole: the core sync check wires
  first (drift detection is the point; the rest is hardening), then each
  remaining check lands as a task-sized increment — script function +
  case arm + workflow step + the `vendir.yml` comment flip naming it —
  so every PR answers one question and the flakiest check can revert
  alone. The `OLD-VENDIR-MIGRATION` prototype's update machinery
  (`vendir-update.yml`, `sanitize-upstream-md`, `sanitizer-test.yml`)
  does not ship — update automation is re-recorded as a centralized
  org-repo updater per ADR 0007, and the base-SHA comparison plus the
  `gh api` on-default-branch probe are dropped (§3 records why); that
  branch stays in git as the edge-case reference. Tick this box in
  T026's PR._
- [x] T019 [P] `Scripts/vendir-check.sh` — the skeleton (check-name
  dispatch, shared helpers, `fail()`) plus §3's **sync** check
  (`vendir sync --locked` + `git status --porcelain --ignored=matching`
  over the five destinations + `vendir.lock.yml`); a bare run executes
  every check that exists, so the gate reproduces locally outside CI;
  bash-3.2-safe so it runs on macOS (local runs need `yq` —
  `brew install yq`); `yq 'explode(.)'` for all config/lock *value*
  reads; anonymous reads only — no token. Lands inert — nothing calls
  it until T020 · `Scripts/vendir-check.sh`
- [x] T020 `.github/workflows/vendir-check.yml` — `ubuntu-slim`,
  `permissions: {}`, `persist-credentials: false` on a SHA-pinned
  checkout (`9c091bb2…` = v7.0.0, the docc-release precedent — the
  supply-chain gate doesn't fetch its own tooling through a mutable
  tag), `env:` blocks per `.github/AGENTS.md`; `curl` + hard-coded
  `VENDIR_SHA256` + `sha256sum -c` install (the Vale precedent — the
  image already ships mikefarah `yq` 4.x and `git`, verified in its
  published toolset, so neither needs an install step); triggers on PRs
  *and pushes to main* touching `vendir*.yml`, the five vendored
  destinations, or the gate-machinery globs `Scripts/vendir-check*` and
  `.github/workflows/vendir-check*` (the push leg mirrors
  development-docs.yml — a direct push or merge skew surfaces at push
  time, not the next weekly run), plus weekly `schedule:` (comment
  notes GitHub's 60-day inactivity disable — §7) and
  `workflow_dispatch:`; one job with a named step per existing check —
  `resolve` then `sync`, each gated `if: ${{ !cancelled() }}` (the
  `${{ }}` is required — a leading `!` is a YAML tag, not expression
  text) so a failed verdict can't mask the next check's — the same
  run-all semantics a bare script run has locally — the gate is live
  from this PR.
  Flip `vendir.yml`'s version-floor comment ("will pin" → "pins in
  CI"), root `AGENTS.md`'s "until vendir-check.yml lands" line, and the
  script header's "(lands T020)" to present tense; note the gate in
  `.github/AGENTS.md`'s conventions list ·
  `.github/workflows/vendir-check.yml`, `vendir.yml`, `AGENTS.md`,
  `.github/AGENTS.md`, `Scripts/vendir-check.sh`
- [x] T021 _Folded into T020 + the T019 findings pass — the `resolve`
  check's script half (§3's remote resolution: `git ls-remote
  refs/tags/<ref>` + `^{}` peel per entry vs the lock's `sha:`) landed
  early there, since an unsynced `ref:` edit is the gate's core story
  and couldn't wait for the workflow to exist; its named step rides
  T020's job ("one step per existing check") rather than its own PR.
  Tick this box in T020's PR._
- [ ] T022 `allowlist` — script gains §3's key/value allowlist
  (un-exploded key scan catches `<<:` merge keys; `url:`/`path:` value
  pins) plus a workflow step, first in run order ·
  `Scripts/vendir-check.sh`, `.github/workflows/vendir-check.yml`
- [ ] T023 `locksha` — script gains §3's same-URL lock-SHA equality +
  workflow step + both `vendir.yml` lock-SHA comment flips — the anchor
  site (~line 23) and the test-bundle rationale (~line 127), "will
  assert"/"(lands later)" → present tense · `Scripts/vendir-check.sh`,
  `.github/workflows/vendir-check.yml`, `vendir.yml`
- [ ] T024 `ignorepaths` — script gains §3's exact-404 probe (429/5xx
  retried with backoff — anonymous `raw.` requests share runner-IP
  throttles) at the locked SHA + workflow step + `vendir.yml`
  ignorePaths comment flip.
  Kept alone deliberately — it is the flakiest check (live `curl`
  probes to three upstreams), so an independent revert never touches
  the core · `Scripts/vendir-check.sh`,
  `.github/workflows/vendir-check.yml`, `vendir.yml`
- [ ] T025 `Scripts/vendir-check-test.sh` — self-test for the gate:
  heredoc-built doctored `vendir.yml`/lock fixtures under `mktemp`,
  each a git repo (`git init` + a commit — the checks assert committed
  state, via `git show HEAD:` and `worktree add HEAD`), asserting each
  check fails when it should — including the 1-vs-2 exit split
  (findings vs could-not-run, and findings *dominate*: a run that both
  found drift and couldn't run a check still exits 1 — inside one check
  too, where a drifted entry plus an unreachable entry still fails) — and
  passes on the real tree. Entries sharing a `(url, ref)` are cached to
  one probe but must still *name* every affected path (a fixture whose
  two directories share a bad tag must fail both by name, not one).
  Fixture remotes can use `file://` URLs by exporting
  `VENDIR_CHECK_ALLOW_PROTOCOLS=file:https` — the script pins
  `GIT_ALLOW_PROTOCOL=https` for its own probes *and* vendir's fetches;
  the same knob widens past a `url.*.insteadOf` rewrite, so cover the
  preflight audit too: a `GIT_CONFIG_GLOBAL` fixture rewriting the
  fixture remote's scheme is flagged exit 2, while a rewrite for an
  unrelated host is ignored;
  plain bash — BATS would be a new test-framework dependency for one
  script, and new deps are an ask-first boundary. Lands inert —
  nothing calls it until T026 · `Scripts/vendir-check-test.sh`
- [ ] T026 `.github/workflows/vendir-check-test.yml` — `ubuntu-slim`,
  `permissions: {}`; runs the self-test on PRs touching
  `Scripts/vendir-check*` or `.github/workflows/vendir-check*`, plus a
  `schedule:`/`workflow_dispatch:` (the old prototype's
  `sanitizer-test.yml` shape, minus the perl). Tick T015 here ·
  `.github/workflows/vendir-check-test.yml`, `tasks.md` (T015 box)

**Checkpoint:** the gate exercises itself at every increment — every
gate-group PR touches `vendir.yml`, `Scripts/vendir-check*`, or
`.github/workflows/vendir-check*`, all inside the gate's trigger
globs, so `vendir-check.yml` runs on its own diff from T020's PR
onward and must pass (advisory, not required).

## Adjacent hardening

- [x] T027 `benchmark-pr.yml` fork-PR path per ADR 0007 — fork PRs get a
  read-only `GITHUB_TOKEN`, so the PR comment is gated to non-fork PRs
  and the comparison also lands in the job summary (no token needed);
  the regression verdict runs under `!cancelled()` so a comment-step
  failure can never mask it; the fork-PR/token convention is recorded
  in `.github/AGENTS.md` · `.github/workflows/benchmark-pr.yml`,
  `.github/AGENTS.md`
- [x] T028 `PlanIndexTests` zero-padded-refs contract test —
  `supersedes: [0006, 0008, 0010]` decodes `[6, 8, 10]` in decimal
  through the Codable path, locking the parse contract this spec's
  zero-padded ADR references ride ·
  `Development/Tools/Tests/PlanIndexTests/PlanIndexTests.swift`
- [ ] T029 [P] `vendir-check` executable target in `Development/Tools` —
  a thin `main.swift` that locates `Scripts/vendir-check.sh` via
  `git rev-parse --show-toplevel` run at the running binary's own
  resolved path first (`Bundle.main.executableURL` — never
  `CommandLine.arguments[0]`, which can be relative or a bare PATH
  name), falling back to the caller's cwd, and `execv`s
  `Scripts/vendir-check.sh` with the forwarded args — a real exec, not
  `Process`, so signals and exit codes pass through untouched (`execv`
  takes an absolute path and never searches `PATH` — resolve the script
  first); `VENDIR_CHECK_ROOT` is forwarded untouched — it names the repo
  under test (a T025 fixture carries no `Scripts/`), never the script's
  home:
  `swift run --package-path Development/Tools vendir-check` becomes
  the local entry point matching `plans`, while CI keeps calling the
  script bare (`ubuntu-slim` ships no Swift toolchain — the wrapper can
  never be the gate's call site). Long term the executable *replaces*
  the script: the checks migrate into Swift one at a time as a follow-up
  (break that port out as its own task once this lands — the stable
  `vendir-check` name means callers never notice the swap). The script
  stays at `Scripts/` —
  `Development/**` is `export-ignore` + `linguist-vendored` (source
  archives drop it, diffs collapse it) and `development-docs.yml`
  fires on every `Development/` edit. No new package deps, no
  `PlanIndex` dep; a `vendir-check-test` sibling for T025's self-test
  may ride the same wrapper pattern if wanted ·
  `Development/Tools/Package.swift`,
  `Development/Tools/Sources/vendir-check/main.swift`

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
