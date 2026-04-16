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
