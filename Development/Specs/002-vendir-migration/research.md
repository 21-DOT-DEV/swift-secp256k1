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
  plus the added `COPYING`) and `apple/swift-crypto` →
  `Sources/Shared/swift-crypto/` (identical except the added
  `LICENSE.txt`/`NOTICE.txt`).
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
  only by `+LICENSE.txt`/`NOTICE.txt`; the test bundle holds the whole
  `tests.c` include
  closure (`secp256k1.c`, `unit_test.h`, `testrand*`/`testutil*`,
  `wycheproof/*.h`, `contrib/lax_der_*.{c,h}`, `include/`, `modules/`) minus
  exactly the seven `main()` sources and `wycheproof/*.json` — under the
  narrowed `*.c`/`*.h` selection the closure is 91 files with no upstream
  build-system files; Wycheproof lands
  exactly its three files. Two footguns the run exposed, both baked into the
  spec: `contrib/lax_der_*.c` alone misses the sibling `.h` files the `.c`s
  quote-include (the glob is `lax_der_*`), and `includePaths` are matched
  repo-relative *before* `newRootPath` re-roots (bare vector names error out
  with "Expected to find at least one file within directory").

## 3. Provenance notes: SHAs, tags, and signatures

`subtree.yaml` records `commit: 833ca65…` for `v0.7.1`. `vendir.lock.yml`
records `sha: 1a53f49…` for the same ref. Verified via the GitHub API: `v0.7.1`
is an *annotated* tag — `833ca65…` is the tag **object** SHA and `1a53f49…` is
the commit it peels to (same tree). vendir's lock is strictly better
provenance (commit SHA + `tags:` list + `commitTitle`), but a reviewer diffing
old config against new lock will see different identifiers for the same pin —
this paragraph is the explanation.

Two smaller lock/provenance subtleties. The `tags:` field is
`git describe --tags <sha>` output (pkg/vendir/fetch/git/git.go) — one
name, not every tag on the commit: `v0.7.1`/`4.5.0` for the tag pins, and
nothing for zkp (the repo has no tags at all — `ls-remote --tags` returns
empty). Drift is narrower than it first sounds: a tag pin drifts only if
`describe` picks a different name; the zkp SHA pin drifts if upstream ever
tags an ancestor commit (`tags: vN-M-g08d1cd0`) — a gate red with no config
change either way, worth knowing when reading a failure. And **signature
verification** is the deferred half of provenance: `v0.7.1` is a GPG-signed
tag (Wuille) and the zkp pin `08d1cd0` a signed merge commit, so a follow-up
CI check runs git/gpg against a committed keyring of known release signers
(Wuille, Ruffing, Nick — sourced from release history, not `SECURITY.md`);
the keyring needs a refresh cadence as signer keys expire (Ruffing's
subkeys were listed as expiring 2026-11-11 at writing). vendir-native
`git.verification.publicKeysSecretRef` was evaluated and deferred —
v0.46.2 verifies through the frozen `x/crypto/openpgp` package; revisit once
a release carries #456 (the go-crypto migration) and timestamp-block parsing
is fixed. swift-crypto can't participate either way — `4.5.0` is a
lightweight tag over an unsigned commit.

## 4. Fetch model

