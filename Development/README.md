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

## Design diagrams

A plan's Design section carries a [Mermaid](https://mermaid.js.org) diagram
when the change has **three or more interacting types, parties, or layers**
— multi-party ceremonies, format or persistence boundaries, cross-module
flows, CI/platform topology — and, without any tier judgment, whenever it
trips a security trigger (rule below). GitHub renders fenced `mermaid`
blocks natively; the DocC catalog (`Sources/P256K/P256K.docc`) cannot
(upstream `swift-docc-render#413` is still open), so diagrams live here and
never in the catalog — an article needing a figure gets a committed SVG
instead.

Rules that keep diagrams useful instead of decorative:

- **Pick the diagram that exposes the change's actual risk.** Ordering bugs
  hide in prose-reviewable code (a round of a ceremony arriving out of order
  "you don't see while abstracted away" — the motivation for sequence
  diagrams); the same logic maps each change shape to its best-fitting type:

  | Change shape | Diagram (Mermaid type) |
  |---|---|
  | Rounds, ordering, and hand-offs between parties or processes | Sequence (`sequenceDiagram`) |
  | Branches in validation, acceptance, or error routing | Flowchart (`flowchart`) |
  | Lifecycles and one-shot states (nonces, signing sessions, key states) | State (`stateDiagram-v2`) |
  | Stored or serialized formats and their relations | Entity-relationship (`erDiagram`) or structure |
  | Type surface, conformances, and signature changes | Class (`classDiagram`; before/after for breaking changes) |
  | Data crossing a trust boundary or the path of secret material | Data-flow — a `flowchart` whose subgraphs are the trust zones; label each crossing arrow with the data type and protocol (SDL practice) |
  | Concurrency: shared mutable state, locks, who holds what when | `sequenceDiagram` with `par`/`critical` blocks and lock notes (Mermaid has no activity-diagram type) — `flowchart` if static |
  | CI/deployment topology: lanes, platforms, blocking vs advisory gates | Deployment-style `flowchart` with one subgraph per platform/lane |
  | Dependency and supply-chain diffs (vendir-managed trees, package graph) | Node/graph `flowchart` |
  | Introducing a new module or namespace | C4-style component sketch (Mermaid `C4Component` or a `flowchart`) at the component grain, never code-member grain (C4's own rot guidance) |
  | Release and tag choreography | `gitGraph` |

- **Security-triggered changes always carry the data-flow diagram.** No
  tier judgment: a change that (a) creates or re-routes a trust boundary
  (network fetch, process boundary, new external data source), (b) changes
  how secret material is handled — storage, copying, key-management paths,
  parsing of untrusted bytes — or (c) adds or changes a cryptographic
  algorithm ships a data-flow diagram with marked trust boundaries and
  labeled crossings, **bounded to the change** (model the delta, not the
  system — the per-change doctrine from OWASP's continuous-threat-modeling
  guidance; SAFECode's trigger list supplies (a)–(c) nearly verbatim; Adam
  Shostack's "Fast, Cheap, Good" is the reason the rule doesn't fire more
  often: over-broad mandates decay into theater). Trigger (b) is the
  constitution's existing key/secret-handling security-review row
  (`constitution.md` → Compliance Review Triggers), so enforcement rides an
  existing gate.
- **Best-fit type, not a mandated type.** The table is a starting mapping,
  not a gate; more than one diagram is fine when two risks are real.
- **Sketch grain, not blueprint grain.** Show types, responsibilities,
  relationships, and *changed signatures* — never transcripted member lists
  (Martin Fowler's "comprehensiveness is the enemy of comprehensibility").
  A diagram a reader could reconstruct from headers in ten seconds fails
  review.
- **Breaking changes get a before/after pocket sketch** at signature
  granularity, shared verbatim between the plan and the migration note.
- **Render before review.** The author — human or agent — renders the
  diagram and looks at the *picture* before the PR opens; a diagram nobody
  saw rendered is unchecked prose wearing a fence. The sanctioned local
  renderer is the official `mermaid-cli` Docker image (pinned by its sha256
  digest): `docker run --rm -v "$PWD:/data" ghcr.io/mermaid-js/mermaid-cli/mermaid-cli@sha256:<digest> -i <file>.md -o /data/out.md`
  renders every fenced diagram in a markdown file to a host file next to
  the input (the image's working directory is `/data`, the mount point);
  mermaid.live works when a browser is already open. Until the backlog's
  Mermaid CI gate is specced, GitHub's rendered preview in the PR is the
  floor.
- **Inventories are generated, not drawn.** A complete member map of a
  namespace (e.g. everything under `P256K.Schnorr`) is produced by tooling
  (SwiftPlantUML over the sources) on demand, never hand-edited — hand-drawn
  blueprints rot by design.
- **Plans are corrected in place — diagrams follow.** When implementation
  reveals a design gap, the diagram changes with the text, in the same edit.

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
