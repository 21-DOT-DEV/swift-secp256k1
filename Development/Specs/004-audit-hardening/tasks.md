# Tasks — 004 · Audit-hardening wave

Ordered work for [the plan](./plan.md); measured evidence in
[research.md](./research.md).

Format: `- [ ] TNNN [P?] what lands · files`. Each entry is one
reviewable change — one commit/PR-sized unit an independent agent can
implement from its description alone. Breaking change-sets extend the
`CHANGELOG.md` migration section and state the replacement symbol in the
same diff. The wave ships as multiple PRs; boundaries named below; inside a
PR, commit order follows group order. No task touches the vendored trees
(`Sources/libsecp256k1/`, `Sources/P256K/swift-crypto/`) or `vendir*.yml`.

## Group A — Versioning artifacts (PR 1)

- [ ] T001 [P] README pin advice: replace the `exact: "0.24.0"` dependency
      example (`README.md:39`) with `.upToNextMinor(from: "0.24.0")` plus one
      sentence explaining that SwiftPM's `from:` spans every 0.x below 1.0.0
      and why the minor is the stability boundary pre-1.0, and one sentence
      stating the example moves to `0.25.0` when that tag is cut (the
      tag-time bump lives in the release task T017 — never name an
      untagged version in a published example) · `README.md`
- [ ] T002 Constitution consumer-advice amendment: in the Versioning &
      Stability section of `Development/constitution.md`, replace "Users
      advised to pin exact versions" with `.upToNextMinor(from:)` advice and
      a one-line rationale pointing at the Apple swift-configuration pre-1.0
      wording; bump the document's version/changelog block ·
      `Development/constitution.md`
