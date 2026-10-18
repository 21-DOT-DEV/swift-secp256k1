# AGENTS.md (.github)

This directory contains GitHub configuration and CI workflows.

## Boundaries (strict)

- Do not broaden GitHub Actions `permissions` without a clear justification.
- Do not print or log secrets/tokens.
- Do not add new third-party actions without asking.

## Workflow conventions

- Preserve least privilege defaults (this repo commonly uses `permissions: {}` at workflow and job levels).
- All workflows use `env:` blocks for context values — no inline `${{ }}` interpolation in `run:` scripts.
- Avoid fragile shell output capture for UTF-8/multiline content; prefer temp files and tools like `jq` reading from files.
- `pull_request`-triggered steps that write via `GITHUB_TOKEN` (comments, labels) get a same-repo gate (`github.event.pull_request.head.repo.full_name == github.repository`) — fork-PR tokens are read-only, and `head.repo.fork` is the wrong test (it also skips same-repo PRs on a repo that is itself a fork). Publish results to `$GITHUB_STEP_SUMMARY` instead, and gate verdict steps with `${{ !cancelled() }}` (a leading `!` is a YAML tag; it must be wrapped or quoted) so a skipped/failed write can't mask them.
- `development-docs.yml` runs only when `Development/**`, `.vale.ini`, `.vale/**`, or the workflow itself changes. It unit-tests the checker in `Development/Tools`, verifies plan and decision-record frontmatter plus index freshness (`plans --check`), lints plan structure with Vale, and prints document lengths as advisory output. It never builds the package.
- `vendir-check.yml` guards the vendored trees: PRs and pushes to main touching `vendir*.yml`, the five vendored destinations, or the gate machinery (`Scripts/vendir-check*`, the workflow itself), plus a weekly schedule and manual dispatch. It is a thin caller — all check logic lives in `Scripts/vendir-check.sh`, one named step per check, each gated `!cancelled()` so one failed verdict can't mask the next; vendir is a pinned binary with a hard-coded SHA-256 (same pattern as Vale). Advisory — never a required check — and fully anonymous: no token, `permissions: {}` throughout.
- `vendir-check-test.yml` self-tests the gate: PRs and pushes to main touching the gate machinery (`Scripts/vendir-check*`, the two workflows), plus a weekly schedule on a different weekday and manual dispatch. Same thin-caller shape — it installs the same pinned vendir binary and runs `Scripts/vendir-check-test.sh` bare (every fixture case plus the real-tree leg). Advisory; `permissions: {}` throughout.

## Validation

- After changing workflows, run `swift test`.
- Planning documents: `swift test --package-path Development/Tools` (checker unit tests) · `swift run --package-path Development/Tools plans --check` (frontmatter valid, indexes current; omit `--check` to rewrite them) · `vale Development/` (plan structure). All three are fast and need no package build.
