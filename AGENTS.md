# AGENTS.md (swift-secp256k1)

This repository is a Swift implementation/wrapper of secp256k1 (+ ZKP) for the Bitcoin and Nostrecosystem.

## Global guidance

- Keep changes small and reviewable.
- Do not introduce new third-party dependencies without asking.
- Avoid outputting or logging secrets. In this repo’s context, do not emit private keys or sensitive vectors into logs/output.

## Validation

- Prefer validating changes with `swift test`.
- Formatting and linting are enforced by repo configuration (SwiftFormat/SwiftLint) and hooks.

## Scoped guidance

These files provide directory-specific deltas (Windsurf applies them automatically based on the file you’re working in):

- `Sources/AGENTS.md`
- `Tests/AGENTS.md`
- `Projects/AGENTS.md`
- `Vendor/AGENTS.md`
- `.github/AGENTS.md`

## Auditing and maintenance

- If guidance seems to be missing, open a file under the directory you care about and ask Cascade to summarize the active `AGENTS.md` instructions for that file.
- Keep scoped `AGENTS.md` files limited to deltas; avoid duplicating global guidance.
- Update `AGENTS.md` when build/test workflows change (e.g. Swift toolchain, Tuist, `xcodebuild` invocation).
