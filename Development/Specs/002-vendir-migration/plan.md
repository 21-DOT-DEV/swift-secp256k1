---
feature: 002
title: Replace git-subtree vendoring with vendir, deleting Vendor/ and the subtree tooling
phase: null
status: In Progress
updated: 2026-10-08
adrs: [0006]
---

# Replace git-subtree vendoring with vendir, deleting Vendor/ and the subtree tooling

A tooling migration, not a library change. vendir syncs the three vendored
upstreams straight into their final trees — `Sources/libsecp256k1/`,
`Sources/libsecp256k1_zkp/`, `Sources/Shared/swift-crypto/` — plus two new
`Projects/` destinations for test-only upstream files, replacing `subtree.yaml`,
the `swift-plugin-subtree` dev dependency, the two subtree update workflows, and
the `Vendor/` mirror directory. Where the reference migration in swift-openssl
kept subtree for its mirror and update loop, this spec retires subtree outright.
Update-PR automation is handled by Renovate in a follow-up PR; until then,
updates are a manual three-step recipe. Produces [ADR
0006](../../ADRs/0006-vendir-replaces-subtree-and-vendor-mirror.md). Ordered
work: [tasks.md](./tasks.md). Evidence and measured verification:
[research.md](./research.md).

## 1. Goal & success criteria

- `vendir sync` reproduces the three extracted trees byte-for-byte against git
  HEAD — the four project-owned `Utility.{h,c}` files are declared via
  `ignorePaths`, so vendir itself carries them (and any uncommitted edits)
  across the wipe, no wrapper — verified during planning with real syncs
  against all three upstreams ([research.md](./research.md) §2).
- Retired and deleted: `Vendor/` (~50MB tracked), `subtree.yaml`,
  `.github/workflows/update-subtree.yml`,
  `.github/workflows/check-subtree-updates.yml`, and the `swift-plugin-subtree`
  dev dependency.
- `Vendor/`'s two live consumers move to vendir-managed destinations: the
  C test-runner symlinks at `Projects/Sources/libsecp256k1Tests/` become a
  deduplicated vendored bundle in upstream layout — the complete header
  tree plus the test-only translation units (`src/tests.c`,
  `src/unit_test.c`, `contrib/lax_der_*`) — while the library's `.c`
  files resolve to the shipped tree (`secp256k1.c` via
  `HEADER_SEARCH_PATHS`, the two `precomputed_*.c` as literal `sources:`
  entries), so the suite exercises the bytes the package ships instead of
  a ~3.4MB twin; the Wycheproof JSON symlinks become real files under
  `Projects/Resources/WycheproofTests/secp256k1/` — the `Vendor/`-backed
  symlinks themselves get removed in the same change — and
  `xcframework-release.yml` reads `COPYING` from `Sources/libsecp256k1/COPYING`,
  and its zip step gains swift-crypto's `LICENSE.txt`/`NOTICE.txt` — the
  framework compiles that code, so Apache-2.0 attribution belongs in the
  binary artifact (a gap that predates this branch).
- Provenance lives in a committed `vendir.lock.yml` — peeled commit SHAs plus
  resolved tag names, which is what Renovate's vendir manager maintains.
- A CI freshness gate keeps the vendored trees honest: `vendir sync
  --locked` plus a scoped `git status --porcelain` (the tree must match the
  committed lock deterministically), each `ref:` resolved against its
  remote and required to equal the lock's `sha:` — a moved tag or unsynced
  `ref:` edit fails by name — and on PRs an unchanged `ref:` must keep its
  base `sha:`. The full check list and design live in §3.
- The interim update recipe (edit `ref:` → `vendir sync` → PR) is
  documented in `AGENTS.md`; Renovate is the committed successor ([ADR
  0006](../../ADRs/0006-vendir-replaces-subtree-and-vendor-mirror.md)) and lands
  as a separate PR.

## 2. Scope

