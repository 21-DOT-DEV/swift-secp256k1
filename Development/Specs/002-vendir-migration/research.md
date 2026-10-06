# Research — 002 · Replace git-subtree vendoring with vendir

Evidence behind the migration choices: (1) what the reference repo's migration
actually shipped, (2) a measured sync against this repo's real extraction
config, (3) a provenance subtlety, (4) the fetch-model decision, and (5) the
update-automation landscape.

## 1. Reference implementation: swift-openssl (PR 21-DOT-DEV/swift-openssl#16)

That migration is **hybrid, not full**: `vendir.yml` + a `VendirSync` Swift
executable handle only the Sources/ extraction; `subtree.yaml`, the
`swift-plugin-subtree` dev dep, `Vendor/openssl`, and both subtree workflows
were all kept — the update loop still runs on the subtree CLI. Their shape is
`directory:` sources pointing at a PreSync-managed `.vendir-cache/openssl`
clone, a `scripts/vendir-preserve.txt` restored from git HEAD after each sync,
and a `scripts/vendir-upstream.json` sidecar for provenance (their
`vendir.lock.yml` is content-free and gitignored, since `directory:` sources
resolve nothing).

What transfers: the pinned-binary CI install; `minimumRequiredVersion`. What
does not: the cache + sidecar — it exists because ~6 contents entries all
clone the *same* GB-scale repo; our fan-out is three destinations off one
repo but each is a ~5MB shallow clone, nothing a cache buys back. Their
`vendir-preserve.txt` + restore wrapper stays behind too — vendir's
`ignorePaths` field (carvel-dev/vendir#37, shipped via #64) preserves existing
destination files natively (§2 verified), so no wrapper is needed at all. Our
migration goes further: subtree is retired outright, and `Vendor/` is deleted
rather than kept under either tool.

## 2. Measured verification (vendir 0.46.2, local)

Real `vendir sync` runs were made against all three upstreams at their pinned
refs — `bitcoin-core/secp256k1@v0.7.1` and `apple/swift-crypto@4.5.0` shallow,
`BlockstreamResearch/secp256k1-zkp@08d1cd0` full history — with
`includePaths`/`excludePaths` translated verbatim from `subtree.yaml` (brace
groups included — vendir's doublestar globs expand them; the spec expands them
anyway for greppability):

- **Output is byte-identical** to `Sources/libsecp256k1/` except
  `Utility.h`/`Utility.c` — the exact set `ignorePaths` covers. The same
  holds for `secp256k1-zkp` → `Sources/libsecp256k1_zkp/` (same two preserves,
  plus the planned `COPYING` addition) and `apple/swift-crypto` →
  `Sources/Shared/swift-crypto/` (identical except the planned `LICENSE.txt`).
- **Fetch time**: ~6s for secp256k1 at `depth: 1`; ~13s for the zkp full clone
  and the swift-crypto shallow clone together.
- **`legalPaths` default does not match `COPYING`** — no license file landed;
  `COPYING` goes in `includePaths` explicitly (it replaces the
  `Vendor/secp256k1/COPYING` that `xcframework-release.yml` ships).
- The only non-`.DS_Store` extra files under the three extraction roots are the
  four `Utility.{h,c}` files — nothing else needs preserving.
- `Sources/Shared/swift-crypto/` extracted files were diffed against
  `Vendor/swift-crypto/` originals: zero drift — the drift-sync runbook has no
  live entries today.
- **`ignorePaths` preserves destination files natively** (carvel-dev/vendir#37,
  shipped via #64; field at `pkg/vendir/config/directory.go`). Verified on
  0.46.2: an `include/Utility.h` carrying a local edit came through the sync
  verbatim — on-disk bytes are kept, so uncommitted edits survive too — and a
  declared-but-absent path is a silent no-op. It's a field on the git contents
  itself, so it composes with `path: .` and costs no extra fetches. Caveat: a
  *future* upstream file at one of those exact paths would be silently
  shadowed (none exists today). The `manual:` contents type was also
  evaluated for this and rejected by vendir's own overlap validation
  (`Expected to not manage overlapping paths`) — it can't declare files inside
  a git-populated subtree.
- **Full five-entry config dry-run (0.46.2, `--chdir /tmp`, real refs).**
  `diff -r` against the working tree is empty modulo the declared deltas:
  `Sources/libsecp256k1{,_zkp}` differ only by `+COPYING` (the shims ride
  `ignorePaths`, absent in a bare `/tmp` dest), `Sources/Shared/swift-crypto`
  only by `+LICENSE.txt`; the test bundle holds the whole `tests.c` include
  closure (`secp256k1.c`, `unit_test.h`, `testrand*`/`testutil*`,
  `wycheproof/*.h`, `contrib/lax_der_*.{c,h}`, `include/`, `modules/`) minus
  exactly the seven `main()` sources and `wycheproof/*.json`; Wycheproof lands
  exactly its three files. Two footguns the run exposed, both baked into the
  spec: `contrib/lax_der_*.c` alone misses the sibling `.h` files the `.c`s
  quote-include (the glob is `lax_der_*`), and `includePaths` are matched
  repo-relative *before* `newRootPath` re-roots (bare vector names error out
  with "Expected to find at least one file within directory").

## 3. Provenance note: tag-object SHA vs commit SHA

`subtree.yaml` records `commit: 833ca65…` for `v0.7.1`. `vendir.lock.yml`
records `sha: 1a53f49…` for the same ref. Verified via the GitHub API: `v0.7.1`
is an *annotated* tag — `833ca65…` is the tag **object** SHA and `1a53f49…` is
the commit it peels to (same tree). vendir's lock is strictly better
provenance (commit SHA + `tags:` list + `commitTitle`), but a reviewer diffing
old config against new lock will see different identifiers for the same pin —
this paragraph is the explanation.

## 4. Fetch model

- vendir fetches **once per contents entry, no cross-entry cache**
  (carvel-dev/vendir#101). swift-openssl's pain was ~6 fetches of one GB-scale
  repo; ours is 5 fetches — four shallow plus the zkp pin's deliberate
  `depth: 0` full fetch — ~50–100MB total; secp256k1 alone is fetched three
  times (`Sources/` once, `Projects/` twice).
- **carvel-dev/vendir#453** (first in v0.46.1; commit 1292613, 2026-06-24):
  named refs (tags/branches) take a targeted `git fetch origin <ref>
  --no-tags --depth N` instead of fetching every ref — the reason
  `minimumRequiredVersion` is 0.46.1.
- **Bare-SHA refs still take the old full-fetch-with-tags path**, and at
  `depth: 1` a non-tip SHA can be absent from the fetched window and fail
  checkout — the zkp entry uses `depth: 0` deliberately. (~7MB tree; seconds.)
- `ref: origin/master` + `--locked` was considered for the zkp pin and
  rejected: the locked-mode fetcher verifies the branch head *equals* the
  locked SHA, which breaks the moment upstream `master` moves — a SHA pin is
  the honest encoding of "parked at `08d1cd0`".
- **`http:` tarball sources rejected**: Renovate's vendir manager only
  *extracts* http sources (no ref bumps), and GitHub's auto-generated archives
  changed checksums once already (Jan 2023) — no durable integrity pin.
- `lazy: true` was considered and left off: it skips re-fetch when a contents
  entry's config is unchanged, which saves nothing meaningful at this scale and
  adds a "why didn't it update" debugging surface.

## 5. Update automation

- **Renovate has a native vendir manager**
  (docs.renovatebot.com/modules/manager/vendir/): watches `vendir.yml`, bumps
  `git:`/`githubRelease:` refs, and runs `vendir sync` for lock-file
  maintenance — replacing the check→dispatch→PR loop with a config file.
  **Dependabot has no vendir support** — hence the roadmap's "most Dependabot
  configuration goes": the ecosystems get absorbed, not just deleted.
- The zkp SHA pin updates via Renovate's digest-update flow for git refs —
  workable, but details live in the Renovate PR, not this spec.
- Interim recipe (documented in `AGENTS.md`): edit `ref:` →
  `vendir sync` → check the lock diff (only the bumped entry's `sha:` should
  move — sync re-resolves every entry) → commit → PR on
  `vendor/<name>-<ref>` with the
  `dependencies` label. This is parity with today — `check-subtree-updates.yml`
  already ran on manual dispatch only.

## 6. `Vendor/` consumer inventory (basis for the drop decision)

| Consumer | What it reads | Re-plumb |
|---|---|---|
| `xcframework-release.yml` | `Vendor/secp256k1/COPYING` | `Sources/libsecp256k1/COPYING` via includePaths |
| `Projects/` `libsecp256k1Tests` target | `src/{tests,precomputed_ecmult,precomputed_ecmult_gen}.c` + everything `tests.c` `#include`s (`secp256k1.c`, `include/`, `contrib/lax_der_*`, `unit_test.*`, `testrand*`, `testutil*`, `wycheproof/*.h`) | upstream-layout bundle at `Projects/Sources/libsecp256k1Tests/`; glob narrowed to `src/{tests,precomputed_ecmult,precomputed_ecmult_gen}.c` — the pair defines the `extern` tables `tests.c` links against |
| `WycheproofTests` resources | `src/wycheproof/*.json` ×2 + `WYCHEPROOF_COPYING` | `Projects/Resources/WycheproofTests/secp256k1/` subdir; the two `Vendor/`-backed symlinks get `git rm`'d in the same sync change (vendir owns the subdir, not the parent) |
| `Vendor/AGENTS.md` drift runbook | local upstream originals | folded into `Sources/AGENTS.md`, fetch-on-demand via `gh api` |
| 36 doc comments across `Sources/Shared/**` + `Projects/Sources/**` | `Vendor/…` path mentions | mechanical rewrite to `secp256k1 v0.7.1, src/…` |
| `.gitattributes`, `.swiftformat`, `.swiftlint.yml` | `Vendor/**` exclude/export-ignore lines | dropped; vendored `Projects/` paths + `Sources/Shared/swift-crypto/**` gain linguist-vendored |

Note: `Vendor/` shows ~615MB on disk locally — the bulk is the untracked
`.build/` inside `Vendor/swift-crypto`; the tracked mirror is ~50MB across
1459 files.
