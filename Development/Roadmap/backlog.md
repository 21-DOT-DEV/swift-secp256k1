# Backlog: Future Consideration

**Purpose**: Items deferred for future consideration, not currently scheduled as phases  
**Last Updated**: 2026-10-22

> Items with strong downstream demand were **promoted to first-class phases** (see [roadmap](README.md)): adaptor signatures & MuSig2-L2 (Phase 6), HD-wallet / BIP-32 serialization (Phase 7), Cashu BDHKE + DLEQ (Phase 8), Silent Payments & ellswift (Phase 10), FROST & half-aggregation (Phase 11). General-purpose crypto (ChaCha20, AES, scrypt, SHA-3) is **sourced from swift-openssl** per the Package Separation section — not a backlog item.

---

## Tooling: Mermaid diagram validation in CI

**Status**: Deferred — specced separately, not part of spec 004's wave
**Priority**: Low — the absence costs a broken diagram surviving review, not a broken build
**Notes**: The diagram rule landed by convention only (`Development/README.md` → "Design diagrams") on 2026-10-22, with CI deferred here. Two gates were researched: **structural** — a Tengo-script Vale rule (Vale runs arbitrary per-document logic on fenced blocks; it cannot invoke external programs, so it enforces the *presence* policy only: a `plan.md` Design section covering ≥3 interacting parties with no mermaid fence warns, scoped to `Development/Specs/**`); **syntax** — render-validation with the official `ghcr.io/mermaid-js/mermaid-cli/mermaid-cli` image pulled by sha256 digest (the Vale/vendir pinned-binary pattern, and the repo already runs Docker in `docker-builds.yml`). Decision (2026-10-22): **Docker image only** — the npm-based lighter alternative (@mermaid-lint/cli) was evaluated and proofed against the spec-004 exemplar, then rejected as a new toolchain/supply surface; no Node packages in this repo's CI. Do **not** use pandoc (no Mermaid evaluation) or SwiftLint (Swift-source-only) — both ruled out by research on 2026-10-22. Vale's limitation is documented by its own project: external program invocation was requested and closed not-planned (`vale-cli/vale#939`); its scriptable check point (Tengo, per-block) does string logic only. Image size verified against the Docker Hub tag listing (~1.0 GB compressed, `minlag/mermaid-cli:12.0.1`) — and proven to be the same artifact as the chosen GHCR image: the official index's per-platform digests (`30a3ca1a…`, `3343ce06…`) are letter-identical to the hub tag's, and digests are content addresses; `minlag` is the tool maintainer's hub account. New jobs follow `.github/AGENTS.md` conventions (`permissions: {}`, no new third-party actions).
**Acceptance**: A `Development/Specs/` entry adds both checks to `development-docs.yml` (or a sibling workflow); a deliberately broken diagram fails the job; the Vale structural rule fires on purpose.

---

## Tooling: generated namespace-inventory diagrams

**Status**: Deferred — evaluate when a real consumer asks what a namespace exposes
**Priority**: Low — sketch-grain diagrams in plans cover the communication need today
**Notes**: Complete member maps of a namespace (e.g. everything under `P256K.Schnorr`) are never hand-drawn (they rot by design — Fowler's blueprint-mode failure); generate them from source with SwiftPlantUML (SourceKitten-based, and SourceKitten is already a dev dependency) on demand or periodically. Output is PlantUML text; convert to committed SVG if it must appear where GitHub is not the renderer.
**Acceptance**: A documented command produces the inventory diagram for a named namespace; the artifact carries a generation date.

---

## Future package: `swift-secp256k1-zkp`

### Extract the zkp product line into a dedicated package

**Status**: Deferred — to be specced when zkp demand funds it (spec 003 / ADR 0008)  
**Priority**: Low — gated on demand, not machinery  
**Notes**: A new repository, not a restore of the removed targets. Its `vendir.yml` pulls two `git:` sources: this repo's `Sources/P256K/**` — the shared Swift surface stays canonical here, and the pull carries the vendored `swift-crypto/` subtree and `P256K.docc` with it, keeping both version-coupled to the surface they serve (a separate `apple/swift-crypto` source is the variant for independent bumps, but then the P256K pull needs `excludePaths` on `Sources/P256K/swift-crypto/**` or the tree double-vendors — duplicate `Digest`/`SecureBytes` definitions) — and BlockstreamResearch's `secp256k1-zkp` (resume point: this repo's last pin `08d1cd0c`, which predates the fork's `frost` module). Two target names do the work: the C target is named `libsecp256k1` so the pulled `import libsecp256k1` lines resolve verbatim — the post-removal import sweep left zero zkp-conditional imports — and SwiftPM's graph-wide target-name uniqueness then makes the two packages mutually exclusive at resolution, which is exactly the drop-in-replacement property (a consumer needing both could try `moduleAliases`, untested through the vendored imports); the Swift target is named `P256K`, making migration manifest-only — `import P256K` and the `P256K.*` API are unchanged. The future manifest re-declares the zkp module traits against the fork's `ENABLE_MODULE_*` defines; sync rides the existing `vendir-check` gate shape and the ADR-0007 centralized updater — no bespoke machinery on either side. The `rust-secp256k1-zkp` precedent nuances the model: it re-exports vanilla `rust-secp256k1` and its `-zkp-sys` crate prefix-renames every vendored symbol so both coexist — our vendir no-patch rule can't carry symbol renaming, so module-name exclusivity is the honest equivalent. Candidate scope — everything that needed the fork's C: Phase 6's adaptor-signature feature (`ecdsa_adaptor`; the fork's `musig` module also adds a zkp-only `adaptor` arg to `secp256k1_musig_nonce_process` — Schnorr adaptor signatures), Phase 11's Schnorr half-aggregation (`schnorrsig_halfagg`), FROST, and the un-phased modules below — vendored here through `0.23.2`, never wrapped:

