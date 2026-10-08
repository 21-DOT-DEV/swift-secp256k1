---
adr: 0006
title: Vendored upstream sources are synced by vendir, retiring git subtree and the Vendor/ mirror
status: Accepted
date: 2026-10-06
supersedes: []
superseded_by: null
---

# 0006 — Vendored upstream sources are synced by vendir, retiring git subtree and the Vendor/ mirror

## Context

Vendoring ran on a bespoke stack: `subtree.yaml` plus a locally-built
`swift-plugin-subtree` CLI kept a squashed full copy of each upstream under
`Vendor/` (~50MB tracked) and extracted globs into `Sources/`, while two
GitHub workflows used the CLI's JSON report to detect updates and open PRs
with `git-subtree` trailer plumbing. The shared roadmap committed to vendir
(the Carvel vendoring tool) with swift-openssl as the proving ground — but its
migration kept subtree for the mirror and update loop, leaving the end-state
unproven.

## Decision

vendir `git:` sources write upstream files directly into their final trees —
`Sources/libsecp256k1/`, `Sources/libsecp256k1_zkp/`, `Sources/Shared/
swift-crypto/`, and two `Projects/` destinations for test-only files — with
provenance in a committed `vendir.lock.yml`. `Vendor/` is deleted; its live
consumers are re-plumbed rather than mirrored (the C test-runner bundle keeps
upstream layout, the Wycheproof JSONs get a vendir-owned subdirectory,
`COPYING` joins the extraction). The four project-owned `Utility.{h,c}` shims
inside the wiped trees are declared via `ignorePaths`, so vendir itself
carries them across syncs — no wrapper. Update automation is Renovate — its
vendir manager bumps `ref:` and re-syncs the ref-pinned entries — landing
in a separate PR with `dependabot.yml` absorbed then; until it lands,
updates are a documented manual recipe.
*(amended 2026-10-07: vendir-manager scope corrected — the zkp SHA pin has
no ref for it to track)*

## Alternatives considered and rejected

- **swift-openssl's hybrid** (vendir extracts, subtree keeps the mirror and
  update loop): preserves two vendoring systems to keep one directory —
  retiring subtree outright is the point of the migration.
- **`.vendir-cache` + `directory:` sources + sidecar lock** (theirs again):
  collapses many-destinations-per-repo fetches; ours is three destinations on
  one repo — real fan-out, but a ~5MB shallow clone needs no cache — and a
  content-free lock file hides provenance from Renovate.
- **Keep `Vendor/` under vendir, full or slimmed**: every real consumer turned
  out re-plumbable for cheap (a bundle, a subdirectory, one `cp` path); a
  mirror that exists "for browsing" doesn't earn ~50MB of every checkout.
- **Post-sync restore wrapper** (swift-openssl's `vendir-preserve.txt` +
  `git checkout` pattern): duplicates what `ignorePaths` does natively, and
  HEAD-restore loses uncommitted edits where `ignorePaths` keeps on-disk
  bytes.
- **`http:` tarball sources**: Renovate can't bump them and GitHub's
  auto-generated archive checksums have shifted before — no durable pin.
- **git submodules**: pointer files, not vendored content — nothing to compile
  in-tree.

## Consequences

Sync is five fetches (~25MB measured): four shallow, plus `depth: 0` on the
zkp SHA pin — a shallow fetch reaches only ref tips and `08d1cd0` sits far
behind `master`'s tip. `vendir.lock.yml` records
peeled *commit* SHAs where `subtree.yaml` recorded annotated tag-*object* SHAs
— same trees, clearer provenance, and the lock is exactly what Renovate
maintains — though the zkp bare-SHA pin has no ref for the vendir manager to
track, so moving it needs a `customManagers` rule paired with a `vendir
sync` step (a text rewrite alone leaves the lock and tree stale).
Update detection is manual until the Renovate PR lands — parity,
since the old checker's schedule was already disabled. `git-subtree` trailers
cease; `Vendor/` deletion is recoverable from history. The drift-check runbook
from `Vendor/AGENTS.md` becomes fetch-on-demand via `gh api` in
`Sources/AGENTS.md`. *(amended 2026-10-07: fetch size and depth mechanism
corrected; zkp update path corrected; amended 2026-10-08: the C test-runner
bundle deduplicates against the shipped tree — it vendors upstream's full
header topology plus only the test-only `.c` harness, while the library's
`.c` files compile from `Sources/libsecp256k1`, so the suite exercises
shipped bytes and ~2.7MB of precomputed tables are not duplicated per clone)*
