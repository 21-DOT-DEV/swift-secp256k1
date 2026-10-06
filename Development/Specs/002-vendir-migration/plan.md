---
feature: 002
title: Replace git-subtree vendoring with vendir, deleting Vendor/ and the subtree tooling
phase: null
status: Planned
updated: 2026-10-06
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
  self-contained vendored bundle in upstream layout (the target compiles
  `src/{tests,precomputed_ecmult,precomputed_ecmult_gen}.c`; the rest stay
  inert text-includes), the Wycheproof JSON symlinks become real files under
  `Projects/Resources/WycheproofTests/secp256k1/` — the `Vendor/`-backed
  symlinks themselves get `git rm`'d in the same change — and
  `xcframework-release.yml` reads `COPYING` from `Sources/libsecp256k1/COPYING`.
- Provenance lives in a committed `vendir.lock.yml` — peeled commit SHAs plus
  resolved tag names, which is what Renovate's vendir manager maintains.
- A CI freshness gate runs `vendir sync` — which
  re-resolves every ref — and fails on `git status --porcelain` output scoped
  to the vendored paths, so a `vendir.yml` ref edit, a stale lock, a
  hand-edited tree, or a re-pushed upstream tag all surface as diffs in the
  next vendoring PR.
- The interim update recipe (edit `ref:` → `vendir sync` → PR) is
  documented in `AGENTS.md`; Renovate is the committed successor ([ADR
  0006](../../ADRs/0006-vendir-replaces-subtree-and-vendor-mirror.md)) and lands
  as a separate PR.

## 2. Scope