| C module | Capability | Cohort | Priority |
|----------|-----------|--------|----------|
| `secp256k1_ecdsa_s2c` | Sign-to-contract / anti-exfil | Bitcoin | Low |
| `secp256k1_rangeproof` / `secp256k1_surjectionproof` | Confidential assets | Liquid-style | Low |

The fork's remaining experimental modules (`generator`, `bppp`, `whitelist`) were vendored but never wrapped and carry no demand signal.

**Acceptance**: A `Development/Specs/` entry scopes the package in its own repo; `vendir sync` reproduces both sources; the result builds with zero plugins.

---

## Tooling: upstream v0.7.1 → v0.8.0 pin bump + extended upstream test vendoring

**Status**: Deferred — deliberately excluded from spec 004's wave (decision 2026-10-22); specced separately  
**Priority**: Medium — the pin is one released version behind; upstream ran at 16 iterations exit-0 here on 2026-10-22, so there is no urgency signal  
**Notes**: v0.8.0 (upstream tag from 2026-08-03) is backward-compatible with what this package uses: the only removed symbols are `secp256k1_context_no_precomp` and the deprecated `secp256k1_schnorrsig_sign`, neither of which has a call site in the package's own wrapper or test code — hits exist only inside the vendored trees (`Sources/libsecp256k1/` declarations, plus `Projects/Sources/libsecp256k1Tests/`'s `tests.c:192` and `tests_impl.h:824`, which check those very aliases and whose deletion the lockstep bump carries) plus a doc mention. Adds a Silent Payments module (BIP-352; shaped API already has a `SilentPaymentsAPIShapeSuite`), an `secp256k1_context_set_sha256_compression` hook (hardware SHA-256), and field-arithmetic speedups that matter mostly on GCC/MSVC. Behavioral change to note: `secp256k1_ellswift_xdh` now rejects secret keys at or above the curve order — pair the bump with the outstanding wrap-or-drop decision on the `ellswift` trait. Precedent per `vendir.yml`'s documented flow: edit the shared `&secp256k1-ref` anchor → `vendir sync` → review the lock delta → run `libsecp256k1Tests` → PR on a `vendor/libsecp256k1-*` branch. In the *same* spec, extend `Projects/Sources/libsecp256k1Tests` vendoring to upstream's exhaustive and constant-time suites (`tests_exhaustive.c`; the MSan/Valgrind-driven `ctime_tests` machinery, which needs the upstream configure-time defines and is exactly the part plain `swift test` cannot pick up).
**Acceptance**: `vendir sync` lands the v0.8.0 SHA on all three secp256k1 entries in lockstep (the fourth `vendir.yml` source is apple/swift-crypto, unchanged); full test battery + `libsecp256k1Tests` pass on the bumped tree; the new suites execute in CI.

---

## Niche / deprecated primitives

| Item | Notes | Priority |
|------|-------|----------|
| **SipHash-2-4** | Zone C (built-here low; swift-openssl fallback). Needed by the BIP-152/158 filters below | Low |
| **MurmurHash3 (32-bit)** | BIP-37 Bloom filters; deprecated, not in OpenSSL → only if a consumer needs it | Low |
| **Strict DER validation (BIP-66)** | Likely already handled by libsecp256k1; review only | Low |

