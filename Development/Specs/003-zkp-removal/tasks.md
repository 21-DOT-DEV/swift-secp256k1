# Tasks — 003 · Remove the ZKP products and fold shared sources into P256K

Ordered work for [the plan](./plan.md); evidence in
[research.md](./research.md).

Format: `- [ ] TNNN [P?] what lands · files`. One checkbox is one reviewable
change — one commit-shaped unit inside this single pull request. `[P]` marks a
task with no prerequisites. **Group headers name the review slice** — the
section of the PR's diff a reviewer reads in one pass — and each closes on a
**checkpoint** stating what must be true before the next slice starts. An
authored diff over ~300 changed lines per commit gets split or the task
justifies why not — bulk deletions, vendored trees, `vendir.lock.yml`, and
mechanical sweeps are exempt from the count. Commit order follows group order
so `git log` reads the same way. Tick the box in the same change that lands
the task.

## Prep that builds standalone

- [ ] T001 [P] Retarget the vanilla test suite — `git mv Tests/ZKPTests
  Tests/P256KTests`, `import ZKP` → `import P256K` (plus `ZKP.` → `P256K.`
  qualifiers and `#if canImport(ZKP)`/`Xcode` guards); `Package.swift`
  target renamed `ZKPTests` → `P256KTests` (deps `["ZKP"]` → `["P256K"]`,
  `zkpModuleSettings` dropped from it); `Projects/Sources/P256KTests`
  symlink repoints to the renamed dir; per-file triage on
  `SilentPaymentsAPIShapeTests` — retarget if it exercises the vanilla
  surface, mark-for-deletion in T003 if it binds zkp-only API (git history
  preserves it either way) · `Tests/ZKPTests/` → `Tests/P256KTests/`,
  `Package.swift`, `Projects/Sources/P256KTests`
- [ ] T002 vendir re-destinations — `vendir.yml`: delete the
  `libsecp256k1_zkp` entry (the `depth: 0` SHA pin and its full-history
  residual go with it) and point the swift-crypto entry at
  `Sources/P256K/swift-crypto` (single destination — no anchor needed);
  `vendir sync`; `Package.swift` gains
  `exclude: ["swift-crypto/LICENSE.txt", "swift-crypto/NOTICE.txt"]` on
  `P256K` (the `COPYING` precedent — inside the target root they warn
  otherwise); `vendir-check.sh` allowlist 5 → 4 paths,
  `vendir-check.yml` globs drop `Sources/libsecp256k1_zkp/**` and repoint
  `Sources/Shared/swift-crypto/**` → `Sources/P256K/swift-crypto/**`;
  `.gitattributes` `linguist-vendored` lines repoint identically;
  `xcframework-release.yml`'s four LICENSE/NOTICE `cp`/`cmp` lines →
  `Sources/P256K/swift-crypto/…` · `vendir.yml`, `vendir.lock.yml`,
  vendored trees, `Package.swift`, `Scripts/vendir-check.sh`,
  `.github/workflows/vendir-check.yml`, `.gitattributes`,
  `.github/workflows/xcframework-release.yml`

**Checkpoint:** `swift build`/`swift test` green — the plugin still
flattens the remaining `Sources/Shared/` into both targets, ZKP is intact,
swift-crypto compiles as ordinary P256K source with no unhandled-file
warnings; `vendir-check` passes over four destinations. *Note: T002
removes `Sources/libsecp256k1_zkp/` from vendir but the directory itself
stays until T003 — the vendir entry and the tree delete together.*

## The atomic teardown

- [ ] T003 One commit — every intermediate state fails to build (a
  declared target with no sources; a plugin `find`ing a deleted
  `Sources/Shared`): `Package.swift` drops `libsecp256k1_zkp` + `ZKP`
  products, the `ZKP`/`libsecp256k1_zkp`/`libsecp256k1zkpTests` targets,
  `zkpModuleDefines`, the eight zkp traits + `zkp` bundle trait, both
  `zkpModuleSettings` extensions, the `SharedSourcesPlugin` declaration,
  and both `plugins:` entries; `git mv Sources/Shared/* Sources/P256K/`
  (subdirs preserved — `Sources/Shared/README.md` folds into
  `Sources/AGENTS.md` in T007 and deletes here); delete
  `Sources/ZKP/` (incl. `ZKP.docc`), `Sources/libsecp256k1_zkp/`,
  `Plugins/SharedSourcesPlugin/`, `Tests/libsecp256k1zkpTests/`, both
  `Placeholder.swift` files, `Scripts/rewrite-docc-shared-paths.swift`;
  `vendir.lock.yml`/`vendir.yml` zkp entry deletion lands here (T002
  staged it) so the vendir-owned dir deletes with its config;
  `Projects/`: `P256K`'s `sources:` repoints at repo `Sources/P256K`
  (`../`-relative glob preferred — the 002 literal-`../` precedent — else
  the `Projects/Sources/P256K` dir becomes a symlink per ADR 0001), the
  `BindingsTests` target + `Projects/Sources/BindingsTests` symlink
  delete · `Package.swift`, `Sources/` trees, `Tests/`, `Plugins/`,
  `Scripts/`, `vendir.*`, `Projects/Project.swift`, `Projects/Sources/`
  *(bulk deletions exempt from line count; authored ≈ manifest edit +
  moves)*

