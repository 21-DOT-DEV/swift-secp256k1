# AGENTS.md (Sources)

This directory contains the library implementation — one Swift target, one C-binding target.

## What lives here

- **Swift target**: `P256K` — the library's entire Swift surface. Every `.swift` file under `Sources/P256K/` — the vendored `swift-crypto/` tree included — compiles directly into the target; there is no intermediate copy step.
- **C-binding target**: `libsecp256k1` — the upstream C library `P256K` wraps; vendir-managed (see Extractions).
- **Two `ASN1/` directories, different owners**: `Sources/P256K/ASN1/` is project-owned — copies of the upstream swift-crypto files that `vendir.yml`'s `excludePaths` holds back from the sync; directory names mirror upstream, space in `Basic ASN1 Types/` included, so don't normalize them (the "Syncing local files with upstream" caveat explains why). `Sources/P256K/swift-crypto/Sources/Crypto/ASN1/` is the vendored remainder of the same upstream directory.

## Extractions

These paths are synced copies of upstream sources, managed by vendir — `vendir.yml` (repo root) is the canonical reference, naming each entry's upstream repo, `ref:` pin, and `includePaths`/`excludePaths` filters (it also manages two destinations under `Projects/`, outside this file's scope):

- `Sources/libsecp256k1/` — `bitcoin-core/secp256k1`
- `Sources/P256K/swift-crypto/` — `apple/swift-crypto`

`swift-crypto/LICENSE.txt` and `swift-crypto/NOTICE.txt` ride with the vendored code — Apache-2.0 requires the license text (§4(a)) and the attribution notice (§4(d)); `vendir.yml`'s `includePaths` re-fetches both on every sync — and sit inside the `P256K` target root, so `Package.swift` `exclude`s both (the `COPYING` precedent). Deleting them breaks the license terms; dropping the `exclude` warns about unhandled files on every build.

## If you must patch vendored code (explicit request only)

`vendir sync` wipes each managed path before copying upstream — a committed patch survives in git history but the tree loses it on the next sync. Prefer upstreaming the change and bumping the `ref:` pin. Do not preserve a patch by moving the file into `ignorePaths`: that field carries the project-owned `Utility.{h,c}` shims, and adding a vendored path makes the local copy silently shadow every future upstream change. If a patch is still required, keep it minimal and tightly scoped — no reformatting, renaming, or sweeping refactors — and confirm the pinned `ref:` in `vendir.yml` first.

## Syncing local files with upstream

When a local file derived from vendored code drifts, cross-reference it against its upstream original before editing:

1. Locate the original: `gh api 'repos/<repo>/contents/<path>?ref=<ref>'` — the repo and ref come from the file's `vendir.yml` entry (e.g. `gh api 'repos/bitcoin-core/secp256k1/contents/src/ecmult_impl.h?ref=v0.7.1'`; quote the argument — the `?` glob-aborts zsh unquoted). Path caveat: the `Sources/P256K/ASN1/` files are project-owned copies of upstream `Sources/Crypto/ASN1/…` files (they're in `vendir.yml`'s `excludePaths`) — look up the upstream path, not the local one. No upstream match means the file is fully custom.
2. Categorize each difference. Typically syncable: import changes, `@available` attributes, protocol conformances (`Sendable`, `Hashable`), concurrency annotations (`@preconcurrency`, `nonisolated`, `async`), `#if` conditional-compilation wrappers. Typically preserved: function bodies and algorithms, custom types, project-specific integrations, custom initializers and members — exception: for the `Sources/P256K/ASN1/` copies, upstream body changes can carry parser security fixes, so review those per-change rather than defaulting to preserved. Review case-by-case: access-control changes, documentation.
3. Present the proposed edits before applying any; apply file-by-file and verify the build after each.
