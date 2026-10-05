---
adr: 0004
title: XCFramework builds are pinned to Xcode 27 and verified as shipped, never post-edited
status: Accepted
date: 2026-10-01
supersedes: []
superseded_by: null
---

# 0004 — XCFramework builds are pinned to Xcode 27 and verified as shipped

## Context

The `P256K` XCFramework's `enum P256K` collides with the `P256K` module name.
Xcode 27's interface emitter writes the `P256K::P256K` module-selector spelling
that resolves the collision (swiftlang#56573); earlier toolchains do not, and
rewriting emitted `.swiftinterface` files after the fact proved fragile. A
second hazard is independent: leaked `_secp256k1_*` symbols in a shipped
framework bind silently to a consumer's own libsecp256k1 under `-dead_strip`.

## Decision

Pin both build pipelines to Xcode 27 (Bitrise `osx-xcode-27.0.x`; GitHub
`xcode-27` + `DEVELOPER_DIR`), emitting module selectors explicitly via
`-enable-module-selectors-in-module-interface`. Ship interfaces exactly as the
compiler writes them — no post-edit — and gate the release twice:
`-verify-emitted-module-interface` typechecks every emitted interface during
the archive itself, and `Scripts/verify-p256k-xcframework.sh` checks the
per-slice export allowlist and runs a real consumer build of the shipped
artifact for every shipped platform.

## Alternatives considered and rejected

- **Post-editing emitted interfaces**: replaced — the rewrite is exactly what
  drifted; the shipped artifact is now verified instead.
- **Older toolchains**: cannot emit the module-selector spelling at all.
- **The prelink allowlist alone**: necessary but insufficient — it whitelists
  exports, while the verifier proves what a consumer can actually import and
  link.

## Consequences

Binary consumers need Swift ≥ 6.3 to read the module interfaces. Release
correctness is asserted against the artifact that actually ships, and the
export contract (`_$s*` + `_P256KVersion*` only) is tripwired rather than
assumed.
