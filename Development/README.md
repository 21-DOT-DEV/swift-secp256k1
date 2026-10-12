# Development

Project process and planning artifacts. This is not user documentation: the
library's API reference lives in the DocC catalogs under `Sources/*/`.

| Folder | Holds | Authoritative for |
|---|---|---|
| [`constitution.md`](constitution.md) | The development charter | How we build: principles, MUST/SHOULD/MAY, governance |
| [`Roadmap/`](Roadmap/README.md) | Phase plan and phase files | What we build and in what order |
| [`Specs/`](Specs/README.md) | One required `plan.md` per feature, plus earned companions | How a single feature gets built |
| [`ADRs/`](ADRs/README.md) | Architecture decision records | Why a durable choice was made, and what it replaced |

## What goes where

A plan describes one feature and stops being current when that feature merges.
A decision record captures one choice and stays true after the code around it
is rewritten. The split follows from that:

- **Review changed the design?** Edit the plan so it describes what shipped.
  Do not append a note saying the plan is now wrong.
- **The reasoning outlives the feature?** It becomes an ADR. Findings that a
  review raised and the evidence refuted belong here too, so the same argument
  is not reopened later.
- **Everything else?** The commit message. It is already in the repository and
  it is already read.

Plans carry no status log, review log, or round-by-round history. That material
either graduates to an ADR or lives in version control.

## Review discipline

Cross-document edits get a claim-extraction pass before a review round
closes: every added line that asserts a fact — a count, a path, a
capability, a "will/only/never" — is checked against the document set's
established claims, including claims written in the same round. The
failure modes seen in practice, each its own sweep: stale
cross-references to renamed or superseded things; path-filter claims
that don't cover the files they name; wrong counts of tasks, checks,
or sources; future-tense claims with no owner to flip them; capability
claims a credential or tool can't support; "verified" beyond the
evidence; platform behavior the prose assumes wrong; and same-round
drift — a sentence just added contradicting a fact elsewhere in the
set.

## Status

Each plan's state lives in one place: the `status` field in its YAML
frontmatter (`Planned`, `In Progress`, `Implemented`). The index table in
`Specs/README.md` is generated from those fields, so the two cannot disagree.
