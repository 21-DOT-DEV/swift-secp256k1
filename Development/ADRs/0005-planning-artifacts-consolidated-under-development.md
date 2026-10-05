---
adr: 0005
title: Planning artifacts are consolidated under Development/, retiring the spec-kit scaffolding
status: Accepted
date: 2026-10-04
supersedes: []
superseded_by: null
---

# 0005 — Planning artifacts are consolidated under Development/

## Context

Project planning was spread across spec-kit machinery: `.specify/` scripts and
templates, `.devin/workflows/speckit.*` agent playbooks, a `specs/` directory of
multi-file feature folders, and index tables maintained by hand. Feature status
lived in several places that could disagree, and the conventions existed only
as process memory — nothing in the repository enforced them.

## Decision

All planning artifacts live under `Development/`: the constitution, the phase
roadmap, one `plan.md` per feature with YAML frontmatter, and architecture
decision records. A separate Swift package (`Development/Tools`) validates
frontmatter and regenerates the index tables, so a feature's status exists in
exactly one field. The spec-kit scaffolding, the four retired `specs/` folders,
and `.devin/` are deleted — their durable knowledge was mined into these
records and `AGENTS.md`, and everything else remains in git history. A
path-filtered CI workflow and two Vale rules check the conventions — the merge
ruleset's required checks are unchanged, so a failing run is visible on the PR
rather than blocking it.

## Alternatives considered and rejected

- **Keep spec-kit**: preserves the drift this change eliminates — generated
  state maintained by hand, enforcement by habit.
- **Retrofit the four old spec folders into the new format**: rejected per
  documentation-migration practice — rewrite only what has active use; these
  describe shipped work and their decisions are captured here instead.
- **Keep `.devin/` for its non-spec-kit contents**: rejected — `AGENTS.md` is
  the cross-tool guidance surface; the surviving rules and the vendoring
  runbook folded into it rather than living in a second, single-tool config
  directory.

## Consequences

`Development/` is the single planning surface and is verifiable from the repo
itself (`plans --check`, `vale Development/`). The pattern follows
swift-bitcoinkernel#40 and is expected to propagate to sibling repositories.
