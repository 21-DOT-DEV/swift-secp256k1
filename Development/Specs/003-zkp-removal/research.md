# Research — 003 · Remove the ZKP products and fold shared sources into P256K

Evidence behind the removal: (1) the downstream failures that motivate
killing the build-tool plugin, (2) the release-line timeline, (3) why every
manifest-side alternative fails, (4) the measured case that ZKP's shipped
surface is ≈ zero, and (5) the future-repo design the removal keeps open.

## 1. Downstream failure evidence

Consumer reports linked during planning, all tracing to the build-tool
plugin rather than consumer misuse:

- **buzz-ios-client PR #206** — resolution succeeded, then
  `Plugin "SharedSourcesPlugin" from package "swift-secp256k1" must be
  enabled before it can be used`. Validation is per-invocation: resolving
  the graph does not grant trust.
- **buzz-ios-client PR #136** — the Xcode Cloud workaround: Archive
  accepts no `xcodebuild` flags, so `-skipPackagePluginValidation` is
  unreachable; `ci_post_clone.sh` seeds
  `~/Library/org.swift.swiftpm/security/plugins.json`, keyed to the
  resolved revision in `Package.resolved`. Works, but is consumer-side
  trust seeding — revision-keyed, breaks on every dep bump.
- **aitaco-llc/buzz PR #7** — Xcode 27 support needed dependency updates,
  but `flutter build ios` still failed on plugin validation — the wall
  follows the plugin across toolchains, not just Xcode Cloud.
- **bitchat #1755** — Xcode 27 plugin validation failed with insufficient
  diagnostics; compiling the plugin directly showed PluginAPI surface
  gated unavailable in the relevant SDK.
- **Ruled out**: bitchat #1637 (geohash counting — unrelated); the
  RubenWaterman/DDE1989 commits and samouraiworld PR #1 (the
  `UInt256.words`/`SIMDWordsInteger` ambiguity on the *0.21.1* line — a
  compile fix; current main's UInt256 is two `UInt128` limbs and
  unaffected).

Conclusion: the failure class is "build-tool plugin in a distributed
package." Deletion removes the mechanism's *reason to exist* — the
second Swift target — rather than managing its copies.

## 2. Release-line timeline (verified in git)

`git log --diff-filter=A -- Plugins/SharedSourcesPlugin/` → the plugin
landed in `315e868b` (2025-12-10, "Replace symlinks with build plugin"),
first tagged **0.22.0**; absent from **0.21.1**, whose
`Sources/{P256K,ZKP}/` contain real separately-committed duplicate files
(`git ls-tree 0.21.1` — both `UInt256.swift` blobs mode `100644`). The
plugin era is exactly 0.22.0 → 0.23.2 — every consumer report hits that
range. Pinned consumers hold their tags: 0.23.2 keeps both products
(plugin included); the removal lands at the next tag.

## 3. Why manifest-side alternatives fail

Every mechanism that could vary the product surface per consumer was
evaluated and rejected — the governing rule is that a resolved dependency
graph must mean the same thing to everything that reads it:

- **Traits can't select products** — additive, unified across the graph;
  `Trait.enabledTraits` is declarative, not resolved-state introspection;
  `products:`/`targets:` cannot vary on a consumer's trait selection.
- **`Context.environment` can't either** — manifest evaluation caches on
  manifest *contents*, not ambient env; the var is global while the
  choice is per-consumer; GUI builds don't inherit shell env; and
  `git show vX:Package.swift` would no longer state what vX ships —
  unlike the `gitInformation` gate, whose input is an immutable property
  of the commit.
- **A shared third target** — `libsecp256k1`/`libsecp256k1_zkp` export
  overlapping `secp256k1_*` symbols; linking both collides.
- **Symlinks** — the pre-plugin mechanism (ADR 0001): platform- and
  DocC-fragile.
- **Committed copies + sync script** — the originally spec'd fix
  (earlier draft of this spec): works, carries drift-gate machinery
  forever, and manages a duplication that deletion removes outright.
  Superseded by this design — the same downstream unblocking at
  strictly less machinery.

## 4. Measured: ZKP's shipped surface is ≈ zero

Decisive measurements for choosing deletion over preservation:

- `grep` for all eight zkp-module defines
  (`ENABLE_MODULE_BPPP|ECDSA_ADAPTOR|ECDSA_S2C|GENERATOR|RANGEPROOF|
  SCHNORRSIG_HALFAGG|SURJECTIONPROOF|WHITELIST`) across `*.swift` →
  **only `Package.swift` matches**. The traits compile extra modules
  into `libsecp256k1_zkp` but no Swift file wraps them — ZKP is the
  vanilla API over the zkp C tree.
- `Tests/ZKPTests` *is* the vanilla suite — there is no `P256KTests`;
  `Projects/Sources/P256KTests` symlinks to `Tests/ZKPTests`. Retargeting
  preserves 100% of non-zkp coverage. `Tests/libsecp256k1zkpTests` is a
  one-file C-binding smoke test — dual-import: the Tuist `BindingsTests`
  target already compiles its vanilla (`libsecp256k1` + `P256K`) arm, and
  `keyAgreementHashFunction` cross-validates the Swift wrapper against
  raw `secp256k1_ecdh`. It is retargeted as
  `Tests/libsecp256k1BindingsTests`, not deleted — the vendored upstream
  `tests.c` suite covers C correctness but never exercises the Swift
  importer surface this file guards.
- `SilentPaymentsAPIShapeTests.swift` (phase-10 prototyping) triaged in
  T001 as vanilla-only — retargets with the suite, nothing deleted.
- The vendored swift-crypto tree must stay inside `Sources/Shared/`
  until the fold — ~20 shared files reference its symbols (`Digest`,
  `SecureBytes`, `CryptoKitError`, `ASN1.*`) with no trait gate
  (`Context.swift` uses `SecureBytes` unconditionally); the plugin's
  `find` sweep is `ZKP`'s only source delivery, and
  `Projects/Sources/P256K/Shared → Sources/Shared` is Tuist's. A
  destination move before the fold breaks `swift build` *and*
  `tuist generate`, so the re-destination rides T003's `git mv`, not
  T002.
- Deletion footprint: ~129 files / ~3.8MB — mostly the vendored
  `libsecp256k1_zkp` tree; bulk deletions exempt from the diff budget.
- Consumers using `ZKP` for the *vanilla* surface migrate to `P256K`
  with identical APIs; consumers binding the zkp C modules pin 0.23.2 —
  the manifest already warns the API "may change at any time."

## 5. The future repo this keeps open

When zkp demand funds it, `swift-secp256k1-zkp` is a new repository —
**not** a restore of the deleted target. Its `vendir.yml` pulls three
`git:` sources: `Sources/P256K/**` from *this* repo (the shared surface
stays canonical here — a standalone ZKP compiles it directly, no copies,
since only `libsecp256k1_zkp` ever links), `secp256k1-zkp`, and
`swift-crypto`. Sync rides the existing `vendir-check` gate shape and
the ADR-0007 centralized updater — zero bespoke machinery on either
side. The zkp-tier roadmap phases (6/8/10/11) re-home there; this spec
only updates the roadmap pointers, not the phase content.
