<!--
Delete this comment before committing.

The ordered work — add this file when the work has real ordering (dependency
waves, review slices) that a flat list in plan.md would hide. Rules:

  * No frontmatter, no `status` field — plan.md alone carries those.
  * Tasks are TNNN (e.g. T001) in dependency order. One checkbox is one
    reviewable change — one commit-shaped unit of work.
  * `[P]` marks a task with no prerequisites — free to pick up early or in
    parallel.
  * Group headers name the review slice — the section of the diff a reviewer
    reads in one pass — and each group closes on a **Checkpoint:** line stating
    what must be true before the next slice starts.
  * An authored diff over ~300 changed lines per commit or pull request gets
    split, or the task justifies in-line why it cannot be — ~300 is the
    midpoint of the documented 200–400 review-effectiveness band (the
    SmartBear/Cisco data; Google's tooling labels changes "large" at 300+);
    the count is per commit/PR, not the whole working tree. Generated output
    (vendored trees, lock files, bulk deletions, mechanical sweeps) is exempt
    from the count. A coherent document set that can't be split — a spec and
    its companions landing together, say — is a legitimate justification;
    name it in the PR description.
  * If the spec ships as more than one pull request, say so here and name the
    boundaries; inside a PR, commit order follows group order so `git log`
    reads the same way.
  * Tick the box in the same change that lands the task.
-->

# Tasks — NNN · <title>

Ordered work for [the plan](./plan.md); measured evidence in
[research.md](./research.md) when the spec has one.

Format: `- [ ] TNNN [P?] what lands · files`. <One line on how this spec's
tasks decompose.>

## <Group name — the review slice>

- [ ] T001 [P] <what lands> · `path/to/file`
- [ ] T002 <what lands> · `path/to/file`

**Checkpoint:** <what is verifiably true when this group closes>.