**In scope:** `vendir.yml`, `vendir.lock.yml`, a path-filtered
`vendir-check.yml` workflow; the
deletions listed above; `Package.swift` (drop the plugin dep; `exclude:
["COPYING"]` on both C targets — rides T002's commit, since the sync puts
the files inside the target roots); `Projects/Project.swift` (narrow the
`libsecp256k1Tests` `sources:` to three literal files — the vendored
`src/tests.c` plus `../Sources/libsecp256k1/src/precomputed_ecmult{,_gen}.c`
under the deduped bundle; literal, since a glob would compile the
vendored-but-inert `unit_test.c` — and update the comment);
`Projects/Resources/libsecp256k1Tests/Shared.xcconfig` (header search
paths repoint at the shipped `Sources/libsecp256k1` triple — the bundle
resolves its own vendored headers own-dir and needs no entry);
`.github/workflows/xcframework-release.yml` (COPYING
path + swift-crypto LICENSE/NOTICE into the release zip); `.gitattributes`,
`.swiftformat`, `.swiftlint.yml`, `.gitignore`;
`AGENTS.md`, `Sources/AGENTS.md`, `Sources/Shared/README.md`, `.github/AGENTS.md`,
`Development/constitution.md`; the 36 `Vendor/…` references in doc comments
across `Sources/Shared/**` and `Projects/Sources/**`; the `CHANGELOG.md`
`[Unreleased]` entry; and the spec-001 `status:` flip folded in as
housekeeping.

**Out of scope (with owners):**

- Renovate configuration, its workflow, and the `dependabot.yml` teardown —
  separate PR ([ADR 0006](../../ADRs/0006-vendir-replaces-subtree-and-vendor-mirror.md)
  records the commitment). `dependabot.yml` is untouched until it lands.
- Upstream content changes — every synced byte is upstream at the pinned ref.
- `Sources/` layout changes — the extracted trees are byte-identical; the
  nested `Sources/Crypto/…` shape under `Sources/Shared/swift-crypto/` stays.
- The merge ruleset and other workflows — `vendir-check.yml` reports visibly
  but joins no required set without a maintainer decision (same stance as [ADR
  0005](../../ADRs/0005-planning-artifacts-consolidated-under-development.md)).

## 3. Design

**vendir.yml.** Five `directories:` entries, each with a single `git:` contents
entry — the canonical model, and the only one Renovate's vendir support updates
end-to-end. `minimumRequiredVersion: 0.46.2` — the release this migration was
verified against and the version CI pins (carvel-dev/vendir#453's targeted
fetch is still open, so the floor is a tested binary, not a feature gate).
`vendir.lock.yml` is
committed; `.vendir-tmp*` is gitignored. `skipInitSubmodules: true` on all
five — vendir runs `git submodule update --init --recursive` by default,
no upstream has a `.gitmodules`, and the flag keeps a future one from
pulling a second repo into the sync. The three secp256k1 refs share one
`&secp256k1-ref` YAML anchor, so the shared pin can't drift inside the
config — the lock-SHA equality check in the CI gate is the backstop for an
alias replaced by a literal (vendir and Renovate compatibility both
verified — [research.md](./research.md) §4/§5).

| Destination | Upstream | `ref:` | `depth:` |
|---|---|---|---|
| `Sources/libsecp256k1` | bitcoin-core/secp256k1 | `v0.7.1` | 1 |
| `Sources/libsecp256k1_zkp` | BlockstreamResearch/secp256k1-zkp | `08d1cd0…` (SHA pin) | 0 |
| `Sources/Shared/swift-crypto` | apple/swift-crypto | `4.5.0` | 1 |
| `Projects/Sources/libsecp256k1Tests` | bitcoin-core/secp256k1 | `v0.7.1` | 1 |
| `Projects/Resources/WycheproofTests/secp256k1` | bitcoin-core/secp256k1 | `v0.7.1` | 1 |

