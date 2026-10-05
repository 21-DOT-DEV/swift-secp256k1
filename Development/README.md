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

## Status

Each plan's state lives in one place: the `status` field in its YAML
frontmatter (`Planned`, `In Progress`, `Implemented`). The index table in
`Specs/README.md` is generated from those fields, so the two cannot disagree.