**In scope:** `vendir.yml`, `vendir.lock.yml`, a path-filtered
`vendir-check.yml` workflow; the
deletions listed above; `Package.swift` (drop the plugin dep, `exclude:
["COPYING"]` on both C targets); `Projects/Project.swift` (narrow the
`libsecp256k1Tests` source glob to the three
`src/{tests,precomputed_ecmult,precomputed_ecmult_gen}.c` units, update the
comment); `Projects/Resources/libsecp256k1Tests/Shared.xcconfig` (header search
paths to the new bundle); `.github/workflows/xcframework-release.yml` (COPYING
path); `.gitattributes`, `.swiftformat`, `.swiftlint.yml`, `.gitignore`;
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
end-to-end. `minimumRequiredVersion: 0.46.1` (first release carrying
carvel-dev/vendir#453's targeted single-ref fetch). `vendir.lock.yml` is
committed; `.vendir-tmp*` is gitignored.

| Destination | Upstream | `ref:` | `depth:` |
|---|---|---|---|
| `Sources/libsecp256k1` | bitcoin-core/secp256k1 | `v0.7.1` | 1 |
| `Sources/libsecp256k1_zkp` | BlockstreamResearch/secp256k1-zkp | `08d1cd0…` (SHA pin) | 0 |
| `Sources/Shared/swift-crypto` | apple/swift-crypto | `4.5.0` | 1 |
| `Projects/Sources/libsecp256k1Tests` | bitcoin-core/secp256k1 | `v0.7.1` | 1 |
| `Projects/Resources/WycheproofTests/secp256k1` | bitcoin-core/secp256k1 | `v0.7.1` | 1 |

Tag pins get `depth: 1` (the targeted fetch). The zkp SHA pin takes vendir's
full-fetch path regardless — a bare SHA is not fetchable by name, and shallow
depth can miss a non-tip commit — so `depth: 0` is explicit about it. The repo
is ~7MB; the fetch is seconds. Five entries fetch three different repos —
secp256k1 three times over at ~5MB a clone. That fan-out is real but trivially
cheap, so a shared-cache design buys nothing here.

**include/exclude translation.** `subtree.yaml`'s `from:`/`exclude:` globs map
to `includePaths`/`excludePaths` 1:1 (brace groups expanded to explicit
patterns — verified equivalent in [research.md](./research.md) §2). One
deliberate addition per extraction — license files ride with vendored code:
`COPYING` for both C trees (replaces the `Vendor/secp256k1/COPYING` the
release zip copies; vendir's `legalPaths` default doesn't match the name, so
it's explicit) and `LICENSE.txt` for swift-crypto. Each lands at its target root and is `exclude`d in `Package.swift` /
inert under `Sources/Shared/` (the plugin only copies `*.swift`).

**Preserve step.** vendir wipes each `directories[].path` before copying, and
the only non-upstream files inside the wiped roots are the four `Utility.{h,c}`
shims (the `.h` is pinned in `include/` by `publicHeadersPath`; the `.c`
needs `src/` internals — neither can leave the tree). vendir's `ignorePaths`
field covers this natively: destination files matching its globs are staged
aside and copied back over the sync — shims and uncommitted edits alike,
verified in [research.md](./research.md) §2. No wrapper exists; humans and CI
run bare `vendir sync`. One caveat: a *future* upstream file at one of those
exact paths would be silently shadowed — none exists today; a `vendir.yml`
comment notes it.

**C test-runner re-plumb.** `tests.c` is an amalgamating file: it `#include`s
`secp256k1.c` (the whole library), `../include/` headers,
`../contrib/lax_der_*.c`, `unit_test.c`, `testrand`/`testutil`, and
`wycheproof/*.h` vectors — but not `precomputed_ecmult{,_gen}.c`, whose table
symbols (`secp256k1_pre_g`, `secp256k1_ecmult_gen_prec_table`) it references
`extern` (upstream's CMake compiles the same pair as the `secp256k1_precomputed`
object library). Relative includes must resolve in upstream layout, so
`Projects/Sources/libsecp256k1Tests/` becomes a vendored bundle preserving that
layout — includePaths cover `src/**`, `include/**`, `contrib/lax_der_*`
(the `.c` files quote-include their sibling `.h`, so the glob carries both —
today that resolves inside the full `Vendor/` tree the symlinks point into),
and
`excludePaths` drops the seven `main()`-carrying `src/*.c` (`bench*.c`,
`ctime_tests.c`, `precompute_ecmult{,_gen}.c` — the table *generators*,
distinct from the `precomputed_*` tables — and `tests_exhaustive.c`) plus
`src/wycheproof/*.json` (the JSONs belong under Resources). `Project.swift`
narrows its source glob to `src/{tests,precomputed_ecmult,precomputed_ecmult_gen}.c`
so every other bundled `.c` stays an inert text-include. `Shared.xcconfig`'s
`HEADER_SEARCH_PATHS` repoint at the bundle. The Wycheproof JSONs (plus
`WYCHEPROOF_COPYING`, the vectors' own license) sync to a vendir-owned
`secp256k1/` subdirectory so the xcconfig siblings survive — `newRootPath:
src/wycheproof` re-roots the fetched tree, but `includePaths` are matched
repo-relative *before* it applies, so the patterns spell `src/wycheproof/…`
in full (verified in [research.md](./research.md) §2) — and the two
`Vendor/`-backed JSON symlinks it replaces get `git rm`'d in the same sync
change — vendir owns the subdir, not the parent. Whether the test bundle
lookup needs the subdir name is a verification step.

**Interim updates.** Manual: edit `ref:` in `vendir.yml` →
`vendir sync` → check the lock diff → commit → PR on a
`vendor/<name>-<ref>` branch with the `dependencies` label. The diff check
matters: `vendir sync` re-resolves *every* entry, so a re-pushed tag or drift
on an untouched pin would ride the same PR — only the bumped entry's `sha:`
should change. No git-subtree trailers, no squash gymnastics — the
lock file is the provenance. Renovate replaces this wholesale in its own PR.

**CI gate.** New `vendir-check.yml`, path-filtered on `vendir*.yml`
and the five vendored destinations; `ubuntu-slim` (its published toolset
includes git, curl, and coreutils — all the job needs); vendir
installed by `curl` plus a hard-coded release SHA-256 in an `env:` constant
(the Vale precedent — a `checksums.txt` fetched from the same release would
prove nothing if the release were tampered); runs `vendir sync` —
re-resolving every ref is what makes drift visible: an
edited `ref:`, a stale lock, a hand-edited tree, or a re-pushed upstream tag
all change the output — then a scoped `test -z "$(git status --porcelain --
<vendored paths> vendir.lock.yml)"`, because `git diff --exit-code` ignores
untracked files. `--locked` was rejected: it fetches the *lock's* stored
`OriginalRef` and verifies it against the locked SHA — the config's edited
`ref:` is never consulted, so a `ref:` edit without a committed lock would
pass silently. Not a required check; a re-pushed tag surfaces at
the next vendoring PR — it cannot alter the repo until something re-resolves
it.

## 4. Implementation steps

Ordered as: the config → the sync
reproduced byte-for-byte and the lock committed → consumers re-pointed →
`Vendor/` teardown → docs → CI gate → verification and merge mechanics. The
full task list, grouped into review slices with checkpoints, is in
[tasks.md](./tasks.md).

## 5. Verification

- [ ] `diff -r` of synced trees against the pre-migration commit is empty
  modulo the declared deltas (`COPYING`/`LICENSE.txt`, the new `Projects/`
  destinations, the removed symlinks) — proven once in
  [research.md](./research.md) §2; re-run on the real config
- [ ] `swift build` and `swift test` at the root unchanged
- [ ] `swift package --disable-sandbox tuist generate -p Projects/ --no-open`
  and `libsecp256k1Tests` builds and runs the upstream suite
- [ ] `WycheproofTests` resolves the JSONs at their new subdir
- [ ] `xcframework-release.yml` `cp` path resolves (path check; the release
  itself only runs on tags)
- [ ] `vendir-check.yml` fails on an intentionally stale *or untracked* output
  and passes clean
- [ ] `swift run --package-path Development/Tools plans --check` and
  `vale Development/` clean
- [ ] Manual update recipe exercised end-to-end once (dry-run on a branch)

## 6. Risks and mitigations

- **vendir wipes each managed path before copying** — `ignorePaths` carries
  the four `Utility.{h,c}` shims across natively (on-disk bytes, so
  uncommitted edits too; verified in [research.md](./research.md) §2).
  Residual: a *future* upstream file at one of those exact paths would be
  silently shadowed — none exists today, and the project names are arbitrary
  enough that upstream adopting them is unlikely.
- **Symlink-target dirs audited** — `Projects/Sources/libsecp256k1Tests/`
  contains only symlinks, so vendir can own it outright; the Wycheproof dir
  holds live xcconfigs, so vendir owns only a new `secp256k1/` subdirectory
  and the two `Vendor/`-backed JSON symlinks beside it get `git rm`'d — vendir
  cannot clear what it doesn't own.
- **Tag-object vs commit SHA provenance shift** — `subtree.yaml`'s `commit:`
  recorded the annotated *tag object* SHA; `vendir.lock.yml` records the peeled
  *commit* SHA (`833ca65…` vs `1a53f49…` for `v0.7.1` — same tree). Documented
  in [research.md](./research.md) §3 so a reviewer diffing configs doesn't
  read it as drift.
- **zkp SHA pin takes the slow fetch path** — bounded at ~7MB of history;
  `depth: 0` documents that the pin is intentional, not an oversight.
- **Update detection is manual until Renovate lands** — parity with today, not
  a regression: the subtree checker's schedule was already disabled and ran on
  dispatch only.
- **Contributors need the vendir binary** — `brew install
  carvel-dev/carvel/vendir`, documented in `AGENTS.md`; CI installs a pinned,
  hash-checked binary.

## 7. Out of scope (follow-ups)

- Renovate: `renovate.json`, its scheduled workflow, absorbing the docker /
  github-actions / swift Dependabot ecosystems, and deleting `dependabot.yml` —
  the committed successor per [ADR
  0006](../../ADRs/0006-vendir-replaces-subtree-and-vendor-mirror.md). The zkp
  pin updates through its digest-update flow.
- Whether `vendir-check.yml` joins the merge ruleset — a maintainer decision,
  same as development-docs.
- Flattening `Sources/Shared/swift-crypto/Sources/Crypto/…` via `newRootPath` —
  deliberately unchanged to keep the diff empty.

## 8. Division of labor

Single pull request, agent-executed, maintainer-reviewed and -committed — the
maintainer lands each task's or checkpoint's commit per the AGENTS.md
working-tree convention. The Renovate follow-up is a second PR for separate
review.
