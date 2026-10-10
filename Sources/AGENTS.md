# AGENTS.md (Sources)

This directory contains the library implementation (Swift targets and C bindings).

## What lives here

- **Swift targets**: `P256K` (wraps libsecp256k1) and `ZKP` (wraps libsecp256k1_zkp)
- **C binding targets**: `libsecp256k1` and `libsecp256k1_zkp`
- **Shared sources**: `Sources/Shared/` — compiled into both P256K and ZKP via SharedSourcesPlugin. Changes here affect both targets.

## Extractions

These paths are synced copies of upstream sources, managed by vendir — `vendir.yml` (repo root) is the canonical reference, naming each entry's upstream repo, `ref:` pin, and `includePaths`/`excludePaths` filters:

- `Sources/libsecp256k1/` — `bitcoin-core/secp256k1`
- `Sources/libsecp256k1_zkp/` — `BlockstreamResearch/secp256k1-zkp`
- `Sources/Shared/swift-crypto/` — `apple/swift-crypto`

## If you must patch vendored code (explicit request only)

`vendir sync` wipes each managed path before copying upstream — a committed patch survives in git history but the tree loses it on the next sync. Prefer upstreaming the change and bumping the `ref:` pin. Do not preserve a patch by moving the file into `ignorePaths`: that field carries the project-owned `Utility.{h,c}` shims, and adding a vendored path makes the local copy silently shadow every future upstream change. If a patch is still required, keep it minimal and tightly scoped — no reformatting, renaming, or sweeping refactors — and confirm the pinned `ref:` in `vendir.yml` first.

## Syncing local files with upstream

When a local file derived from vendored code drifts, cross-reference it against its upstream original before editing:

1. Locate the original: `gh api 'repos/<repo>/contents/<path>?ref=<ref>'` — the repo and ref come from the file's `vendir.yml` entry (e.g. `gh api 'repos/bitcoin-core/secp256k1/contents/src/ecmult_impl.h?ref=v0.7.1'`; quote the argument — the `?` glob-aborts zsh unquoted). Path caveat: the `Sources/Shared/ASN1/` files are project-owned copies of upstream `Sources/Crypto/ASN1/…` files (they're in `vendir.yml`'s `excludePaths`) — look up the upstream path, not the local one. No upstream match means the file is fully custom.
2. Categorize each difference. Typically syncable: import changes, `@available` attributes, protocol conformances (`Sendable`, `Hashable`), concurrency annotations (`@preconcurrency`, `nonisolated`, `async`), `#if` conditional-compilation wrappers. Typically preserved: function bodies and algorithms, custom types, project-specific integrations, custom initializers and members — exception: for the `Sources/Shared/ASN1/` copies, upstream body changes can carry parser security fixes, so review those per-change rather than defaulting to preserved. Review case-by-case: access-control changes, documentation.
3. Present the proposed edits before applying any; apply file-by-file and verify the build after each.
