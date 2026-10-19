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

- [x] T001 [P] Retarget the vanilla test suite — `git mv Tests/ZKPTests
  Tests/P256KTests`, `import ZKP` → `import P256K` (plus `ZKP.` → `P256K.`
  qualifiers and `#if canImport(ZKP)`/`Xcode` guards); `Package.swift`
  target renamed `ZKPTests` → `P256KTests` (deps `["ZKP"]` → `["P256K"]`,
  `zkpModuleSettings` dropped from it); `Projects/Sources/P256KTests`
  symlink repoints to the renamed dir; per-file triage on
  `SilentPaymentsAPIShapeTests` — retarget if it exercises the vanilla
  surface, mark-for-deletion in T003 if it binds zkp-only API (git history
  preserves it either way) · `Tests/ZKPTests/` → `Tests/P256KTests/`,
  `Package.swift`, `Projects/Sources/P256KTests`
- [x] T013 [P] Retarget the C-binding smoke suite — `git mv
  Tests/libsecp256k1zkpTests Tests/libsecp256k1BindingsTests`, collapse
  the `#if canImport(libsecp256k1_zkp)` header to its `#else` arm
  (`@testable import libsecp256k1` + `@testable import P256K`);
  `Package.swift` target renamed `libsecp256k1zkpTests` →
  `libsecp256k1BindingsTests` (deps `["ZKP", "libsecp256k1_zkp"]` →
  `["P256K", "libsecp256k1"]`, `zkpModuleSettings` dropped);
  `Projects/Sources/BindingsTests` symlink repoints to the renamed dir —
  the Tuist `BindingsTests` target keeps its name, it already compiled
  this file's vanilla arm. Kept rather than deleted: it is the only
  `swift test` coverage that names `secp256k1_*` symbols (the vendored
  upstream `tests.c` suite never exercises the Swift importer surface) ·
  `Tests/libsecp256k1zkpTests/` → `Tests/libsecp256k1BindingsTests/`,
  `Package.swift`, `Projects/Sources/BindingsTests`
