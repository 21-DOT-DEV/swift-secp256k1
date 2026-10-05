# Research — 001 · Planning artifacts consolidated under Development/

Evidence behind the seed decision records and the migration choices. Two sweeps:
(1) what the upstream PR (swift-bitcoinkernel#40) actually changed, and (2) a
systematic inventory of this repository's durable decisions for seeding `ADRs/`.

## 1. Source PR analysis

The PR replaced spec-kit scaffolding with a self-contained `Development/`
directory plus enforcement: a `plans` checker (separate Swift package, so the
root manifest's dev dependencies never enter a docs check), generated index
tables, a path-filtered CI gate, and two Vale rules. Post-merge history shows
one follow-up spec using the system and no fixes to the tooling — it shipped
clean. The format has since evolved: a spec folder may carry `spec.md`,
`tasks.md`, and `research.md` alongside the required `plan.md` (see
`004-sync-watch` upstream); this spec adopts that form.

Local deltas the PR did not have to handle, and their resolutions:

- Four spec-kit `specs/` folders (six files each, all shipped work) → dropped;
  their decisions were mined below rather than their folders retrofitted.
- `.devin/` held live non-spec-kit configuration (trigger-gated rules, a
  vendoring runbook) → distilled into `AGENTS.md`/`Vendor/AGENTS.md`, then the
  directory deleted for full parity.
- A richer roadmap (index + backlog + thirteen phase files) → moved verbatim;
  links rewired.

## 2. ADR candidate sweep

**Method**: inventory every artifact that records or implies a durable choice —
the `AGENTS.md` files' "Non-obvious patterns" and "Boundaries" sections, the four
retiring specs' decision/research sections, constitution MUSTs, the roadmap's
directional commitments, and `git log -S` for the commits that introduced each
pattern. Score against three tests: still true after surrounding code moved on ·
had real rejected alternatives · costly to rediscover. Seed the strongest five;
park the rest for organic backfill (backfilling is an ongoing practice — a record
is written whenever someone finds themselves explaining a "why").

| Candidate | Evidence | Verdict |
|---|---|---|
| Shared sources copied into both targets by a build plugin | spec 001 research + commit #934 (2025-12-10); alternatives: directory symlinks, duplication, same-package executable (SPM can't), rsync | **Seeded 0001** (dated 2025-12-08) |
| Development dependencies gated on git-tag context | `Package.swift` `Context.gitInformation?.currentTag`; commit #1082 (2026-04-16); alternative: unconditional dev deps reaching consumers | **Seeded 0002** |
| No `Snippets/` directory | AGENTS.md + DocC refactor #1096 (2026-04-24); alternative rejected by SE-0356 duplicate-symbol link failure | **Seeded 0003** |
| XCFramework toolchain pins (Xcode 27, module selectors, shipped-artifact verification) | commits #1176/#1178 (2026-09-27/10-01); alternative: post-editing emitted interfaces | **Seeded 0004** |
| Planning artifacts under `Development/` (this migration) | this spec | **Seeded 0005** — produced *by* the feature, per the `adrs:` field |
| Package separation with swift-openssl (Zone A–D sourcing rule) | `Development/Roadmap/README.md` §Package Separation | Parked — already durable in the roadmap; revisit if it leaves the roadmap's front page |
| Vendir-driven vendoring direction | roadmap high-priority item | Parked — a committed *direction*, not yet a decision that survived contact; record it when phase 10 lands |
| Test vectors and integration tests under `Projects/` (Tuist) | spec 003 research | Parked — real candidate; defer until the architecture settles past phase 2 |
| ZKP-first development workflow (prototype ZKP → promote P256K) | `AGENTS.md`, constitution §Projects | Parked — constitutional practice already; fold into a future workflow ADR if it evolves |
| `#if Xcode \|\| ENABLE_MODULE_*` trait guards | `AGENTS.md` | Parked — a workaround mechanism, not a decision with alternatives |
| swift-tools-version as the compatibility oracle | retiring `.devin` rule | Not an ADR — method guidance; folded into `AGENTS.md` |
| Partial swift-crypto extraction boundary (excluded `ObjectIdentifier`/`SEC1*` symbols) | `subtree.yaml`, spec 004 | Parked — adjacent to package separation; pair with it if that record is ever written |
| Zero runtime dependencies | constitution §I | Not an ADR — constitutional principle, already the stronger record |
| Dual CI (Bitrise + GitHub Actions) | `bitrise.yml`, `.github/workflows/` | Parked — no clear rejected-alternative story captured yet |

## 3. Conventions verified against the upstream artifacts

- Backfilled records are dated to the *decision* (per upstream precedent: its
  ADRs predate the PR that created them).
- `phase: null` marks tooling work; `Implemented` means merged — spec 001 lands
  as `In Progress` and flips at merge.
- `superseded_by: null` and `supersedes: []` decode cleanly under the schema
  (`[Int]?` / `String?`); verified against `Schema.swift` and the test suite.
- Roadmap files carry no frontmatter — the checker only reads `Specs/*/plan.md`
  and `ADRs/*.md`; roadmap change-log sections are why `.vale.ini` scopes the
  `Plans` style to `Development/{Specs,ADRs}/**/*.md`.