---

## Data Structures

General-purpose structures supporting specific BIPs (in-repo vs recommend-external is undecided):

| Item | BIP | Notes |
|------|-----|-------|
| **Bloom Filters** | BIP-37 | Uses MurmurHash3; deprecated (privacy); low |
| **Golomb-Coded Sets** | BIP-158 | Uses SipHash; modern filter; medium if SipHash is built |
| **Merkle Trees / taptrees** | BIP-341 | Tagged-hash based; medium-high for Taproot completeness |

---

## Deferred applications (CLIs)

**Promoted 2026-08-01**: the CLI tools (MuSig2 CLI, address generator, ECDSA signing CLI, Schnorr verifier) were promoted from this backlog to **Phase 9.5 — Command-Line Tool** for the 2026 funding window (Q5 of the shared 2026 roadmap). See [phase-9.5-cli-tool.md](phase-9.5-cli-tool.md).

---

## Platform Support

### Windows Build Support

**Status**: Deferred — no plugin-era blocker remains  
**Priority**: Low (Windows is not a primary Swift platform)  
**Notes**: The `SharedSourcesPlugin`'s POSIX `find + cp` blocker retired with the plugin (spec 003); what is left is a Windows CI runner plus whatever portability fixes `Sources/P256K` and the vendored C tree still need — none of it re-verified since the removal.  
**Acceptance**: `swift build` succeeds on Windows without symlink errors; Windows CI job passes.

---

## Hardening

### Fixed-size input validation across the C boundary

**Status**: Done — landed with the recoverable-signature validation fix (2026-10-20); digest sites later refined to SEC1 normalization  
**Priority**: Medium — memory-safety hardening; every remaining site is an out-of-bounds *read* on a caller-provided length (the only out-of-bounds *write*, `session_secrand32`, was fixed with the MuSig work)  
**Notes**: Public `[UInt8]`/`Digest` parameters reach upstream functions that read a fixed 32 bytes with no length check — a short input reads out of bounds. Fixed-size *non-digest* inputs guard `count == P256K.ByteLength.dimension` before the C call: `Schnorr+Tweak.swift` `add(_ tweak:)` ×2, `Schnorr+Signature.swift` `signature(for:auxiliaryRand:)` (`ndata`), `ECDSA+Tweak.swift` `add`/`multiply` ×4, `MuSig+Tweak` ×2, MuSig `extraInput32`/`SessionSecretRand`. *Digest* inputs (semantically `msg32`, not fixed byte strings) are instead normalized per SEC1 §4.1.3 — leftmost-32 for longer digests, integer value for shorter — at `ECDSA` sign/verify, `Recovery` sign/recover, MuSig `partialSignature`/`partial_sig_verify`, and `Nonce.generate(msg32:)`; that matches Go `crypto/ecdsa`, OpenSSL, and FIPS 186-5, and restored the released non-throwing signing signatures. A follow-up sweep of the same defect class — public bytes reaching a *fixed-size* C read — closed two more paths: `Signing.ECDSASignature.init(compactRepresentation:)` (fixed-64 `ecdsa_signature_parse_compact` → `incorrectParameterSize`) and malformed-length `Schnorr`/`MuSig`/`Signing` `XonlyKey`s reaching the fixed-32 `xonly_pubkey_parse`. The x-only fix lands at construction: `XonlyKey.init` validates length *and* curve-point membership via `xonly_pubkey_parse`, so a malformed x-only key is unrepresentable — `isValid`, `add`, `init(xonlyKey:)`, and `negation`'s `fatalError` all inherit the invariant instead of each guarding it.  
**Acceptance**: Every public `[UInt8]`/`Digest` input feeding a fixed-size C read is normalized or length-checked before the call; regression test per site; `swift test` green.

### Full opacity for MuSig session and key-aggregation-cache state

