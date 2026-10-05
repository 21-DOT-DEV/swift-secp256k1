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
- `development-docs.yml` runs only when `Development/**`, `.vale.ini`, `.vale/**`, or the workflow itself changes. It unit-tests the checker in `Development/Tools`, verifies plan and decision-record frontmatter plus index freshness (`plans --check`), lints plan structure with Vale, and prints document lengths as advisory output. It never builds the package.

## Validation

- After changing workflows, run `swift test`.
- Planning documents: `swift test --package-path Development/Tools` (checker unit tests) · `swift run --package-path Development/Tools plans --check` (frontmatter valid, indexes current; omit `--check` to rewrite them) · `vale Development/` (plan structure). All three are fast and need no package build.
