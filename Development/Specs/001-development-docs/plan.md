---
feature: 001
title: Planning artifacts consolidated under Development/ with a checked, self-contained workflow
phase: null
status: In Progress
updated: 2026-10-04
adrs: [0005]
---

# Planning artifacts consolidated under Development/ with a checked, self-contained workflow

A process migration, not a library change. The spec-kit scaffolding (`.specify/`
scripts and templates, `.devin/workflows/speckit.*`, the root `specs/` folders)
is replaced by a single `Development/` directory holding the constitution, the
roadmap, one `plan.md` per feature, and architecture decision records, with the
conventions checked from inside the repository. Tooling work, no roadmap phase;
it ports the pattern proven in swift-bitcoinkernel#40, adapted to this
repository's deltas. Ordered work: [tasks.md](./tasks.md). Evidence and the ADR
candidate sweep: [research.md](./research.md). Produces [ADR
0005](../../ADRs/0005-planning-artifacts-consolidated-under-development.md).

## 1. Goal & success criteria

- `Development/` is the single planning surface: `README.md` (what-goes-where
  charter), `constitution.md`, `Roadmap/` (the phase fileset moved verbatim,
  links rewired), `Specs/` (one required `plan.md` per feature plus earned
  companions, `_template/`, a generated index), `ADRs/` (`NNNN-slug.md` records,
  generated index), `Tools/` (the `plans` checker package).
- A feature's status exists in exactly one field: `plans` validates plan and
  decision-record frontmatter against a schema that refuses unknown fields and
  regenerates both index tables, failing in `--check` mode.
- `development-docs.yml` and two Vale rules check the conventions in CI — the
  PR landing this feature triggers the gate it installs, so the workflow is
  exercised before it is trusted.
- No durable knowledge is lost: `.devin/` rule distillations fold into
  `AGENTS.md`, the vendoring runbook into `Vendor/AGENTS.md`, and the retired
  specs' decisions into the seed ADRs. This migration is itself planned as a
  spec rather than exempted from the system it installs.

## 2. Scope

**In scope:** the `Development/` tree; the checker package; `.vale.ini` and two
`Plans` rules; the `development-docs.yml` workflow; `AGENTS.md`,
`Vendor/AGENTS.md`, `.github/AGENTS.md`, `.gitattributes`, `.dockerignore`; the
deletion of `.specify/`, `.devin/`, and `specs/`.

**Out of scope (with owners):**

- Cryptographic code, vendored sources, and public API — constitution
  Principles I–IV are untouched by design; nothing under `Sources/` or `Vendor/`
  changes beyond scoped guidance files.
- The merge ruleset's required-check set — unchanged; the new gate reports
  visibly but does not block (recorded in [ADR
  0005](../../ADRs/0005-planning-artifacts-consolidated-under-development.md)).
  Making it required is a maintainer decision, per §7.
- The stale `001-`…`004-` spec branches — maintainer cleanup; this change only
  removes their planning artifacts from `main`.
- User API documentation — lives in `Sources/P256K/P256K.docc` and
  `Sources/ZKP/ZKP.docc`; `Development/` is process documentation only.

## 3. Design

**Enforcement.** `Development/Tools` is a nested manifest like
`Scripts/XCFrameworkTest/Package.swift`; nothing in the root build touches it.
The `plans` executable (`PlanIndex` library + thin `main.swift`) decodes
frontmatter against a schema that refuses unknown fields (`feature: 002` keeps
its leading zeros, `updated:` stays text but must name a real calendar date),
checks the status enums, and rebuilds the tables between
`<!-- BEGIN/END GENERATED INDEX -->` markers — escaping each cell by
CommonMark's own rules, so entity and backslash escapes apply outside backtick
code spans while `\|` is needed everywhere. It also checks the graph the
documents form: numbers are unique across folders and records, `adrs:` and
supersede references resolve to records that exist, a supersede chain must
agree at both ends and terminate at a standing decision, and every document's
table rows are walked — skipping fenced code blocks (a `|` inside a fence is
data, not structure) and normalizing `\r\n` line endings (`\r\n` is a single
grapheme cluster, so splitting on `"\n"` alone never fires on a Windows-ending
file).

