# Tasks — 001 · Planning artifacts consolidated under Development/

Ordered work for [the plan](./plan.md); evidence and the ADR candidate sweep in
[research.md](./research.md).

Format: `- [x] TNNN [P?] what lands · files`. One checkbox is one reviewable
change. `[P]` marks a task with no prerequisites. Tick the box in the same change
that lands the task. This migration ships as a single pull request, so the
checkboxes record the order the work was executed, not separate merges.

## Enabling work — the checker before the docs it checks

- [x] T001 [P] Port `Development/Tools` verbatim — `Package.swift`, `PlanIndex`
  (Schema/Indexer/Command), the `plans` executable, and both test files — with
  repo-name header swaps and the second-manifest rationale rewritten for this
  project's dev-dependency reality · `Development/Tools/**`
- [x] T002 Verify the package in place: `swift test --package-path
  Development/Tools` — +85 tests (the ported suite plus the hardening tests
  recorded in T019)

## The Development/ skeleton

- [x] T003 Move `.specify/memory/` into place with `git mv` — constitution to
  `Development/constitution.md`, `roadmap.md` to `Development/Roadmap/README.md`,
  the thirteen phase files and `backlog.md` alongside it · `Development/**`
- [x] T004 Rewire links: `constitution.md` resolves one level up, `roadmap/`
  prefixes drop, `../roadmap.md` references point at `README.md`; correct the
  stale "swift-crypto 4.2.0 Update" status row (work shipped; vendored tag is
  4.5.0) with a change-log entry · `Development/Roadmap/*`
- [x] T005 Amend the constitution: sync-report bump to 1.1.0, Principle V names
  `plan.md` under `Development/Specs/` plus the corrected-in-place and
  ADR-graduation practices, stale template TODOs dropped, amendment step 3
  retargeted at `_template/` · `Development/constitution.md`
- [x] T006 [P] Write `Development/README.md`, `Specs/README.md`,
  `Specs/_template/plan.md`, `ADRs/README.md` — index tables left as empty
  marker pairs for the tool to fill · `Development/**`

## This spec

- [x] T007 Author `Specs/001-development-docs/` — `plan.md` with frontmatter and
  constitution check, this `tasks.md`, `research.md` carrying the systematic ADR
  candidate sweep · `Development/Specs/001-development-docs/`

## Decision records

- [x] T008 Sweep candidates from AGENTS.md patterns and boundaries, the four
  retiring specs' decision sections, the constitution, the roadmap, and git
  history; seed five records dated to their decision dates (0001 shared sources,
  0002 conditional dev deps, 0003 no `Snippets/`, 0004 XCFramework pins, 0005
  this consolidation); park the rest in `research.md` · `Development/ADRs/*`
- [x] T009 Run `plans` to generate both index tables; confirm `plans --check`
  exits clean · `Development/{Specs,ADRs}/README.md`

## Enforcement

- [x] T010 [P] Add `.vale.ini` scoped to `Development/{Specs,ADRs}/**/*.md` and
  the two `Plans` rules (no append-only log sections, no running test totals) ·
  `.vale.ini`, `.vale/styles/Plans/*`
- [x] T011 [P] Add `.github/workflows/development-docs.yml` — path-filtered,
  `macos-26` + `Xcode_26.4`, `permissions: {}`/`contents: read`, tool tests,
  `plans --check`, `vale Development/`, advisory line-count report ·
  `.github/workflows/development-docs.yml`

## Teardown and folds

- [x] T012 Delete `.specify/` wholesale (scripts, templates, remaining memory)
  and the four `specs/` folders; their content survives in git history · deletions
- [x] T013 Delete `.devin/` wholesale — eleven spec-kit workflows, the stale
  windsurf rule, and two assistant-ergonomics rules dropped; fold the
  plugin-research, POSIX-command, and swift-version-compatibility distillations
  into root `AGENTS.md`; merge the upstream-sync procedure into
  `Vendor/AGENTS.md` · deletions + `AGENTS.md`, `Vendor/AGENTS.md`

## Plumbing

- [x] T014 `.gitattributes`: swap `.specify/**`, `.windsurf/**`, `specs/**`
  export-ignore lines for `Development/**`, `.vale/**`, `.vale.ini`;
  `.dockerignore` likewise · `.gitattributes`, `.dockerignore`
- [x] T015 Root `AGENTS.md`: add the "Planning artifacts" section and update the
  scoped-guidance and maintenance lists; `.github/AGENTS.md`: add the workflow
  note and the three validation commands · `AGENTS.md`, `.github/AGENTS.md`

## Verification and merge

- [x] T016 Run repository `swiftformat`/`swiftlint` over the new Swift sources;
  conform rather than exclude · `Development/Tools/**`
- [x] T017 `swift build` + `swift test` at the root — confirm unaffected; the new
  workflow is exercised by this PR's own path filter
- [x] T019 Harden the checker and its surroundings — fence-aware table
  scanning (fenced `|` lines are data; a fence ends the table above it; a
  shorter fence cannot close a longer one), `\r\n` line splitting (`\r\n` is
  one grapheme cluster, so `split(separator: "\n")` never fired), a global
  number counter, resolving `adrs:`/`supersedes:`/`superseded_by:` references,
  real-calendar-date fields, index cells escaped per CommonMark code-span rules
  (entities and backslashes outside spans only, `\|` and newlines everywhere),
  supersede chains that must terminate at a standing decision, a write seam so
  write-failure reporting is testable as root, Vale pinned to a hashed release
  binary, `cancel-in-progress` scoped to PRs, and wording/template
  consistency across the docs · `Development/Tools/**`,
  `.github/workflows/development-docs.yml`, `Development/**`
- [x] T018 Flip `status:` to `Implemented` at merge — the field records a
  repository fact, not a claim about checks