Tag pins get `depth: 1` — it bounds history depth even though released vendir
still fetches every ref shallowly for a named tag (the targeted single-ref
fetch in carvel-dev/vendir#453 is unmerged). The zkp SHA pin can't ride
`depth: 1` — a shallow fetch reaches only ref tips, and `08d1cd0` sits well
behind `master`'s tip — so `depth: 0` is required. The repo
is ~7MB; the fetch is seconds. Five entries fetch three different repos —
secp256k1 three times over at ~5MB a clone. That fan-out is real but trivially
cheap, so a shared-cache design buys nothing here.

**include/exclude translation.** `subtree.yaml`'s `from:`/`exclude:` globs map
to `includePaths`/`excludePaths` 1:1 (brace groups expanded to explicit
patterns — verified equivalent in [research.md](./research.md) §2). One
deliberate addition per extraction — license files ride with vendored code:
`COPYING` for both C trees (replaces the `Vendor/secp256k1/COPYING` the
release zip copies; vendir's `legalPaths` default doesn't match the name, so
it's explicit) and `LICENSE.txt`/`NOTICE.txt` for swift-crypto (Apache-2.0
§4(d) requires the NOTICE attribution text to ride with the code). Each lands at its target root and is `exclude`d in `Package.swift` — for the C-tree
`COPYING`s, that exclusion rides T002's commit, since an un-excluded file
inside a target root warns on every build — or sits inert under
`Sources/Shared/` (the plugin only copies `*.swift`).

**Preserve step.** vendir wipes each `directories[].path` before copying, and
the only non-upstream files inside the wiped roots are the four `Utility.{h,c}`
shims (the `.h` is pinned in `include/` by `publicHeadersPath`; the `.c`
needs `src/` internals — neither can leave the tree). vendir's `ignorePaths`
field covers this natively: destination files matching its globs are staged
aside and copied back over the sync — shims and uncommitted edits alike,
verified in [research.md](./research.md) §2. No wrapper exists; humans run
bare `vendir sync`, the gate runs `vendir sync --locked`. One caveat: a
*future* upstream file at one of those
exact paths would be silently shadowed — none exists today; a `vendir.yml`
comment notes it, and the CI gate queries both C upstreams at the locked
SHAs to assert those paths stay absent.

**C test-runner re-plumb.** `tests.c` is an amalgamating file: it `#include`s
`secp256k1.c` (the whole library), `../include/` headers,
`../contrib/lax_der_*.c`, `unit_test.c`, `testrand`/`testutil`, and
`wycheproof/*.h` vectors — but not `precomputed_ecmult{,_gen}.c`, whose table
symbols (`secp256k1_pre_g`, `secp256k1_ecmult_gen_prec_table`) it references
`extern` (upstream's CMake compiles the same pair as the `secp256k1_precomputed`
object library). The bundle vendors only what the shipped tree lacks: the
**complete header tree** (`include/**/*.h` + `src/**/*.h`) plus the test-only
translation units (`src/tests.c`, `src/unit_test.c` — vendored because
`tests.c` text-includes it — and `contrib/lax_der_*`, whose `.c` files
quote-include their sibling `.h`), `COPYING`, and
`src/wycheproof/WYCHEPROOF_COPYING`. Vendoring every header — including the
~0.7MB that duplicate `Sources/libsecp256k1` — is deliberate: module test
headers use `../../`/`../../../`-relative and same-dir (`"keyagg.h"`)
spellings that no fixed `-I` set satisfies robustly, while a complete header
tree makes every relative include resolve own-dir exactly as upstream's own
build (verified by `clang -fsyntax-only` on a scratch tree, then the real
`libsecp256k1Tests` build and suite run). Every library `.c` instead comes
from the shipped tree: `secp256k1.c` resolves through
`HEADER_SEARCH_PATHS` — `$(SRCROOT)/../Sources/libsecp256k1{,/src,/include}`:
the `src/` entry supplies the unvendored `secp256k1.c`, the `include/`
entry supplies the `<secp256k1.h>` that `contrib/lax_der_*.h`
angle-include (angle brackets skip the including file's own directory;
quote-includes of `../include/…` never reach the paths — `include/` is
vendored, so they resolve own-dir inside the bundle), and
the root entry mirrors upstream's own `-I` set; the two
`precomputed_*.c` are literal `sources:` entries in `Project.swift` — their
includes are all same-dir, so no search path is needed. No `excludePaths` on
this entry: `includePaths` name no `main()`-carrying file beyond `tests.c`
itself, and the literal
`sources:` list (`src/tests.c` + the two `../Sources/…` tables) — no glob —
keeps vendored-but-inert `unit_test.c`/`lax_der_*.c` from compiling a second
time on top of `tests.c`'s text-includes (duplicate-symbol link failure
otherwise). The repoint of `Shared.xcconfig` lands in the same commit (T002)
so the checkpoint's suite run exercises shipped bytes, not `Vendor/`'s.
The Wycheproof JSONs (plus
`WYCHEPROOF_COPYING`, the vectors' own license) sync to a vendir-owned
`secp256k1/` subdirectory so the xcconfig siblings survive — `newRootPath:
src/wycheproof` re-roots the fetched tree, but `includePaths` are matched
repo-relative *before* it applies, so the patterns spell `src/wycheproof/…`
in full (verified in [research.md](./research.md) §2) — and the two
`Vendor/`-backed JSON symlinks it replaces get removed in the same sync
change — vendir owns the subdir, not the parent. The loader looks the
vectors up flat (`forResource:`, no subdirectory), so the vendored dir
must flatten into the bundle — §5 verifies it.

**Interim updates.** Manual: edit `ref:` in `vendir.yml` →
`vendir sync` → check the lock diff → run `libsecp256k1Tests` against the
synced tree (the §6 tripwire — it only catches extraction bugs if it runs)
→ commit → PR on a
`vendor/<name>-<ref>` branch with the `dependencies` label. The diff check
matters: `vendir sync` re-resolves *every* entry, so a re-pushed tag or drift
on an untouched pin would ride the same PR — only the bumped dep's `sha:`s
should move (for secp256k1 that's all three entries in lockstep — they
share one anchor; the CI gate enforces the same rule on PRs). No
git-subtree trailers, no squash gymnastics — the
lock file is the provenance. Renovate replaces this wholesale in its own PR.

**CI gate.** New `vendir-check.yml`, path-filtered on `vendir*.yml`,
the five vendored destinations, and the workflow itself, plus a weekly
`schedule:` and
`workflow_dispatch:` — a moved tag surfaces within days, not at the next
vendoring PR; `ubuntu-slim` (its published toolset includes git, curl,
coreutils, `yq`, and `jq`; config and lock reads go through
`yq 'explode(.)'` — a bare read prints the `*secp256k1-ref` alias
literally, and `ls-remote` would chase a garbage ref); vendir
installed by `curl` plus a hard-coded release SHA-256 in an `env:` constant
(the Vale precedent — a `checksums.txt` fetched from the same release would
prove nothing if the release were tampered) — pinned at or above the
config's `minimumRequiredVersion`, which the config enforces itself.
Six checks, each a named failure, in run order:

1. **Key allowlist** — enumerate every mapping key in `vendir.yml` and
   fail on any outside the used set: top-level `apiVersion`, `kind`,
   `minimumRequiredVersion`, `directories`; per directory `path`,
   `contents`; per `contents[]` entry `path`, `git`, `includePaths`,
   `excludePaths`, `legalPaths`, `ignorePaths`, `newRootPath`; `git`
   limited to `url`, `ref`, `depth`, `skipInitSubmodules`. Values are
   pinned too: every `url:` in the fixed three-upstream set and every
   `directories[].path` in the five-destination set — otherwise a
   repointed `url:` resolves happily on a fork through every other check.
   vendir drops unknown keys silently — a typo'd `excludePath:` syncs
   green, and the consistency checks below can't see the difference.
2. **Remote resolution** — `git ls-remote <url> refs/tags/<ref>
   refs/tags/<ref>^{}` per entry (take the `^{}` line's SHA when present —
   the bare ref line is the tag-*object* SHA for annotated tags and
   false-fails the lock comparison; lightweight `4.5.0` has only the ref
   line; the zkp pin's `ref:` is the SHA itself),
   required to equal the lock's `sha:` — each resolved value must match
   `^[0-9a-f]{40}$` (an abbreviated SHA fails rather than matching by
   accident) and empty `ls-remote` output fails (a branch name or
   `origin/…` ref queries nothing under `refs/tags/`) — so a moved tag or
   an unsynced
   `ref:` edit fails with the entry named. Runs before the sync: after a
   tag move the locked SHA is often unreachable at `depth: 1`, and a
   fetch error would mask the named failure.
3. **Deterministic tree** — `vendir sync --locked`, then `test -z "$(git
   status --porcelain --ignored=matching -- <vendored paths>
   vendir.lock.yml)"` — the tree must match the committed lock (`git diff
   --exit-code` ignores untracked files; `--ignored=matching` catches a
   synced upstream file matching a repo `.gitignore` pattern).
4. **Base comparison** — on PRs, an entry whose `ref:` is unchanged from
   the base must keep the base's locked `sha:`, so a re-pushed tag can't
   ride another dependency's bump through a committed re-resolve (needs
   base history; skips when `vendir.yml` doesn't exist on the base — this
   PR introduces it).
5. **Anchor backstop** — the three secp256k1 lock SHAs stay equal (the
   anchor makes drift impossible by construction; the guard catches an
   alias replaced by a literal).
6. **Shim shadow check** — `curl -o /dev/null -w '%{http_code}'` on
   `raw.githubusercontent.com` for `include/Utility.h` and `src/Utility.c`
   in both C upstreams at their locked SHAs; passes only on an exact 404
   — an outage must fail, not read as absent (no `gh` or token needed;
   curl is already the install tool). A future upstream file at either
   `ignorePaths` path would be silently shadowed.

`--locked` alone was rejected as the gate — `Lock()` swaps the config's
`ref:` for the lock's `sha:` (pkg/vendir/config/directory.go) without
consulting the edit — so check 2 is what makes a `ref:` edit without a
re-synced lock fail. Not a required check; nothing reaches the repo
without a re-resolve, and a moved tag fails with its name on the next
gate run.

## 4. Implementation steps

Ordered as: the config → the sync
reproduced byte-for-byte and the lock committed → consumers re-pointed →
`Vendor/` teardown → docs → CI gate → verification and merge mechanics. The
full task list, grouped into review slices with checkpoints, is in
[tasks.md](./tasks.md).

## 5. Verification

- [x] `diff -r` of synced trees against the pre-migration commit is empty
  modulo the declared deltas (`COPYING`/`LICENSE.txt`/`NOTICE.txt`, the new `Projects/`
  destinations, the removed symlinks) — proven once in
  [research.md](./research.md) §2; re-run on the real config (T002: zero
  modified tracked files)
- [x] `swift build` and `swift test` at the root unchanged (T002: 39/39,
  no unhandled-file warnings)
- [x] `swift package --disable-sandbox tuist generate -p Projects/ --no-open`
  and `libsecp256k1Tests` builds and runs the upstream suite (T002: exits 0,
  ~216s)
- [x] `WycheproofTests` resolves the JSONs — `TestVectorLoader` looks them up
  flat in the test bundle, so the vendored `secp256k1/` subdir must flatten
  in the copy step
- [x] `xcframework-release.yml` `cp` path resolves (path check; the release
  itself only runs on tags) — the three source paths exist post-sync and the
  copy/zip/unzip/assert flow was simulated locally
- [ ] `vendir-check.yml` fails on an intentionally stale *or untracked* output,
  fails a doctored `ref:` by name (remote-resolution check), fails a
  misspelled-key probe (allowlist check), and passes clean
- [ ] `swift run --package-path Development/Tools plans --check` and
  `vale Development/` clean
- [ ] Manual update recipe exercised end-to-end once (dry-run on a branch)

## 6. Risks and mitigations

- **Test-bundle duplication — resolved 2026-10-08 (dedup variant landed,
  header-tree form)** — `Projects/Sources/libsecp256k1Tests` vendors the
  complete header tree plus the test-only `.c` harness (~2.2MB, of which
  ~0.7MB are headers duplicating `Sources/libsecp256k1` — down from ~3.4MB
  of duplicated sources in the self-contained design). "Test what you
  ship" is the established packaging norm (Fedora `%check`, Debian
  autopkgtest): the suite now compiles the library `.c` files consumers
  actually build, so a silent `vendir.yml` extraction bug in `Sources/`
  fails the suite *when it runs* — the vendoring recipe above and the
  T002/T017 checkpoints; no CI job runs the suite today
  (`apple-builds`/`docker-builds` compile the package, so a build-breaking
  bug still fails CI — a wrong-but-compiling extraction does not) —
  instead of passing forever on a twin. The complete-header-tree
  choice (over vendoring only test-only files) avoids fragile per-depth
  engineered `-I` dirs for `../../`/`../../../`/same-dir include spellings.
  Residual: `#include "secp256k1.c"` resolves through search paths, so a
  same-named file could shadow it — and vendored headers shadow shipped
  ones for bundle-internal includes; both copies are pinned by the shared
  `&secp256k1-ref` anchor and the CI gate's lock-SHA equality +
  `sync --locked` porcelain checks, so they cannot drift undetected.