**Status**: Deferred from the MuSig opaque-state hardening (2026-10-24)  
**Priority**: Medium — defense-in-depth; current size+magic checks are best-effort, not real parsing  
**Notes**: Upstream v0.7.1 exposes no serialize/parse API for `secp256k1_musig_session` (133 bytes) or `secp256k1_musig_keyagg_cache` (197 bytes), so `PartialSignature.init(dataRepresentation:session:)` and the cache-accepting `XonlyKey`/`PublicKey` inits can only check exact size plus the 4-byte magic prefix (`{0x9d,0xed,0xe9,0x17}` / `{0xf4,0xad,0xbb,0xdf}`) before copying into C structs — a crafted blob with a valid prefix but corrupt body still reaches `session_load`/`keyagg_cache_load` (whose `ARG_CHECK` then aborts the process). The durable fix is architectural: stop exposing these structs as persistable `Data` at all — keep them as in-process-only tokens inside the producing/consuming types (session never leaves the `partialSignature`→`aggregateSignatures` flow), or expose them behind a validated, versioned container type with its own integrity tag — pending either upstream serialize/parse APIs or a documented decision to define our own wire format. Cross-check `secp256k1-zkp`'s fork before designing: it may already expose serialization the vanilla pin lacks.  
**Acceptance**: A `Development/Specs/` entry records the decision; either session/cache are no longer externally constructible from raw bytes, or a real parse/serialize boundary exists; `swift test` green.

### `keyagg_cache` input on MuSig nonce generation

**Status**: Deferred from the MuSig nonce-generation fix (2026-10-18)  
**Priority**: Medium — misuse-resistance hardening  
**Notes**: BIP-327 recommends feeding the aggregate public key into nonce derivation as defense-in-depth; `secp256k1_musig_nonce_gen` takes it as `keyagg_cache`, which `Nonce.generate` currently passes as `nil`. An optional `publicKeyAggregate:` parameter (accepting `P256K.MuSig.PublicKey`, which already carries the 197-byte cache) would expose it. Once exposed, BIP-327 nonce-gen vector case 1 (`aggpk` set) becomes reproducible at the Swift layer — the vector suite currently skips it with that reason stated. Motivate by misuse resistance, not vector coverage.  
**Acceptance**: `generate` accepts an optional aggregate key and forwards its cache to upstream; BIP-327 case 1 verifies `expected_pubnonce`/`expected_secnonce` exactly.

### Secret-material copies → direct `SecureBytes` pointers

**Status**: Done — landed (2026-10-22)  
**Priority**: Medium — secret-material hygiene  
**Notes**: Scrubbing copies after the fact does not hold up in Swift: `SecureBytes.bytes` makes a fresh plain `[UInt8]` on every call, expression-level temporaries like `seckey_verify(ctx, key.bytes)` are unreachable by `defer`, and copy-on-write can leave unseen duplicates. The durable fix is to stop copying — every `.bytes` read on `SecureBytes` and every `Array(secretMaterial)` reaching C in `Sources/P256K` now passes `withUnsafeBytes`/`withUnsafeMutableBytes` pointers straight into the C calls (`PrivateKeyImplementation`, the ECDSA/Schnorr/MuSig tweak methods, signing, ECDH), and `Context.create()` passes its `SecureBytes` seed pointer directly to `secp256k1_context_randomize`. The pointer borrows go through internal `withUnsafeBytePointer` / `withUnsafeMutableBytePointer` / `withUnsafeMutableBytes(boundTo:)` helpers so call sites pass a non-optional typed pointer straight into `ARG_NONNULL` parameters; helper guards report through `P256K.invariantFailure`, not `precondition` (which `-Ounchecked` compiles out). The sweep covers the write side too: C secret outputs land directly in `SecureBytes` storage via `init(unsafeUninitializedCapacity:)` (ECDH shared secret, `keypair_sec` tweak output), `secp256k1_musig_secnonce` is bound into `SecureBytes` storage so `nonce_gen`/`partial_sign` write and zero it in place, and `secp256k1_keypair` locals are `memset_s`-scrubbed after their last use. Regressions are blocked at compile time rather than by lint: the accessor — renamed `byteArray` because Foundation's `Data.bytes` (`RawSpan`) shadows any extension member on newer SDKs, with `.bytes` kept as a deprecated alias — is declared on `ContiguousBytes where Self: CopyableBytes`, a marker protocol `SecureBytes` deliberately does not conform to, so `.byteArray` on `SecureBytes` fails to build (`requires that 'SecureBytes' conform to 'CopyableBytes'`). An `@available(*, unavailable)` shadow was tried first and rejected: it could shadow only concrete-typed call sites, while generic `D: ContiguousBytes` call sites see just the protocol extension and resolve the available member regardless — the marker constraint covers both. A SwiftLint custom rule cannot see types and would false-positive on public byte access. `CopyableBytes` conformances ship for `Data`, `Array`, `ArraySlice`, `SharedSecret`, `HashDigest`, the `ECDSASignature`s, `SchnorrSignature`, `Schnorr.Nonce`, `MuSig.Nonce`, `MuSig.AggregateSignature`, and `Schnorr.PartialSignature` — every public type whose API already permits byte extraction. Known leftover: PEM/DER decode paths materialize `[UInt8]` key intermediates (`Array(pem.derBytes)`, parsed `privateKey` fields) — a small marginal leak beside the caller-supplied `String`/`Data` representation whose lifetime already spans the copy; revisit only if a `SecureBytes`-native DER path lands. `SecurityConsiderations.md` carries the honest note that Swift wiping is best-effort — the compiler may still spill secrets to registers or the stack.  
**Acceptance**: No `.byteArray`/`.bytes`/`Array(...)` secret-material copy reaches a C call in `Sources/P256K`; `Context.create()` passes the `SecureBytes` pointer directly; `.byteArray` on `SecureBytes` fails to compile; `SecurityConsiderations.md` carries the best-effort note; `swift test` green.

