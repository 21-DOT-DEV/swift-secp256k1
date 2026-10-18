---
adr: 0008
title: ZKP products are removed; shared sources fold into the single P256K target
status: Accepted
date: 2026-10-16
supersedes: [0001]
superseded_by: null
---

# 0008 — ZKP products are removed; shared sources fold into the single P256K target

## Context

`SharedSourcesPlugin` copies `Sources/Shared/*.swift` into both targets at
build time — which means every consumer must satisfy SwiftPM's plugin-trust
validation to compile the package. Xcode Cloud's Archive step accepts no
`xcodebuild` flags (so `-skipPackagePluginValidation` is unreachable and
consumers seed `~/Library/org.swift.swiftpm/security/plugins.json` from
`ci_post_clone.sh`), and Xcode 27's validator fails with no useful
diagnostic. Meanwhile a source-level audit showed ZKP's *distinct* shipped
surface is essentially zero: its eight `ENABLE_MODULE_*` traits compile
extra modules into `libsecp256k1_zkp`, but no Swift file wraps them — the
`ZKP` product is the vanilla API linked against the zkp C tree, and the
entire sharing machinery exists only because two targets compile the same
files.

## Decision

Remove the `ZKP` and `libsecp256k1_zkp` products, targets, and trait
set. `Sources/Shared/` folds into `Sources/P256K/` — one Swift
target means the shared-source mechanism needs no replacement: no plugin,
no copies, no sync script, no drift gate. `Sources/libsecp256k1_zkp/` and
its vendir entry are deleted; vendored swift-crypto moves to
`Sources/P256K/swift-crypto/` as a single vendir destination.
`Tests/ZKPTests` — the vanilla suite — becomes `Tests/P256KTests` against
`import P256K`; `Tests/libsecp256k1zkpTests` — the C-binding smoke suite —
becomes `Tests/libsecp256k1BindingsTests` against `import libsecp256k1`
(the Tuist `BindingsTests` target already compiled its vanilla arm).
*(amended 2026-10-17: test-target disposition corrected —
`Tests/libsecp256k1zkpTests` was dual-import, not zkp-only, so it
retargets as `Tests/libsecp256k1BindingsTests` instead of deleting)*
ZKP-tier work (the zkp-module APIs, phases 6/8/10/11) is
deferred to a future dedicated `swift-secp256k1-zkp` package that vendirs
the shared surface from this repo — recorded in the roadmap backlog.

## Alternatives considered and rejected

- **Keep the build-tool plugin**: its trust requirement is the reported
  consumer failure; nothing manifest-side removes it.
- **Committed copies + a sync/check gate**: works, but builds permanent
  machinery to manage a duplication that deletion removes outright —
  rejected in favor of the simpler end state.
- **Extract ZKP to a live repo now**: 2–3× the work plus a second release
  train and a forced consumer migration; deletion keeps that door open
  without paying it today.
- **A shared third target**: `libsecp256k1`/`libsecp256k1_zkp` export
  overlapping `secp256k1_*` symbols — link-time collisions.
- **Trait- or environment-conditioned products**: traits are additive and
  invisible to manifest code; `Context.environment` makes the manifest
  depend on ambient process state rather than the commit — a package's
  surface must be consumer-invariant.
- **Symlinks**: the pre-plugin mechanism — platform- and DocC-fragile.

## Consequences

Consumers build with zero plugins — no trust prompt, no flag, Xcode Cloud
works out of the box — at the price of a breaking change: `.product(name:
"ZKP")` fails at resolution with a clear error. Vanilla users migrate to
`P256K` with identical APIs; true zkp-module consumers pin `0.23.2` until
the dedicated package exists. The package loses its second release surface
but gains its simplest possible shape: one Swift target, one C target, no
sharing mechanism. DocC collapses to a single archive and the
path-rewrite tooling retires. The deletion is reversible — git history
preserves every deleted file, and the future-repo design is recorded.