- **vendir wipes each managed path before copying** — `ignorePaths` carries
  the four `Utility.{h,c}` shims across natively (on-disk bytes, so
  uncommitted edits too; verified in [research.md](./research.md) §2).
  Residual: a *future* upstream file at one of those exact paths would be
  silently shadowed — none exists today, the project names are arbitrary
  enough that upstream adopting them is unlikely, and the CI gate asserts
  their absence at each locked SHA.
- **Symlink-target dirs audited** — `Projects/Sources/libsecp256k1Tests/`
  contains only symlinks, so vendir can own it outright; the Wycheproof dir
  holds live xcconfigs, so vendir owns only a new `secp256k1/` subdirectory
  and the two `Vendor/`-backed JSON symlinks beside it get removed — vendir
  cannot clear what it doesn't own.
- **Tag-object vs commit SHA provenance shift** — `subtree.yaml`'s `commit:`
  recorded the annotated *tag object* SHA; `vendir.lock.yml` records the peeled
  *commit* SHA (`833ca65…` vs `1a53f49…` for `v0.7.1` — same tree). Documented
  in [research.md](./research.md) §3 so a reviewer diffing configs doesn't
  read it as drift.
- **zkp SHA pin needs full history** — a shallow fetch can't reach it (it
  sits well behind `master`'s tip), so `depth: 0` is required, not optional; bounded
  at ~7MB of history either way. Deeper residual: even `depth: 0` works only
  while `08d1cd0` stays reachable from a fetched branch or tag — a `master`
  rewrite upstream would break sync outright until re-pinned (unlikely; no
  mitigation short of a fork mirror).