- vendir fetches **once per contents entry, no cross-entry cache**
  (carvel-dev/vendir#101). swift-openssl's pain was ~6 fetches of one GB-scale
  repo; ours is 5 fetches — four shallow plus the zkp pin's deliberate
  `depth: 0` full fetch — ~25MB measured (three ~5MB secp256k1 shallows,
  ~7MB zkp, swift-crypto shallow); secp256k1 alone is fetched three
  times (`Sources/` once, `Projects/` twice).
- **carvel-dev/vendir#453 is still open, not shipped.** Released vendir's git
  fetcher (`pkg/vendir/fetch/git/git.go` at v0.46.2) unconditionally sets
  `remote.origin.tagOpt --tags` and fetches without a refspec unless the ref
  is `origin/`-prefixed — a named tag pulls every ref shallowly under
  `depth: 1`, not one targeted ref. Cheap at secp256k1's size (~6s measured)
  either way, so `minimumRequiredVersion: 0.46.2` pins the verified binary
  rather than a feature.
- **Shallow fetches only reach ref tips** — `depth: 1` pulls every ref's tip
  commit, so a pin that isn't a tip can sit outside the fetched window and
  fail checkout: `08d1cd0` sat 191 commits behind zkp's `master` tip when
  measured (GitHub compare API, Oct 2026 — the number drifts as `master`
  moves), which is why the zkp entry needs `depth: 0`. (~7MB of
  history; seconds.)
- `ref: origin/master` + `--locked` was considered for the zkp pin and
  rejected: under `--locked` the pin holds (`Lock()` swaps `ref:` for the
  lock's `sha:` — pkg/vendir/config/directory.go), but plain `vendir sync`
  — what humans and Renovate's vendir manager run — ignores the lock and
  checks out `master`'s
  tip — the pin would exist only under `--locked`. A SHA `ref:` is the
  honest encoding of "parked at `08d1cd0`".
- **`http:` tarball sources rejected**: Renovate's vendir manager only
  *extracts* http sources (no ref bumps), and GitHub's auto-generated archives
  changed checksums once already (Jan 2023) — no durable integrity pin.
- `lazy: true` was considered and left off: it skips re-fetch when a contents
  entry's config is unchanged, which saves nothing meaningful at this scale and
  adds a "why didn't it update" debugging surface.
- **`skipInitSubmodules: true` on all five**: vendir runs
  `git submodule update --init --recursive` after checkout unless told not to
  (git.go, gated on `!SkipInitSubmodules`). No upstream has a `.gitmodules`,
  so output is unchanged — the flag keeps a future upstream submodule from
  pulling a second repo into the sync.
- **The shared secp256k1 pin rides one YAML anchor** — `ref: &secp256k1-ref
  v0.7.1` on the first entry, `ref: *secp256k1-ref` on the other two. vendir
  0.46.2 accepts it and emits a lock byte-identical to three literal refs.

## 5. Update automation

- **Renovate has a native vendir manager**
  (docs.renovatebot.com/modules/manager/vendir/): watches `vendir.yml`, bumps
  `git:`/`githubRelease:` refs, and runs `vendir sync` for lock-file
  maintenance — replacing the check→dispatch→PR loop with a config file.
  **Dependabot has no vendir support** — hence the roadmap's "most Dependabot
  configuration goes": the ecosystems get absorbed, not just deleted.
- **YAML-anchor compatibility verified on Renovate 44.142.1** — run against
  its own `extractPackageFile` + `doAutoReplace`: the extractor resolves the
  `*secp256k1-ref` aliases (all three secp256k1 deps group into one update),
  the replace edits only the anchor line, and re-extraction reads the new
  value on all three. Scope note: this verified the functions in
  branch-worker order — a full `renovate --platform=local --dry-run=full`
  pass in the Renovate PR is the belt before relying on the anchor. The
  lock-SHA guard stays as a backstop for paths that bypass this — an alias
  replaced by a literal, a future `customManagers` rule, or a changed vendir
  manager.
- The zkp SHA pin does **not** update via Renovate's vendir manager —
  `extractGitSource` puts `git.ref` in `currentValue` on the `git-refs`
  datasource and never sets `currentDigest`, so a bare commit has no ref to
  track. Moving it needs a `customManagers` regex rule (`currentValue:
  master`, the SHA captured as `currentDigest`) *plus* a `vendir sync` step
  — a regex rewrite alone leaves the lock and vendored tree stale (the
  vendir manager's artifact update only covers its own deps); `subtree.yaml`'s
  `branch: master` survives as a `# tracks: master` comment in `vendir.yml`.
  Two managers can also end up owning the pin — `extractGitSource` still
  emits it on `git-refs` — so the PR may need a `packageRules` disable for
  the vendir-manager dep on the zkp URL; the dry run settles it. Details
  live in the Renovate PR.
- Interim recipe (documented in `AGENTS.md`): edit `ref:` →
  `vendir sync` → check the lock diff (only the bumped dep's `sha:`s should
  move — sync re-resolves every entry, and secp256k1's three entries share
  one anchor, so a bump moves them in lockstep; the CI gate enforces the
  same rule on PRs) → commit → PR on
  `vendor/<name>-<ref>` with the
  `dependencies` label. This is parity with today — `check-subtree-updates.yml`
  already ran on manual dispatch only.

## 6. `Vendor/` consumer inventory (basis for the drop decision)

| Consumer | What it reads | Re-plumb |
|---|---|---|
| `xcframework-release.yml` | `Vendor/secp256k1/COPYING` | `Sources/libsecp256k1/COPYING` via includePaths |
| `Projects/` `libsecp256k1Tests` target | `src/tests.c` + `src/precomputed_ecmult{,_gen}.c` + everything `tests.c` `#include`s (`secp256k1.c`, `include/`, `contrib/lax_der_*`, `unit_test.*`, `testrand*`, `testutil*`, `wycheproof/*.h`) | upstream-layout bundle at `Projects/Sources/libsecp256k1Tests/`; sources narrowed to the three literal `.c` files (no `{a,b}` glob — unverified under Tuist) — the pair defines the `extern` tables `tests.c` links against |
| `WycheproofTests` resources | `src/wycheproof/*.json` ×2 + `WYCHEPROOF_COPYING` | `Projects/Resources/WycheproofTests/secp256k1/` subdir; the two `Vendor/`-backed symlinks get `git rm`'d in the same sync change (vendir owns the subdir, not the parent) |
| `Vendor/AGENTS.md` drift runbook | local upstream originals | folded into `Sources/AGENTS.md`, fetch-on-demand via `gh api` |
| 36 doc comments across `Sources/Shared/**` + `Projects/Sources/**` | `Vendor/…` path mentions | mechanical rewrite to `secp256k1 v0.7.1, src/…` |
| `.gitattributes`, `.swiftformat`, `.swiftlint.yml` | `Vendor/**` exclude/export-ignore lines | dropped; vendored `Projects/` paths + `Sources/Shared/swift-crypto/**` gain linguist-vendored |

Note: `Vendor/` shows ~615MB on disk locally — the bulk is the untracked
`.build/` inside `Vendor/swift-crypto`; the tracked mirror is ~50MB across
1459 files.
