# Architecture Decision Records

One file per durable decision, named `NNNN-<slug>.md`. Records are append-only:
a decision that no longer holds is marked `Superseded` and points at the record
that replaced it, rather than being edited or deleted. The chain is checked at
both ends: a `Superseded` record must set `superseded_by:` to a record that
exists and that lists it in `supersedes:` (and vice versa), `superseded_by:`
may not appear on a record that still stands, numbers never repeat, every
reference must resolve, and every chain of replacements must end at a record
that still stands — a loop retires every decision on it.

A choice belongs here when it stays true after the feature that prompted it has
shipped and the surrounding code has moved on. Feature-local choices that die
with their feature stay in that feature's plan under `../Specs/`.

Each record opens with YAML frontmatter:

```yaml
---
adr: 0001
title: Shared sources are copied into both targets by a build plugin
status: Accepted          # Proposed | Accepted | Superseded
date: 2026-10-04
supersedes: []
superseded_by: null
---
```

Then: **Context** (what forced the decision), **Decision**, **Alternatives
considered and rejected**, **Consequences**. Keep each to a paragraph.

The table below is generated from those frontmatter blocks. Do not hand-edit it.

<!-- BEGIN GENERATED INDEX -->
| # | Decision | Status | Date |
|---|---|---|---|
| 0001 | [Shared sources are copied into both targets by a build plugin, not symlinked](0001-shared-sources-copied-into-both-targets-by-a-build-plugin.md) | Accepted | 2025-12-08 |
| 0002 | [Development dependencies are gated on git-tag context in Package.swift](0002-development-dependencies-gated-on-git-tag-context.md) | Accepted | 2026-04-16 |
| 0003 | [No Snippets/ directory — SwiftPM auto-discovery cannot scope snippet dependencies](0003-no-snippets-directory.md) | Accepted | 2026-04-24 |
| 0004 | [XCFramework builds are pinned to Xcode 27 and verified as shipped, never post-edited](0004-xcframework-builds-pinned-to-xcode-27-with-shipped-artifact-verification.md) | Accepted | 2026-10-01 |
| 0005 | [Planning artifacts are consolidated under Development/, retiring the spec-kit scaffolding](0005-planning-artifacts-consolidated-under-development.md) | Accepted | 2026-10-04 |
| 0006 | [Vendored upstream sources are synced by vendir, retiring git subtree and the Vendor/ mirror](0006-vendir-replaces-subtree-and-vendor-mirror.md) | Accepted | 2026-10-06 |
<!-- END GENERATED INDEX -->