- **Update detection is manual until Renovate lands** — parity with today, not
  a regression: the subtree checker's schedule was already disabled and ran on
  dispatch only.
- **Contributors need the vendir binary** — `brew install
  carvel-dev/carvel/vendir`, documented in `AGENTS.md`; CI installs a pinned,
  hash-checked binary, and the recipe points at that pinned version —
  `minimumRequiredVersion` is a floor, so a newer local release could write
  a lock format CI can't check.

## 7. Out of scope (follow-ups)

- Renovate: `renovate.json`, its scheduled workflow, absorbing the docker /
  github-actions / swift Dependabot ecosystems, and deleting `dependabot.yml` —
  the committed successor per [ADR
  0006](../../ADRs/0006-vendir-replaces-subtree-and-vendor-mirror.md). The zkp
  SHA pin is the exception — no ref for the vendir manager; the
  `customManagers` + sync-step path and the dual-manager `packageRules`
  question live in [research.md](./research.md) §5. Before relying on the
  `&secp256k1-ref` anchor, run one
  `renovate --platform=local --dry-run=full` — it settles that and the
  single-owner question; the recorded verification covered
  `extractPackageFile` + `doAutoReplace` in branch-worker order, not a
  real run applying three upgrades to one file.
- Upstream signature verification: `v0.7.1` is a GPG-signed tag and the zkp
  pin `08d1cd0` a signed merge commit — the gate detects ref drift but
  cannot authenticate what a pin points at: a bump to a forged commit
  passes every check. The follow-up is a
  CI-side git/gpg check against a committed keyring of known release
  signers; vendir-native verification was evaluated and deferred — keyring
  contents, expiry cadence, and the deferral detail live in
  [research.md](./research.md) §3. Fetch fresh signer keys when that work
  starts — the documented expiries are near-term.
