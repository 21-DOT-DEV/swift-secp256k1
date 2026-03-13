# AGENTS.md (.github)

This directory contains GitHub configuration and CI workflows.

## Boundaries (strict)

- Do not broaden GitHub Actions `permissions` without a clear justification.
- Do not print or log secrets/tokens.
- Do not add new third-party actions without asking.

## Workflow conventions

- Preserve least privilege defaults (this repo commonly uses `permissions: {}` at workflow and job levels).
- Prefer `env:` blocks over inline interpolation inside shell scripts.
- Avoid fragile shell output capture for UTF-8/multiline content; prefer temp files and tools like `jq` reading from files.

## Validation

- After changing workflows, run `swift test`.
