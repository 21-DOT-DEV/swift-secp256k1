# Specs

One numbered folder per feature (`NNN-slug/`): a required `plan.md`, plus any
companion files the feature earns (`tasks.md` for ordered work, `research.md`
for evidence). The number is a stable global counter, independent of roadmap
re-phasing; a plan's roadmap phase lives in its frontmatter, not its path.
Features that are tooling or demo-app work carry no phase.

Start from [`_template/plan.md`](_template/plan.md).

## What a plan is, and is not

A plan describes one feature and is **corrected as it changes**. When review
changes the design, edit the affected section so the plan describes what shipped.
Never append a note saying an earlier section is now wrong: that is how a plan
ends up contradicting itself, and how it grows without bound.

Plans therefore carry **no status log, review log, or round-by-round history**.
That material has three homes instead:

| Material | Goes to |
|---|---|
| A decision that outlives the feature, or a review finding the evidence refuted | [`../ADRs/`](../ADRs/README.md), listed in the plan's `adrs:` field |
| A trap that will bite whoever next touches the code | A comment or test name beside that code |
| Everything else that happened during review | The commit message |

**Test counts: deltas, not totals.** Record what a feature *added* (`+7 tests`),
never a running total for the whole suite. A total is a snapshot of one moment
and is wrong by the next commit; a delta stays true.

## Status

A feature's state lives in exactly one place: the `status` field in its plan's
frontmatter. `Planned` means not started; `In Progress` means code complete on a
branch; `Implemented` means **merged**, which is a fact about the repository rather
than a claim that every check passed. Verification that is still outstanding at
merge stays as an unticked box in the plan's own list and is named near the top, so
a reader does not have to reach §5 to find it. The table below
is generated from those fields by
[`../Tools`](../Tools/README.md) (`swift run --package-path Development/Tools
plans`), so the index and the plans cannot
disagree. Do not hand-edit it.

<!-- BEGIN GENERATED INDEX -->
| # | Feature | Phase | Status | Plan |
|---|---|---|---|---|
| 001 | Planning artifacts consolidated under Development/ with a checked, self-contained workflow | — | Implemented | [plan.md](001-development-docs/plan.md) |
| 002 | Replace git-subtree vendoring with vendir, deleting Vendor/ and the subtree tooling | — | Planned | [plan.md](002-vendir-migration/plan.md) |
<!-- END GENERATED INDEX -->
