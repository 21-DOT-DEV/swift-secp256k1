# AGENTS.md (Vendor)

This directory contains vendored upstream sources managed by `subtree.yaml`.

## Boundaries (strict)

- Do not edit files under `Vendor/**` unless you were explicitly asked to patch vendored code.
- Prefer updating vendored code via the subtree workflow rather than manual edits.
- If you need to change behavior, prefer making the change upstream and then updating the subtree.

## If you must patch (explicit request only)

- Keep changes minimal and tightly scoped.
- Avoid reformatting, renaming, or sweeping refactors.
- Verify the subtree entry in `subtree.yaml` (remote/tag/commit) before editing.
- Ensure changes remain upstream-syncable.

## Extractions (Vendor → Sources)

This file is the canonical reference for extraction mappings. The subtree CLI uses `subtree.yaml` to extract selected files from Vendor into Sources:

- `Vendor/secp256k1` → `Sources/libsecp256k1/`
- `Vendor/secp256k1-zkp` → `Sources/libsecp256k1_zkp/`
- `Vendor/swift-crypto` → `Sources/Shared/swift-crypto/`

## Syncing local files with upstream

When a local file derived from vendored code drifts, cross-reference it against its upstream original before editing:

1. Locate the original: `find Vendor/ -name "<filename>" -type f`. If multiple matches exist, pick the entry named in `subtree.yaml`; no match means the file is fully custom.
2. Categorize each difference. Typically syncable: import changes, `@available` attributes, protocol conformances (`Sendable`, `Hashable`), concurrency annotations (`@preconcurrency`, `nonisolated`, `async`), `#if` conditional-compilation wrappers. Typically preserved: function bodies and algorithms, custom types, project-specific integrations, custom initializers and members. Review case-by-case: access-control changes, documentation.
3. Present the proposed edits before applying any; apply file-by-file and verify the build after each.
