---
feature: 003
title: Remove the ZKP products and fold shared sources into P256K, retiring the build plugin
phase: null
status: Planned
updated: 2026-10-16
adrs: [0008]
---

# Remove the ZKP products and fold shared sources into P256K, retiring the build plugin

A product-line removal, not a tooling shim. `SharedSourcesPlugin` — the
`.buildTool()` plugin flattening `Sources/Shared/*.swift` into both targets —
exists only because two Swift targets share one source set; it forces every
consumer through SwiftPM's plugin-trust validation, which Xcode Cloud cannot
satisfy and which fails silently under Xcode 27 ([research.md](./research.md)
§1). ZKP's distinct shipped surface is measured ≈ zero: its eight
`ENABLE_MODULE_*` traits compile extra modules into the C library but no
Swift source wraps them — ZKP today is the vanilla API linked against the
zkp C tree ([research.md](./research.md) §4). Removing the `ZKP` and
`libsecp256k1_zkp` products deletes the second consumer, so the shared-source
mechanism — plugin, copies, sync script, drift gate — needs no replacement
at all. `Sources/Shared/` folds into `Sources/P256K/`, and ZKP-tier work
returns via a future dedicated package ([ADR
0008](../../ADRs/0008-zkp-products-removed-shared-sources-folded-into-p256k.md),
superseding [ADR
0001](../../ADRs/0001-shared-sources-copied-into-both-targets-by-a-build-plugin.md)).
Ordered work: [tasks.md](./tasks.md). Evidence: [research.md](./research.md).

## 1. Goal & success criteria

- The package ships exactly two products — `P256K` and `libsecp256k1` — and
  two targets plus the retargeted `P256KTests` suite; every build path
  (`swift build`, `swift test`, `xcodebuild`, `tuist generate`, Xcode Cloud)
  runs with **zero** plugins, no trust prompt, no
  `-skipPackagePluginValidation`.
- `Sources/P256K/` is self-contained: the folded former-`Shared/` sources,
  the vendir-managed `swift-crypto/` tree, and the `.docc` catalog. No
  `Sources/Shared/` remains.
- `Tests/ZKPTests` — the vanilla test suite — survives as
  `Tests/P256KTests` against `import P256K` with unchanged coverage;
  `Tests/libsecp256k1zkpTests` (the zkp C-binding smoke test) is deleted
  with its target.
- `vendir.yml` drops the `libsecp256k1_zkp` entry (its heaviest: the
  `depth: 0` SHA pin) and re-destinations swift-crypto to
  `Sources/P256K/swift-crypto` — four destinations total, all
  `vendir-check` invariants preserved.
- Consumer-visible breakage is honest and documented: `.product(name:
  "ZKP")` fails at *resolution* with a clear error; the release notes and
  `MigratingToP256K` state the migration (vanilla users switch to `P256K`;
  true zkp-module consumers pin `0.23.2` until a dedicated package exists).

## 2. Scope

**In scope:** `Package.swift` (products, targets, trait tables,
`zkpModuleDefines`/`zkpModuleSettings`, plugin declaration); the atomic
tree change — `git mv Sources/Shared/*` → `Sources/P256K/`, delete
`Sources/ZKP/`, `Sources/libsecp256k1_zkp/`, `Plugins/SharedSourcesPlugin/`,
`Tests/libsecp256k1zkpTests/`, both `Placeholder.swift` files; the
`Tests/ZKPTests` → `Tests/P256KTests` rename + import retarget;
`vendir.yml`/`vendir.lock.yml`; `Scripts/vendir-check.sh` allowlist and
`.github/workflows/vendir-check.yml` globs;
`.github/workflows/apple-builds.yml` (`-skipPackagePluginValidation` ×4 +
the `Validate ZKP DocC` step); `.github/workflows/docc-release.yml` (ZKP
archive steps + both path-rewrite steps);
`.github/workflows/xcframework-release.yml` (license paths);
`bitrise.yml` (ZKP stage/workflow);
`Scripts/rewrite-docc-shared-paths.swift` (deleted);
`Projects/` (P256K source repoint, `P256KTests`/`BindingsTests` symlinks +
Tuist target); `.gitattributes`; the `#if canImport(libsecp256k1_zkp)`
import sweep (~30 files); `README.md`, root `AGENTS.md`,
`Sources/AGENTS.md`, `Sources/Shared/README.md` (folded + deleted),
`.github/AGENTS.md`; DocC (`ZKP.docc` deleted, `ChoosingP256KvsZKP`
deleted, trust prose stripped from `GettingStarted`/`MigratingToP256K`);
`Development/Roadmap/` (zkp-tier phases re-homed note + backlog
extraction entry + Windows note rewrite); `CHANGELOG.md`.

**Out of scope (with owners):**