- Whether `vendir-check.yml` joins the merge ruleset — a maintainer decision,
  same as development-docs. Its path filter would leave a required check
  pending on untouched-path PRs — a required rollout needs an always-run
  path or the filter dropped.
- Scheduled-failure visibility — a `schedule:`-triggered red run notifies
  only the last editor of the cron line. If silent-red is unacceptable, a
  follow-up job opening an issue needs a scoped `issues: write` grant on
  that one job; `permissions: {}` stays for the gate itself.
- Pin local `vendir` to the CI version via a lefthook hook filtered to
  `vendir*.yml` — lefthook is already a dev dependency; closes the skew the
  AGENTS recipe warns about (a newer local vendir could write a lock CI
  can't read).
- Flattening `Sources/Shared/swift-crypto/Sources/Crypto/…` via `newRootPath` —
  deliberately unchanged to keep the diff empty.
- `BOT_TOKEN`: its only consumers were the deleted subtree workflows, and
  the repo has no repo-scoped secrets — if the token is org-level,
  cross-repo usage needs an org-admin audit before revocation.

## 8. Division of labor

Single pull request, agent-executed, maintainer-reviewed and -committed — the
maintainer lands each task's or checkpoint's commit per the AGENTS.md
working-tree convention. The Renovate follow-up is a second PR for separate
review.