**Checkpoint:** `swift build`, `swift test`, `tuist generate` green;
`swift package describe` lists two products and zero `plugins:`; a
scratch `xcodebuild` without `-skipPackagePluginValidation` builds.

## Mechanical sweeps

- [ ] T004 Collapse the conditional imports — ~30 files'
  `#if canImport(libsecp256k1_zkp) … #elseif canImport(libsecp256k1) …
  #endif` become plain `import libsecp256k1` (the zkp arm is permanently
  dead); `#if Xcode || ENABLE_MODULE_*` guards on retained traits stay ·
  `Sources/P256K/**`
- [ ] T005 CI sweep — `apple-builds.yml`: drop `-skipPackagePluginValidation`
  ×4 and the `Validate ZKP DocC` step; `docc-release.yml`: delete the ZKP
  archive build/rewrite/sanity/smoke steps and the P256K rewrite step
  (symbol-graph paths are committed files — they resolve unmodified), zip
  + upload steps become P256K-only; `bitrise.yml`: `PIPELINE-P256K-ZKP` →
  `PIPELINE-P256K`, drop the `ZKP` stage + `BUILD-ZKP` workflow, fold its
  `swift test --traits ecdh,musig,recovery,schnorrsig,uint256` run into
  `BUILD-P256K`; confirm `.spi.yml` needs nothing (documentation link
  only) · `.github/workflows/{apple-builds,docc-release}.yml`,
  `bitrise.yml`

**Checkpoint:** `swift build`/`swift test` green post-sweep; a repo-wide
`canImport(libsecp256k1_zkp)` grep is empty; no workflow invokes the
deleted script or a `ZKP` target.

## Docs and roadmap

- [ ] T006 Root docs — `README.md`: product list and the Package Traits
  paragraph (zkp trait is gone; point the "full walkthrough" link text
  past plugin-trust language); root `AGENTS.md`: the `SharedSourcesPlugin`
  bullet becomes the single-target layout note ("`Sources/P256K/` is
  self-contained — edit it directly"), the "Cross-archive DocC xrefs"
  bullet retires (one archive — hashes can't diverge), Commands unchanged ·
  `README.md`, `AGENTS.md`
- [ ] T007 `Sources/` docs — `Sources/AGENTS.md` rewritten for the
  single-target layout (one Swift target, one C target, swift-crypto at
  `Sources/P256K/swift-crypto/`; the `Sources/Shared/README.md` content
  that still matters — ASN1 files are project-owned upstream copies, the
  license-file invariant — folds in here); delete
  `Sources/Shared/README.md` (the move happened in T003; this commit
  carries the prose) · `Sources/AGENTS.md`, `Sources/Shared/README.md`
- [ ] T008 DocC — delete `Sources/ZKP/ZKP.docc` remnants and
  `Sources/P256K/P256K.docc/ChoosingP256KvsZKP.md` (the two-product choice
  no longer exists — fix any `<doc:ChoosingP256KvsZKP>` links); strip the
  "Trust the SharedSourcesPlugin" section from `GettingStarted.md` and
  the plugin note from `MigratingToP256K.md`, replacing with a migration
  line: `ZKP`/`libsecp256k1_zkp` products removed in this release —
  vanilla consumers switch to `P256K` · `Sources/*/*.docc`
- [ ] T009 Roadmap + changelog — `Development/Roadmap/`: a README note
  re-homing the zkp-tier phases (6 adaptor sigs, 8 BDHKE/DLEQ, 10/11 as
  applicable) to the future dedicated package; `backlog.md` gains the
  `swift-secp256k1-zkp` extraction item (design sketch: new repo,
  `vendir.yml` `git:` sources pull this repo's `Sources/P256K/**` +
  `secp256k1-zkp` + `swift-crypto` — canonical shared surface stays here;
  rides the existing `vendir-check` shape and ADR-0007 updater) and the
  Windows item's plugin note is rewritten (the POSIX blocker is gone);
  `CHANGELOG.md` `[Unreleased]` breaking entry; `.github/AGENTS.md`
  conventions if the workflow list mentions the dropped pieces ·
  `Development/Roadmap/{README,backlog}.md`, `CHANGELOG.md`,
  `.github/AGENTS.md`
- [ ] T010 _Folded into the spec commit — ADR 0008 (revised in place as
  "ZKP products removed; shared sources fold into P256K") and the 0001
  supersession landed with the spec document set, since `adrs: [0008]`
  validates only against existing records._ · `Development/ADRs/`

**Checkpoint:** `vale Development/` clean; a repo-wide
`ZKP`/`SharedSourcesPlugin`/`Sources/Shared` grep returns only CHANGELOG
history, the superseded ADR, roadmap/backlog notes, and the fold-aware
doc wording; `plans --check` green.

## Verification and merge

- [ ] T011 Full §5 sweep — builds/tests/describe, suite-delta accounting,
  vendir-check green, flagless `xcodebuild`, Tuist generate + both test
  runs, DocC archive path spot-check, scratch-consumer `ZKP` resolution
  failure confirmed, dev-docs trio, final grep checklist — each result
  recorded against its §5 box
- [ ] T012 Flip this spec's `status:` to `Implemented` at merge — the
  field records a repository fact, not a claim about checks ·
  `plan.md`, `tasks.md`

**Checkpoint:** merge-time only — index tables regenerated, status
reflects what the repository now does.