- The future `swift-secp256k1-zkp` package — a new repo, specced
  separately when demand funds it; the backlog entry (T009) records the
  vendir cross-repo-sync design sketch.
- No `0.21.x`/`0.23.x` backport — pinned consumers hold their tags
  (0.23.2 keeps both products, plugin included); the compile fix already
  shipped in 0.23.x.
- Trait surface of the retained package — `ecdh`, `ellswift`, `recovery`,
  `schnorrsig`, `musig`, `uint256` stay identical.
- Upstream content — `secp256k1-zkp` simply stops being synced; nothing
  upstream changes.
- Dormant zkp-only C-module API design — phases 6/8/10/11 capability
  planning is unchanged; only the *home* of that future work moves.

## 3. Design

**Layout.** One Swift target, one C target — the shared-source problem
ceases to exist rather than being managed:

```
Sources/
├── P256K/              ← everything P256K compiles
│   ├── P256K.docc/
│   ├── <folded Sources/Shared tree: Combine.swift, ECDSA/, Keys/, …>
│   └── swift-crypto/   vendir-managed (LICENSE/NOTICE excluded)
└── libsecp256k1/       vendir-managed
```

`Sources/Shared/*` moves to `Sources/P256K/` via `git mv`, subdirectories
preserved — history follows the renames. `Sources/Shared/README.md`'s
still-true content (the ASN1 upstream-copy caveat, the license-file
invariant) folds into `Sources/AGENTS.md`; the README itself is deleted —
nothing is "shared" anymore.

**Manifest.** Shrinks to the minimum: two products, `P256K` +
`libsecp256k1` targets, `P256KTests`; `moduleDefines` (the shared six) and
the default/`uint256` traits stay; `zkpModuleDefines`, the eight zkp
traits, the `zkp` bundle trait, and both `zkpModuleSettings` extensions
are deleted with their only consumer. `P256K` gains
`exclude: ["swift-crypto/LICENSE.txt", "swift-crypto/NOTICE.txt"]` (the
`COPYING` precedent — license files inside a target root must be excluded
or they warn on every build). No plugin declaration, no `plugins:`
entries, no `developmentTargets` — the manifest needs no conditional
surface beyond the existing `developmentDependencies` gate.

**Ordering constraint (the atomic commit).** Three moves must land in one
commit: the manifest teardown, the `Sources/Shared` → `Sources/P256K`
fold, and the `Sources/libsecp256k1_zkp` vendir-entry deletion. Splitting
them yields states that cannot build — a declared target with no source
dir, or a plugin whose `find` runs on a deleted `Sources/Shared`. Bulk
deletions are exempt from the line budget; the authored portion is the
~100-line manifest edit plus the move, well inside review size.

**Test suite.** `Tests/ZKPTests` is the vanilla suite (no `P256KTests`
exists) — it `git mv`s to `Tests/P256KTests` with `import ZKP` → `import
P256K` and `ZKP.` → `P256K.` retargeted **before** the atomic commit:
P256K already compiles the identical surface, so the rename commit builds
green on its own. Per-file pass on `SilentPaymentsAPIShapeTests` — if it
exercises ZKP-only surface it deletes with the atomic commit (git history
keeps it for the future repo); if vanilla, it retargets with the rest.
`Tests/libsecp256k1zkpTests` deletes with the C target it binds.