- [x] T002 vendir excision — `vendir.yml`: delete the `libsecp256k1_zkp`
  entry (the `depth: 0` SHA pin and its full-history fetch go with it);
  `vendir sync` regenerates the lock at four destinations;
  `vendir-check.sh`'s allowlist drops the path from `expected_paths` and
  the BlockstreamResearch URL from `allowed_urls` ("three declared
  upstreams" → "two"); `vendir-check.yml` path filters drop
  `Sources/libsecp256k1_zkp/**` — the gate stops guarding the tree the
  moment vendir stops managing it; every sentence asserting the old
  shape goes with it (`Sources/AGENTS.md`'s extraction list drops the
  zkp line, root `AGENTS.md`'s "five `git:` sources across three
  upstreams" becomes four across two with the shim count dropping to
  two, `.github/AGENTS.md`'s destination count, and
  `vendir-check-test.sh`'s fixture comments). The swift-crypto
  re-destination rides T003's fold instead — while `ZKP` and the Tuist
  `Shared` symlink still read through `Sources/Shared/`, moving the
  tree out early strips `Digest`/`SecureBytes`/`CryptoKitError`/`ASN1`
  symbols from both builds ([research.md](./research.md) §4) ·
  `vendir.yml`, `vendir.lock.yml`, `Scripts/vendir-check.sh`,
  `Scripts/vendir-check-test.sh`, `.github/workflows/vendir-check.yml`,
  `AGENTS.md`, `Sources/AGENTS.md`, `.github/AGENTS.md`

**Checkpoint:** `swift build`/`swift test` green — nothing compiled
changed: the plugin still flattens all of `Sources/Shared/`, swift-crypto
included, into both targets; ZKP is intact; `vendir-check` passes over
four destinations. *Note: T002 removes `Sources/libsecp256k1_zkp/` from
vendir but the directory itself stays until T003 — the vendir entry
leaves here, the tree deletes there.*

## The atomic teardown

- [x] T003 One commit — every intermediate state fails to build (a
  declared target with no sources; a plugin `find`ing a deleted
  `Sources/Shared`): `Package.swift` drops `libsecp256k1_zkp` + `ZKP`
  products, the `ZKP`/`libsecp256k1_zkp` targets,
  `zkpModuleDefines`, the eight zkp traits + `zkp` bundle trait, both
  `zkpModuleSettings` extensions, the `SharedSourcesPlugin` declaration,
  and both `plugins:` entries; `git mv Sources/Shared/* Sources/P256K/`
  (subdirs preserved — `Sources/Shared/README.md` folds into
  `Sources/AGENTS.md` in T007 and deletes here); the fold carries the
  vendored swift-crypto tree to its final location, so the same commit
  re-destinations it: `vendir.yml` `path:` → `Sources/P256K/swift-crypto`
  and `vendir sync` (rewrites the lock's `path:` — `git mv` first, then
  sync, and the wiped-and-recopied tree still reads as one rename);
  `Package.swift`'s `P256K` gains
  `exclude: ["swift-crypto/LICENSE.txt", "swift-crypto/NOTICE.txt"]`
  (the `COPYING` precedent — license files inside a target root warn
  otherwise); every file naming the old location repoints here:
  `vendir-check.sh` `expected_paths`, `vendir-check.yml` globs,
  `.gitattributes` `linguist-vendored` (which also drops the
  `Sources/libsecp256k1_zkp` lines with the tree),
  `xcframework-release.yml`'s four LICENSE/NOTICE `cp`/`cmp` lines, and
  `Scripts/vendir-check-test.sh`'s bad-path fixture sed; delete
  `Sources/ZKP/` (incl. `ZKP.docc`), `Sources/libsecp256k1_zkp/` (its
  vendir entry left in T002 — the now-unmanaged tree is removed
  outright), `Plugins/SharedSourcesPlugin/`, both `Placeholder.swift`
  files, `Scripts/rewrite-docc-shared-paths.swift`; `Projects/`:
  `P256K`'s `sources:` repoints at repo `Sources/P256K`
  (`../`-relative glob preferred — the 002 literal-`../` precedent — else
  the `Projects/Sources/P256K` dir becomes a symlink per ADR 0001);
  `lefthook.yml` drops the `swift build --target ZKP` pre-push hook — it
  fails the moment the target is gone (the `swift test` hook stays);
  `apple-builds.yml` also drops the `Validate ZKP DocC` step here — it
  invokes the deleted target and reds every pushed head, so it cannot
  wait for T005 (the bitrise `ZKP` stage stays for T005: its script is
  `swift test` over vanilla traits only — green either way) ·
  `Package.swift`, `Sources/` trees, `Plugins/`,
  `Scripts/`, `Projects/Project.swift`, `Projects/Sources/`, `lefthook.yml`,
  `vendir.yml`, `vendir.lock.yml`, `.gitattributes`,
  `.github/workflows/vendir-check.yml`,
  `.github/workflows/apple-builds.yml`,
  `.github/workflows/xcframework-release.yml`
  *(bulk deletions exempt from line count; authored ≈ manifest edit +
  moves)*

**Checkpoint:** `swift build`, `swift test`, `tuist generate` green;
`swift package describe` lists two products and zero `plugins:`; a
scratch `xcodebuild` without `-skipPackagePluginValidation` builds.

## Mechanical sweeps

- [x] T004 Collapse the conditional imports — ~30 files'
  `#if canImport(libsecp256k1_zkp) … #elseif canImport(libsecp256k1) …
  #endif` become plain `import libsecp256k1` (the zkp arm is permanently
  dead); the two non-import code forks collapse the same way —
  `MuSig+Signing.swift`'s `secp256k1_musig_nonce_process` call keeps the
  5-arg vendored signature (the `adaptor` arg exists only in the zkp
  fork — upstream's module, merged via bitcoin-core/secp256k1#1479,
  never carried it) and `MuSig+Nonces.swift`'s
  `canImport(zkp_bindings)` fork (the pre-rename module name, false on
  every shipped layout) keeps its `#else` arm; `#if Xcode ||
  ENABLE_MODULE_*` guards on retained traits stay · `Sources/P256K/**`
- [x] T005 CI sweep — `apple-builds.yml`: drop `-skipPackagePluginValidation`
  ×4 (the `Validate ZKP DocC` step left in T003 — the only step that
  reds a T003-only head); `docc-release.yml`: delete the ZKP
  archive build/rewrite/sanity/smoke steps and the P256K rewrite step
  (symbol-graph paths are committed files — they resolve unmodified), zip
  + upload steps become P256K-only; `bitrise.yml`: `PIPELINE-P256K-ZKP` →
  `PIPELINE-P256K`, drop the `ZKP` stage + `BUILD-ZKP` workflow, fold its
  `swift test --traits ecdh,musig,recovery,schnorrsig,uint256` run into
  `BUILD-P256K`; confirm `.spi.yml` needs nothing (documentation link
  only) — no tag, release, or `docc-release` dispatch may land between
  the T003 merge and this merge: the workflow still calls the deleted
  rewrite script and `--target ZKP` until here ·
  `.github/workflows/{apple-builds,docc-release}.yml`,
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
  bullet retires (one archive — hashes can't diverge), the header's
  "(and secp256k1-zkp)" and the Snippets bullet's two-C-binding
  rationale get the same pass, Commands unchanged; `SECURITY.md`'s
  wrapped-libraries list and `Development/constitution.md`'s scope
  line + component table drop the zkp rows · `README.md`, `AGENTS.md`,
  `SECURITY.md`, `Development/constitution.md`
- [ ] T007 `Sources/` docs — `Sources/AGENTS.md` rewritten for the
  single-target layout (one Swift target, one C target, swift-crypto at
  `Sources/P256K/swift-crypto/`; the `Sources/Shared/README.md` content
  that still matters — ASN1 files are project-owned upstream copies, the
  license-file invariant — folds in here — recover it from git history;
  the file deleted in T003, so nothing on disk remains to move) ·
  `Sources/AGENTS.md`
- [ ] T008 DocC — strip the "Trust the SharedSourcesPlugin" section from
  `GettingStarted.md` and the plugin note from `MigratingToP256K.md`,
  replacing with a migration line: `ZKP`/`libsecp256k1_zkp` products
  removed in this release — vanilla consumers switch to `P256K`; sweep
  every `zkp` trait reference out of both articles — the
  `traits: ["zkp"]` copy-paste examples (`GettingStarted.md` ~line 89,
  `MigratingToP256K.md` ~line 74; a consumer who copies one now hits an
  unknown-trait error at resolution), the `zkp`-bundle paragraph
  (`GettingStarted.md` ~line 93 — rewriting it also clears the DocC
  inclusive-language note on `whitelist`), the "requires the `zkp`
  trait" module-mapping rows and "behind the `zkp` package trait" line
  (`MigratingToP256K.md` ~lines 100–103), and the `zkp`-named traits in
  the trait-selection prose and missing-trait troubleshooting paragraph
  (`MigratingToP256K.md` ~lines 68, 200) · `Sources/*/*.docc`
- [ ] T009 Roadmap + changelog — `Development/Roadmap/`: a README note
  re-homing the zkp-tier phases (6 adaptor sigs, 8 BDHKE/DLEQ, 10/11 as
  applicable) to the future dedicated package — sweep the phase files for
  stale target names while there (the `phase-1` `libsecp256k1zkpTests`
  note was already corrected alongside T013); `backlog.md` gains the
  `swift-secp256k1-zkp` extraction item (design sketch: new repo,
  `vendir.yml` `git:` sources pull this repo's `Sources/P256K/**` +
  `secp256k1-zkp` + `swift-crypto` — canonical shared surface stays here;
  rides the existing `vendir-check` shape and ADR-0007 updater), the
  Windows item's plugin note is rewritten (the POSIX blocker is gone),
  and a new item records `DocC symbol extraction fails under
  Xcode 27.0 — cause unconfirmed; pre-existing, unrelated to spec 003`
  (the three DocC jobs pin Xcode 26.4 by hand while
  `xcframework-release.yml` already runs 27.0 — whoever aligns them
  trips this);
  `CHANGELOG.md` `[Unreleased]` breaking entry; `.github/AGENTS.md`
  conventions if the workflow list mentions the dropped pieces ·
  `Development/Roadmap/{README,backlog,phase-1-testing-foundation}.md`,
  `CHANGELOG.md`, `.github/AGENTS.md`
- [ ] T010 _Folded into the spec commit — ADR 0008 (revised in place as
  "ZKP products removed; shared sources fold into P256K") and the 0001
  supersession landed with the spec document set, since `adrs: [0008]`
  validates only against existing records._ · `Development/ADRs/`
- [x] T014 Source doc-comment residue — repoint the nine
  `secp256k1-zkp/include/secp256k1_musig.h` doc links to
  `bitcoin-core/secp256k1` (the module's upstream home since
  bitcoin-core/secp256k1#1479 — the links were stale before this spec)
  and reword the three `Sources/Shared/*` doc cites to `Sources/P256K/*`
  for the single-target layout; authored wording, not mechanical —
  split from T004 so that commit stays purely compiler-verified, and
  may land any time before T011's repo-wide grep gate ·
  `Sources/P256K/**`

**Checkpoint:** `vale Development/` clean; a repo-wide case-insensitive
`zkp`/`SharedSourcesPlugin`/`Sources/Shared` grep returns only CHANGELOG
history, the superseded ADR, roadmap/backlog notes, and the fold-aware
doc wording; `plans --check` green.

## Verification and merge

- [ ] T011 Full §5 sweep — builds/tests/describe, suite-delta accounting,
  vendir-check green, flagless `xcodebuild`, Tuist generate + both test
  runs, DocC archive path spot-check (run under Xcode 26.4, CI's pin —
  `apple-builds.yml:70`), scratch-consumer `ZKP` resolution
  failure confirmed, dev-docs trio, final grep checklist — each result
  recorded against its §5 box
- [ ] T012 Flip this spec's `status:` to `Implemented` at merge — the
  field records a repository fact, not a claim about checks ·
  `plan.md`, `tasks.md`

**Checkpoint:** merge-time only — index tables regenerated, status
reflects what the repository now does.