- [ ] T003 [P] Migration-note skeleton: CHANGELOG `[Unreleased]` gains the
      wave's section header and the standing instruction reproduced verbatim
      ("each breaking change lands with its replacement named here; tag cut
      after the last breaking change, never between") · `CHANGELOG.md`

**Checkpoint:** a consumer reading README today learns the correct
pre-1.0 constraint; the constitution's advice no longer contradicts the
wave; `swift run --package-path Development/Tools plans --check` and
`vale Development/` pass.

## Group B — Schnorr signing/verification redesign (PR 2, the wave's largest)

- [ ] T004 Replace `signature(message:auxiliaryRand:strict:)` with the
      five-method surface of plan §3.1: `signature(for:)` unchanged;
      `signature(for:auxiliaryRand:)` **kept but retyped** — `auxiliaryRand:
      some ContiguousBytes`, caller's storage borrowed instead of the
      un-zeroed `var randomBytes` copy at `Schnorr+Signature.swift:131`
      (existing `[UInt8]` call sites compile unchanged; binary relink);
      `signature(message: some ContiguousBytes)` (exactly 32 bytes else
      throw); `signature(message: some ContiguousBytes, auxiliaryRand:
      some ContiguousBytes)` (aux exactly 32 bytes);
      `signature(customMessage:auxiliaryRand:…)` for
      upstream's arbitrary-length entry point. The Boolean flag, the raw
      pointer, and the un-zeroed copy all vanish; `nil` is unexpressible.
      The changelog migration section lists the one removed signature and
      the one retyped one ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift` · **breaking**
- [ ] T005 Verification mirrors the shape: the raw-bytes
      `isValid(_:for:)` takes non-mutating `ContiguousBytes` (the
      `inout [UInt8]` requirement is gone); the digest overload
      `isValidSignature(_:for:)` **keeps its `Digest` signature** — it is
      the `DigestValidator` protocol requirement (`Schnorr+Signature.swift:202`)
      — and changes only internally, dropping the inout array it builds ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift` · **breaking**
- [ ] T006 Extend the wave's verification retype to MuSig:
      the public multi-party verifier
      `P256K.MuSig.XonlyKey.isValid(_ signature:for message: inout [UInt8])`
      takes `some ContiguousBytes`, mirroring the Schnorr retype — without
      it, the solo and multi-party verify APIs diverge on the exact pattern
      this wave names a defect (mutability demanded for an unmutated buffer) ·
      `Sources/P256K/MuSig/MuSig+Signing.swift:268` · **breaking**
- [ ] T007 Update all internal call sites and existing tests to the new
      surfaces (Schnorr and MuSig); the official BIP-340 vectors (19 rows —
      signing rows driven with their declared `auxRand`, index 0 supplying
      the zero case) and the BIP-327 vectors must pass unchanged ·
      `Tests/P256KTests/` (Schnorr and MuSig suites),
      `Projects/Sources/` vector loaders as needed
- [ ] T008 New probes as permanent tests: 100-byte unhashed input throws
      through `signature(message:)`; `customMessage:` signs and verifies;
      zero-aux reproduces the all-zero-auxiliary vector (index 0) exactly ·
      `Tests/P256KTests/`

**Checkpoint:** no public Schnorr entry point accepts a raw pointer or a
Boolean mode flag; the entire pre-wave corpus of vectors still passes;
the 100-byte misuse now errors explicitly; `swift test` green. Diff budget:
largest slice of the wave — split tests into their own commit inside the PR
if the total nears ~400 authored lines.

## Group C — Verify-after-sign (PRs 3–6, one path per PR)

- [ ] T009 Schnorr: after `secp256k1_schnorrsig_sign_custom` succeeds,
      re-verify against the derived x-only key via
      `secp256k1_schnorrsig_verify`; failure → `P256K.invariantFailure`.
      DocC cites BIP-340 footnote 14 and upstream's "does not strictly
      follow BIP-340" doc note · `Sources/P256K/Schnorr/Schnorr+Signature.swift`
- [ ] T010 ECDSA: verify the parsed `secp256k1_ecdsa_signature` struct
      against the stored public key — no compact round-trip ·
      `Sources/P256K/ECDSA/ECDSA+Signature.swift`
- [ ] T011 Recovery: verify via `secp256k1_ecdsa_recover` +
      `secp256k1_ec_pubkey_cmp` against the derived public key (Bitcoin
      Core `SignCompact` technique) · `Sources/P256K/Recovery/Recovery+Signature.swift`
- [ ] T012 MuSig2 partial signatures: self-verify via the already-wrapped
      `secp256k1_musig_partial_sig_verify` against the signer's own public
      nonce and the session in use, with nonce provenance closed first:
      `SecureNonce` retains the companion public nonce from its
      `Nonce.generate` result (BIP-327's reference derives the public nonce
      *inside* `Sign()` from the secret-nonce scalars — carrying the
      companion is the Swift equivalent upstream's opaque-struct rule
      permits), and `partialSignature(...)` validates the caller-supplied
      `pubnonce` against that companion and throws
      `secp256k1Error.underlyingCryptoError` on mismatch **before any C
      call** — the "not consulted" parameter becomes consulted, never a
      crash on caller input. Verify failure → `invariantFailure`; DocC cites
      BIP-327 reference.py's assert · `Sources/P256K/MuSig/MuSig+Signing.swift`,
      `Sources/P256K/MuSig/MuSig+Nonces.swift`,
      `Sources/P256K/Schnorr/Schnorr+Nonces.swift` (the `SecureNonce`
      definition itself — its new companion-pubnonce stored property
      lands here) · **breaking** — the previously ignored `pubnonce`
      becomes validated and can throw
- [ ] T013 [P] Fault-injection tests per path. Seam, named: a package-internal
      (never `public`) corruption hook the signing methods consult between
      producing the signature bytes and self-verifying them — a
      `nonisolated(unsafe)` static closure stored `nil` in production and set
      only from `@testable` test code, guarded by the same
      `NSRecursiveLock` pattern `Invariant.swift` already uses for its
      handler state (Swift 6 strict concurrency rejects an unadorned
      mutable static). Assertions reuse the existing child-process exit-test
      pattern — `#expect(processExitsWith:)` observing a stderr marker, as
      `Tests/P256KTests/InvariantTests.swift` already does for the crash
      channel · new file under `Tests/P256KTests/`; one internal line per
      signing path in `Sources/P256K/`
- [ ] T014 Run `benchmark-pr.yml` workflows on T009–T012 and attach the
      comparisons to each PR description · workflow invocation only

**Checkpoint:** four paths self-prove before returning; corrupted outputs
never escape; benchmark deltas are measured and published on the PRs (the
"measure-first" promise kept).

## Group D — Rename sweep and initializer trim (PRs 7–8)

- [ ] T015 [P] Rename the three public `bytes` accessors to
      `dataRepresentation`, returning `Data`, with
      `@available(*, deprecated, renamed:)` aliases returning the old shape
      — one PR, all three types · `Sources/P256K/ECDSA/ECDSA+XonlyKey.swift:48`,
      `Sources/P256K/Schnorr/Schnorr+XonlyKey.swift:50`,
      `Sources/P256K/MuSig/MuSig.swift:243` · **breaking-soft** (aliases
      carry consumers until 1.0)
- [ ] T016 Trim every public site that hands callers the opaque
      `keyagg_cache` blob — `Schnorr.XonlyKey` and `MuSig.XonlyKey`
      `init(dataRepresentation:keyParity:cache:)` plus
      `MuSig.PublicKey.init(dataRepresentation:format:cache:)` (the only
      site where `cache` is required, not defaulted): public inits take
      key bytes (parity only via an explicitly labeled parameter where
      needed); the cache-taking inits and the public `cache` accessors
      on both x-only types move internal, while
      `MuSig.PublicKey.init(xonlyKey:)` stays public, reading the
      now-internal accessor in-module. Upstream ships no `keyagg_cache`
      serialization and calls the struct version-unstable, and the
      reference consumers (rust-secp256k1, btclib, Bitcoin Core's MuSig2
      wallet) obtain a cache only by re-aggregating. A reconstructed
      aggregate becomes verification-only; a consumer resuming a signing
      session re-runs `MuSig.aggregate(_:)` on the participant pubkeys.
      ECDSA's `Signing.XonlyKey` needs nothing — it has no cache ·
      `Sources/P256K/Schnorr/Schnorr+XonlyKey.swift`,
      `Sources/P256K/MuSig/MuSig.swift`,
      `Tests/P256KTests/MusigTests.swift` (the two `cache:` probes
      retarget the internal init) · **breaking**

**Checkpoint:** build passes with deprecation warnings on the old names;
a scratch consumer calling the three renamed `bytes` accessors compiles
(the removed signing, verify, and cache-initializer names intentionally
fail); the public signature surface names no upstream-internal type.

## Group E — Tag (release step, no code)

- [ ] T017 Roll `[Unreleased]` into `[0.25.0]`, cut the tag only after
      every breaking task merges (T004–T006, T012, T015–T016); in the
      same change bump the README example from
      `.upToNextMinor(from: "0.24.0")` to `.upToNextMinor(from: "0.25.0")`;
      publish the migration note as the release body ·
      `CHANGELOG.md`, `README.md`, git tag

**Checkpoint:** exactly one tag exists between the wave's pre-state and
post-state; every breaking symbol in the changelog names its replacement.

## Group F — Documentation recipes (PR 9)

- [ ] T018 [P] DocC article: fixed-32-byte signing flow (hash → sign via the
      32-byte method → verify), shown only against the post-redesign API ·
      `Sources/P256K/P256K.docc/`
- [ ] T019 DocC article: key agreement + key derivation — slice the
      compressed-point prefix byte for the bare 32-byte shared x, feed it
      unhashed to `HKDF<SHA256>` (CryptoKit/swift-crypto), salt guidance
      with the verified NIP-44 v2 shape as the worked example; states it is
      an example composition · `Sources/P256K/P256K.docc/`
- [ ] T020 Test that compiles the articles' exact code against the library ·
      `Tests/P256KTests/`

**Checkpoint:** articles build in the DocC catalog; their code is exercised
by tests; no protocol-named public API exists anywhere in the diff.

## Group G — CI assurance (PRs 10–11)

- [ ] T021 [P] Sanitizer lane: new jobs — `--sanitize=address` and
      `--sanitize=undefined`, each its own merge-blocking job on
      `ubuntu-latest` inside `container: swift:6.4.1` (the image the
      Dockerfile pins) with `options: --cap-add SYS_PTRACE` — required
      because LeakSanitizer attaches via `ptrace`, denied by default in
      containers and ungrantable to a `docker build` step
      (google/sanitizers#916). Each job repeats `--traits
      ecdh,musig,recovery,schnorrsig,uint256` for parity with the
      existing lane (`--traits` replaces the default trait set) and
      UBSan carries `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1`;
      `--sanitize=thread` advisory on `macos` runner with suppression file +
      `halt_on_error=1` and written promotion criteria (N clean weeks). Each
      sanitizer its own job and scratch path. Scope, stated honestly:
      SwiftPM propagates the flags to the vendored `libsecp256k1` C target,
      so the shipped C library is instrumented wherever the Swift suite
      calls into it; upstream's standalone test harness (`libsecp256k1Tests`,
      Tuist-only, macOS-only) runs only on the TSan lane, built via
      `xcodebuild -enableThreadSanitizer YES` and executed with
      `TSAN_OPTIONS=halt_on_error=1` at a low iteration count (e.g. 2) ·
      `.github/workflows/` (new or extended file), new suppressions file
- [ ] T022 [P] Generation-liveness leg: PR job that runs the documented
      Tuist generate command fresh and runs one vector scheme through
      `xcodebuild test` · `.github/workflows/`
- [ ] T023 [P] Contributor note: `Projects/AGENTS.md` states the generated
      project is git-ignored, can go stale locally, and gives the fix
      (delete + regenerate) · `Projects/AGENTS.md`

**Checkpoint:** the three merge-blocking jobs (ASan, UBSan, generation
liveness) green on the wave's final state; the advisory TSan report
visible in the job summary; all new jobs carry `permissions: {}`,
`env:` blocks, and no new third-party actions.

## Dependency map

T001–T003 (A) before everything. T004–T008 (B) before Group C (verify rides
the final API) and before T018–T020 (articles show the final API).
T009–T012 (C) may parallelize among themselves after B — T012 is breaking,
so it lands before T017 alongside the other breaking tasks. Group D any
time after B but before T017. Groups F and G parallel after their gates.