**Tuist.** `Projects/Project.swift`'s `P256K` target resolves its sources
at repo `Sources/P256K/` — preferring a `../`-relative `sources:` glob
(002's literal `../Sources/…` entries are precedent; verify glob
acceptance at implementation) over converting `Projects/Sources/P256K` to
a directory symlink (ADR 0001's consolidated-symlink fallback). The
`P256KTests` symlink repoints `Tests/ZKPTests` → `Tests/P256KTests`;
`BindingsTests` (symlink + Tuist target) deletes with
`libsecp256k1zkpTests`.

**CI.** `bitrise.yml`: the `ZKP` stage and `BUILD-ZKP` workflow are
removed; its `swift test --traits ecdh,musig,recovery,schnorrsig,uint256`
run folds into `BUILD-P256K` so trait-coverage is not silently lost.
`apple-builds.yml`: four `-skipPackagePluginValidation` flags and the
`Validate ZKP DocC` step go (`-skipMacroValidation` stays — unrelated).
`docc-release.yml` becomes P256K-only; the rewrite steps die because
symbol-graph paths are real committed files now. `vendir-check` allowlist
shrinks 5 → 4 destinations.

**Import sweep.** ~30 files carry `#if canImport(libsecp256k1_zkp) …
#elseif canImport(libsecp256k1) …` — post-deletion the first arm is
permanently false, so the sweep replaces each with plain `import
libsecp256k1` (mechanical, one commit). The `#if Xcode || ENABLE_MODULE_*`
guards on retained traits stay untouched.

**DocC.** `ZKP.docc` and `ChoosingP256KvsZKP` delete (the two-product
choice no longer exists); trust prose leaves `GettingStarted` and
`MigratingToP256K`; the root `AGENTS.md` DocC-xref bullet retires — a
single archive means hashes cannot diverge.

**Alternatives considered** (evidence in [research.md](./research.md)):
committed copies + sync script (the shape originally spec'd — rejected
because it builds permanent machinery to manage a duplication that can
simply be deleted); extraction to a live ZKP repo *now* (2–3× the work,
second release train — the deletion keeps that door open without paying
it today); keeping ZKP with the plugin (§1: the trust wall is the bug
report); a shared third target (C-symbol collisions); symlinks; trait-/
environment-selected products (consumer-invariance — §3 of research.md).

## 4. Implementation steps

Ordered as: independently-buildable prep first (test-suite retarget,
vendir re-destination) → the atomic teardown commit → mechanical sweeps →
CI/docs sweep → verification and merge. Full list with review slices:
[tasks.md](./tasks.md).

## 5. Verification

- [ ] `swift build`, `swift test`, `swift build --target P256K` green;
  `swift package describe` shows two products, no `plugins:` anywhere
- [ ] `Tests/P256KTests` runs the full former-ZKPTests suite — test-count
  delta = only deleted zkp-specific tests, recorded in §5/CHANGELOG
- [ ] `vendir sync --locked` reproduces all four destinations;
  `Scripts/vendir-check.sh` green on the updated allowlist
- [ ] `xcodebuild` per the `apple-builds.yml` matrix with **no**
  `-skipPackagePluginValidation`; `bitrise.yml` pipeline validates
  (yaml parse) and its `swift test` runs under `BUILD-P256K`
- [ ] `tuist generate` + `libsecp256k1Tests` + `P256KTests` green through
  the repointed source resolution
- [ ] DocC `--analyze` archive for `P256K` builds clean; symbol paths are
  committed repo paths (no rewrite step)
- [ ] A scratch consumer manifest declaring `.product(name: "ZKP")` fails
  at resolution with a clear "no such product" error — the documented
  break
- [ ] `swift test --package-path Development/Tools`,
  `plans --check`, `vale Development/` clean
- [ ] Repo-wide grep for `ZKP`/`SharedSourcesPlugin`/`Sources/Shared`
  returns only history (CHANGELOG), the superseded ADR, and the
  future-repo backlog notes

## 6. Risks and mitigations

- **ZKP consumers break at resolution** — deliberate and honest:
  resolution-time "no such product" beats the silent trust-wall failure
  they hit today; the package warns the API is unstable; migration note
  lands in the release notes + `MigratingToP256K`.
- **In-flight zkp prototyping loses its home** —
  `SilentPaymentsAPIShapeTests` exists in `ZKPTests`; per-file triage in
  T001 decides retarget-vs-delete, and git history preserves anything
  deleted. Phase-10 silent-payments work re-homes to the future package.
- **ZKP-first workflow inverts** — ADR 0001's "prototype in ZKP, promote
  to P256K" was the shared-dir workflow; post-fold there is one target
  and the direction is moot. The future repo inherits `Sources/P256K`
  wholesale via vendir, so today's P256K files are the prototype bed.
- **Test coverage regressions via sloppy retarget** — the rename commit
  is isolated and required to be green before teardown starts; the §5
  delta check records exactly what was lost.
- **A dangling `ZKP.`/`libsecp256k1_zkp` reference survives the sweep** —
  §5's final grep checklist is the tripwire; `swift build` catches the
  compile-visible ones.
- **Bitrise drift** — no local Bitrise runner exists; the YAML edit is
  verified by parse + the workflow's own CI run on the PR.

## 7. Out of scope (follow-ups)

- **The `swift-secp256k1-zkp` package** — the backlog entry (T009)
  sketches it: a new repo whose `vendir.yml` pulls `Sources/P256K/**`
  (the shared surface — canonical stays here), `secp256k1-zkp`, and
  `swift-crypto` as `git:` sources, riding the existing `vendir-check`
  gate shape and the ADR-0007 org updater. No bespoke sync machinery.
- **Windows support** — the plugin's POSIX blocker is gone entirely;
  the backlog note (T009) rewrites to toolchain/CI work only.
- **Release-notes callouts** — "ZKP products removed; no plugins remain —
  Xcode Cloud works out of the box" belongs in the next tag's notes.
- **Restoring a zkp-gated C-module API** — dormant upstream modules
  (rangeproof, adaptor, s2c, …) ship again only in the future package.

## 8. Division of labor

Task-sized commits, agent-executed, maintainer-reviewed and -committed —
the maintainer lands each task's or checkpoint's commit per the AGENTS.md
working-tree convention. One pull request unless review splits it; commit
order follows the task groups so `git log` reads the same way.