**Toolchain.** `development-docs.yml` is path-filtered push/PR to `main` on
`macos-26` + `Xcode_26.4` — the toolchain the CI gates already use and whose
Swift 6.3 satisfies the tool's `swift-tools-version: 6.3`; the XCFramework
release workflow pins Xcode 27 separately, per [ADR
0004](../../ADRs/0004-xcframework-builds-pinned-to-xcode-27-with-shipped-artifact-verification.md).
The checker never builds the package itself. Vale is pinned to a `v3.24.0`
release binary with a SHA-256 check, not `brew install`, so an upstream release
cannot change what the gate enforces.

**Prose.** `vale Development/` is scoped to `Specs/` and `ADRs/` only — roadmap
phase files legitimately carry change logs. The glob was verified with a
canary: `**/` matches zero directories so `ADRs/*.md` is covered, and files
outside the section receive no styles, so `Tools/.build/` checkouts cannot
fail CI.

**Retired.** `.specify/` wholesale; the four `specs/` folders (spec-kit format,
their durable decisions mined into the seed records); `.devin/` (eleven
spec-kit workflows and three stale or mechanical rules dropped; three
distillations fold into `AGENTS.md`; the upstream-sync runbook merges into
`Vendor/AGENTS.md`).

## 4. Implementation steps

Ordered as: the checker before the docs it checks → the `Development/` skeleton
→ this spec → the seed decision records → the enforcement layer → teardown and
folds → plumbing → verification. The full task list with file ownership is in
[tasks.md](./tasks.md).

## 5. Verification

- [x] `swift test --package-path Development/Tools` — +85 checker tests
- [x] `swift run --package-path Development/Tools plans` generates both indexes
- [x] `swift run --package-path Development/Tools plans --check` exits clean
- [x] `vale Development/` reports no errors
- [x] `swift build` and `swift test` at the root unaffected
- [ ] The `development-docs.yml` workflow itself runs green on this PR
- [x] Repository format/lint clean on new sources (swiftformat 0/7; SwiftLint's
  `included:` set is `Sources/`+`Tests/` and does not reach `Development/`)
- [ ] Status flipped to `Implemented` at merge (the field means *merged*)

## 6. Risks and mitigations

- **Knowledge lost during teardown** — mitigated by the systematic candidate
  sweep ([research.md](./research.md) §2): every artifact that records or
  implies a durable choice was inventoried, scored, and either seeded or
  parked. Anything missed survives in git history.
- **Index and frontmatter drift** — the tables are generated between markers
  and `--check` fails on staleness; a status lives in one field by
  construction.
- **Checker silently weaker than it looks** — fenced code treated as table
  rows, `\r\n` documents read as a single line, tests that pass either way.
  Each trap carries a regression test that fails when the handling is
  removed.
- **The gate is invisible where it does not apply** — the `paths:` filter means
  it never starts on unrelated PRs, and it is not a required check; ADR 0005
  records that deliberately.

## 7. Out of scope (follow-ups)

- `status:` flips to `Implemented` at merge — the field records a repository
  fact, not a claim about checks.
- Whether the check joins the ruleset's required set — that needs the `paths:`
  filter replaced by an in-job skip so unrelated PRs do not wait on a check
  that never starts. A maintainer decision.
- Vale version bumps — the workflow pins `v3.24.0` + SHA-256; bump both
  together.
- The four stale `001-`…`004-` spec branches — delete at leisure; their
  artifacts are already gone from `main`.

## 8. Division of labor

Single-author migration landed as one pull request, agent-executed and
maintainer-reviewed.
