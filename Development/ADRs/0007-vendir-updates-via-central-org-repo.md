---
adr: 0007
title: Vendored upstream sources are synced by vendir, with updates produced by a centralized org updater
status: Accepted
date: 2026-10-11
supersedes: [0006]
superseded_by: null
---

# 0007 — Vendored upstream sources are synced by vendir, with updates produced by a centralized org updater

## Context

ADR 0006 adopted vendir for extraction and named Renovate the update
successor, deferred to a follow-up. Two things reshaped that plan on
review: a per-repo update worker was prototyped on the unmerged
`OLD-VENDIR-MIGRATION` branch — a dispatchable `vendir-update.yml`, an
org-secret `BOT_TOKEN`, a protected environment, and a perl sanitizer for
release notes pasted into PR bodies, ~800 lines whose complexity
outweighed its benefit — and the org already runs the centralized shape
this decision actually wants: `swift-plugin-tuist`'s
`check-github-release.yml` (a `schedule:` + `workflow_dispatch:` detector
that compares a pinned version to upstream and calls `gh workflow run`)
feeding `publish-artifact-bundle.yml` (a `workflow_call:` +
`workflow_dispatch:` worker).

## Decision

The extraction half of 0006 stands unchanged: vendir `git:` sources write
upstream files into their final trees, `ignorePaths` carries the
`Utility.{h,c}` shims across syncs, and provenance lives in the committed
`vendir.lock.yml`. What changes is the update successor: a centralized
updater in its own org repository, in the tuist checker/worker shape — a
scheduled, manually-dispatchable detector that polls upstream heads/tags
against each repo's `vendir.lock.yml` SHAs and dispatches a worker that
clones the repo, re-pins `vendir.yml`, runs `vendir sync`, verifies only
the bumped upstream's lock SHAs moved, pushes a `vendor/<dep>-<ref>`
branch to an org-owned fork of the vendoring repo, and opens the bump
PR against the parent. The worker's GitHub App holds `contents: read`,
`pull-requests` + `issues` write (the `dependencies` label) on each
vendoring repo and `contents: write` only on the fork — a leaked App
key cannot push a branch or tag to a shipped repo, because tag creation
rides the same `contents: write` permission the App never holds there.
Bump refs pass a strict format check (`^v?[0-9][0-9A-Za-z._-]*$` or a
40-hex SHA) and reach `run:` steps through `env:`, never inline
`${{ }}` — upstream controls the tag string. Vendoring repos then need
only `vendir.yml`, the drift gate, and the App installed — no per-repo
worker, no write credential stored in the repo; the org-owned fork
(same-org forking shipped with GitHub's 2022-06-27 fork-policy change)
is one-time setup per vendoring repo. PR bodies link to release notes rather
than embedding upstream-authored text, so no body-sanitization
machinery exists — the only untrusted input is the ref string, handled
by the format check. Until the central repo exists, the manual recipe
in `AGENTS.md` is the update path — parity with the retired subtree
checker, whose schedule was already disabled.

## Alternatives considered and rejected

- **Hosted Mend Renovate app** (0006's plan): its vendir manager is
  function-verified for the tag-pinned entries (`research.md` §5 —
  extractor and replacer tested on 44.142.1, the `&secp256k1-ref`
  anchor groups all three secp256k1 deps into one update; a full dry
  run still precedes reliance), but the zkp bare-SHA pin has no ref to
  track and the
  `customManagers` fix needs self-hosted-only `postUpgradeTasks` to keep
  the lock fresh. It stays the zero-code fallback if the central updater
  never materializes.
- **Self-hosted `renovatebot/github-action`**: reaches the zkp pin via
  `customManagers` + `postUpgradeTasks`, at the cost of a classic PAT, a
  scheduled workflow, and Renovate internals to maintain — heavier than
  the central worker it would duplicate.
- **Per-repo dispatchable worker** (the `OLD-VENDIR-MIGRATION`
  prototype): the bump logic, an org-wide `BOT_TOKEN` personal access
  token, a protected environment, and a decode-first sanitizer — all
  duplicated in every vendoring repo. The branch stays in git as the
  reference for edge-case handling (SHA-on-default-branch checks,
  declined-PR semantics).
- **App pushing same-repo `vendor/*` branches, confined by rulesets**:
  `contents: write` on vendoring repos, fenced to `vendor/**` by a
  branch ruleset plus a tag ruleset. Rejected — the credential still
  mints release tags wherever a ruleset is missing or misapplied, and
  confinement-by-config fails open across N repos; the fork model
  removes the permission instead. Mend ships the same split: hosted
  Renovate uses in-repo branches while "Forking Renovate" exists for
  orgs that refuse `contents: write`.

## Consequences

Update detection and update execution both centralize: vendoring a
dependency in another org repo needs no CI there beyond this gate. Bump
PRs keep the `vendor/<dep>-<ref>` convention and `dependencies` label;
the credential is the small GitHub App the Decision section scopes —
a workflow's `GITHUB_TOKEN` is repo-scoped and cannot push cross-repo,
and a PAT is the credential class the prototype was rejected for.
App-created fork PRs run CI on `pull_request` with the fork-PR
read-only token: every workflow step that writes via `GITHUB_TOKEN`
needs a fork-PR path — `benchmark-pr.yml` gates its PR comment to
non-fork PRs and publishes the comparison in the job summary (no
token needed), and its regression verdict runs under `!cancelled()`
so a comment failure cannot mask it. Required checks must also report on
fork PRs — the Bitrise project's fork-PR build setting is confirmed
when the updater is built; if a required check cannot see fork PRs,
bump PRs couldn't merge and the model falls back to same-repo
branches under rulesets. The App's private key lives in a protected
environment in the central repo, deployment-restricted to the
worker's protected branch — the custody the prototype paid once per
repo. Each vendoring repo also gets a tag ruleset restricting tag
create/update/delete to maintainer bypass: not load-bearing under
the fork model — the App holds no tag-capable permission — but
defense against every other write credential, and this repo's only
ruleset today targets branches, so the maintainer adds it now rather
than at updater time. Fork-model trade-offs accepted: PRs from
org-owned forks cannot take maintainer push-edits (a
regenerate-on-demand bot does not need them), and fork-PR workflow
approval is the org's setting — one click under the common
first-time-contributor default, every bump PR under the stricter
all-outside-collaborators mode. The human step is unchanged under
either update path:
a reviewer pulls each bump branch and runs `libsecp256k1Tests` — no
automation runs that suite. This record supersedes 0006 in full: its
extraction decision carries over unchanged in substance; its Renovate
clause is the part replaced.