### Upstream doc links track the vendir pin

**Status**: Split out of the MuSig nonce fix into its own PR (2026-10-18) — drafted, then reverted to keep the security diff pure  
**Priority**: Low  
**Notes**: `Sources/P256K` doc comments link `bitcoin-core/secp256k1` headers on `blob/master`; the vendir pin is `v0.7.1` = commit `1a53f4961f337b4d166c25fce72ef0dc88806618` — verified 2026-10-18: the annotated tag dereferences to the `vendir.lock.yml` SHA (`git ls-remote … refs/tags/v0.7.1^{}`), so `blob/v0.7.1` URLs resolve to the vendored tree. The repoint sweeps ~35 URLs across `Sources/P256K` (incl. 2 `.docc` articles) and should land as a dedicated change; a pin bump should re-sweep the same URLs. Optional automation: extend `Scripts/vendir-check.sh` with a link-consistency probe against the locked ref. `SECURITY.md`'s upstream `SECURITY.md` link correctly stays on `master` (a living policy doc, not pinned code).

---

## Documentation

### Re-evaluate the `Snippets/` directory (SE-0356)

**Status**: Deferred — the duplicate `secp256k1_*`-symbol blocker retired with the `libsecp256k1_zkp` product (spec 003 / ADR 0008); ADR 0003 recorded the original call  
**Priority**: Low — documentation nicety; fenced ` ```swift` blocks in catalog articles already carry examples  
**Notes**: SE-0356 snippet targets auto-link every library product in the package, so the two-C-product collision that motivated ADR 0003 can no longer occur — `P256K` already depends on `libsecp256k1`. Unvalidated: the DocC `@Snippet` pipeline is untested on the pinned toolchain, and snippets build only under `swift build --build-snippets`, so adoption needs a CI leg or they rot unbuilt. Per-snippet dependency scoping is still unshipped upstream — snippets can import only host-package modules (`P256K`, `libsecp256k1`), which suffices.  
**Acceptance**: A spec (`Development/Specs/NNN-*`) decides the shape; a `Snippets/` file compiles under `swift build --build-snippets`, a `@Snippet` directive renders in the P256K DocC archive, and CI gains a snippet-build leg.

### DocC symbol extraction fails under Xcode 27.0

**Status**: Known limitation — pre-existing, cause unconfirmed; unrelated to spec 003  
**Priority**: Low — workaround in place  
**Notes**: DocC archive builds fail at symbol extraction under Xcode 27.0, so the DocC-producing jobs — `apple-builds.yml`'s DocC Validation and `docc-release.yml` — pin Xcode 26.4 by hand (`development-docs.yml` pins the same toolchain, though its plans-checker and Vale work never produces a DocC archive) while `xcframework-release.yml` and Bitrise already run 27.0 — whoever aligns the pins trips this. The 26.4 pins are the documented workaround until the failure is diagnosed.  
**Acceptance**: DocC archives build clean under Xcode 27.0 and the hand-pins drop.

---

## Prioritization Criteria

When promoting an item from backlog to a phase:
1. **Downstream reach** — how many in-scope cohorts need it (RICE)
2. **Spec coverage** — fills a real BIP/NIP/NUT/BOLT gap
3. **Dependency chain** — unblocks other work (WSJF opportunity-enablement)
4. **Effort** — cheap overlaps (SHA-2 tower) before standalone primitives
5. **Scope alignment** — secp256k1-native or Bitcoin-utility; general crypto → swift-openssl

---

## Adding to Backlog

New items should include: **Purpose**, **spec reference** (if any), **dependencies**, **priority signal** (with rationale), and **notes**.
