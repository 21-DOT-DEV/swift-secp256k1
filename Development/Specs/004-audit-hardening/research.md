# Research — 004 · Audit-hardening wave

What the audit measured, what the follow-on best-practice research established,
and the citations an implementing agent can re-check. No review history lives
here — where an earlier working assumption was falsified by primary sources,
this file states the final position only.

## A. Audit evidence (2026-10-22, two-target comparison)

Target B is this package (`P256K` Swift wrapper over vendored libsecp256k1
v0.7.1); Target A is an unrelated narrow Nostr SDK vendoring the upstream
v0.8.0 tree. Method: static review, byte-diff of both vendored trees against
upstream at their claimed commits, full test-suite execution on both, all 19
official BIP-340 vectors executed against both public surfaces, two real
published Nostr events (from rust-nostr's test fixtures) validated end-to-end
through each, boundary probes, and task-based usability probes.

- **No correctness defect found in either target's shipped paths.** Target B
  passed its full suite (80 swift-testing tests + 11 XCTest), its vector and
  security schemes (BIP-340, BIP-327 MuSig2, Wycheproof ECDH/ECDSA, internal
  security regression suites), and upstream's own C test suite at 16
  iterations, exit 0.
- **Vendored trees are byte-identical to their claimed upstream commits,**
  modulo each target's declared filters; Target B's pin is lock-file- and
  CI-gate-enforced (`vendir.yml`, `Scripts/vendir-check.sh`).
- **Measured misuse gap (the wave's core):** feeding a raw, unhashed 100-byte
  input to `signature(message:auxiliaryRand:strict: false)` produced a
  signature that verifies — no error, no warning. The same-layer verify took
  a message only as `inout [UInt8]`.
- **Deterministic-by-accident:** `auxiliaryRand` is a required raw-pointer
  parameter whose `nil` silently selects upstream's all-zero auxiliary data —
  fully deterministic nonces, discarding the fault-injection protection the
  library's default digest overloads provide.
- **Naming drift:** three public accessors named `bytes` returning `[UInt8]`
  versus eleven public `var dataRepresentation: Data` declarations (count
  reproducible via `grep -rh 'public var dataRepresentation' Sources/P256K --include='*.swift' | wc -l`;
  twenty files reference the name overall).
- **Leaky initializers:** `Schnorr.XonlyKey.init(dataRepresentation:keyParity:cache:)`
  exposes an upstream magic-checked MuSig cache blob publicly; the same
  cache-taking form exists on `MuSig.XonlyKey`, where it additionally
  serializes a struct upstream gives no serialization functions.
- **CI reality observed live:** the git-ignored generated Xcode workspace can
  go stale locally and fail cryptically (`P256K has no member
  'invariantFailure'`) until regenerated.

## B. Upstream and specification citations

- **BIP-340, "Default Signing" + footnote 14** (`bips/bip-0340.mediawiki`,
  current master): the signing algorithm *ends* with "If Verify(...) returns
  failure, abort"; footnote 14: "Verifying the signature before leaving the
  signer prevents random or attacker provoked computation errors... It is
  recommended, but can be omitted if the computation cost is prohibitive."
- **libsecp256k1 delegates the step to callers**: its schnorr-sign doc
  comment states the function "does not strictly follow BIP-340 because it
  does not verify the resulting signature. Instead, you can manually use
  secp256k1_schnorrsig_verify and abort if it fails."
- **Bitcoin Core PR #22934** (merged): added verify-after-sign to `Sign`,
  `SignCompact`, and `SignSchnorr`; an opt-out flag was proposed and dropped.
  The recoverable-signature path proves via `secp256k1_ecdsa_recover` +
  `secp256k1_ec_pubkey_cmp`.
- **BIP-327 reference** (`bips/bip-0327/reference.py`): `sign()` ends with
  `assert partial_sig_verify_internal(...)` — "Optional correctness check.
  The result of signing should pass signature verification."
- **Ledger Bitcoin app**: verifies produced Schnorr signatures before
  returning them (defense-in-depth, commit 39cc6bb2).
- **BIP-340, "Messages of Arbitrary Size"**: arbitrary-length messages are
  spec-legal *today*; the fixed-32-byte discipline is a protocol requirement
  (Nostr event ids, Taproot sighashes), not a BIP-340 one — hence a distinct
  `customMessage:` name rather than an error for all non-32-byte inputs.
- **Auxiliary randomness semantics** (`include/secp256k1_schnorrsig.h`):
  a NULL auxiliary pointer is treated as an all-zero one; BIP-340 notes
  zero-aux is compliant but gives up fault-injection hedging.
- **NIP-44 v2** (`nips/44.md`, current): conversation key =
  HKDF-extract(sha256, IKM = shared_x — the **unhashed** 32-byte x
  coordinate, salt = UTF-8("nip44-v2")). Because this library's key agreement
  returns the *serialized compressed point* (prefix byte + x), the docs
  recipe must slice the prefix byte.
- **v0.8.0 changelog** (upstream, 2026-08-03): its removed symbols
  (`secp256k1_context_no_precomp`, deprecated `secp256k1_schnorrsig_sign`)
  have zero call sites in the package's own wrapper or test code — the only
  hits are declarations inside the vendored `Sources/libsecp256k1/` tree
  (`include/secp256k1.h:248`, `include/secp256k1_schnorrsig.h:129`), live
  call sites in the vendored upstream test bundle
  (`Projects/Sources/libsecp256k1Tests/src/tests.c:192` and
  `src/modules/schnorrsig/tests_impl.h:824` — the calls that check the very
  deprecated aliases being removed, so upstream's own removal deletes them
  and the lockstep bump carries the deletion), plus a doc mention in
  `P256K.docc/MigratingToP256K.md:184`; adds Silent Payments
  module and an SHA-256-compression override hook; changes `ellswift_xdh`
  secret-key validation. Low-risk bump — but deferred by decision, not risk.
- **keyagg_cache carries no blessed serialization**
  (`include/secp256k1_musig.h`): the 197-byte opaque struct has "No
  serialization and parsing functions (yet)" and is "not guaranteed to be
  portable between different platforms or versions". Downstream bindings
  enforce the same shape — `rust-secp256k1`'s `musig::KeyAggCache` keeps
  private fields behind a single re-aggregation constructor,
  `btclib-secp256k1` wraps it as a declined no-serialization opaque
  handle, and Bitcoin Core's merged MuSig2 wallet (PR #29675) keeps all
  signing session state in memory and restarts signing on reload.
  Resuming a session means re-aggregating the participant pubkeys, which
  `secp256k1_musig_pubkey_agg` makes deterministic.

## C. Versioning evidence

- **Remote tags**: 0.24.0 = `bcd6dd8e` exists; no 0.25.0. `CHANGELOG.md`
  already carries breaking `[Unreleased]` entries (`bytes → byteArray`,
  throwing `HashDigest.init`, hardened zeroization and MuSig binding) ahead
  of `[0.24.0] — 2026-10-19`.
- **SwiftPM semantics**: `from: "0.x.y"` is `.upToNextMajor` with no 0.x
  special case — resolves forward through every 0.x minor below 1.0.0.
- **Apple precedent**: apple/swift-configuration's pre-1.0 README advised
  exactly `.upToNextMinor(from:)` with the sentence "Before we reach 1.0,
  API-breaking changes may occur between minor `0.x` versions." — the
  template for the pin-advice change.
- **Constitution status**: `Development/constitution.md` already permits
  immediate pre-1.0 breaks; its "Users advised to pin exact versions" advice
  in the Versioning & Stability table is the line amended by this wave.

## D. Swift/CI practice evidence

- **Sanitizer invocation standard**: `swift test --sanitize=address |
  thread | undefined` is the documented practice (swift-server/guides/docs);
  flags propagate to C targets, so the leg exercises the vendored C too.
  The existing Linux lane is `docker build .` — its `RUN` step cannot be
  granted `SYS_PTRACE`, and LeakSanitizer (bundled inside ASan on Linux)
  attaches via `ptrace`; google/sanitizers#916 and oss-fuzz#9 document
  the fatal failure and the fix, `--cap-add SYS_PTRACE` on
  `docker create`/`run`, which GitHub Actions accepts natively through
  `container.options` (documented as `docker create` flags) — so the
  lanes run as `container: swift:6.4.1` jobs (the image the Dockerfile
  pins), not `docker build` extensions. Each repeats the lane's
  `--traits ecdh,musig,recovery,schnorrsig,uint256` — `--traits`
  replaces the default trait set, so a flagless sanitized run would
  drop the `uint256` sources and tests — and carries
  `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1` (CPython's
  reusable-san.yml pattern) so reports fail the job. Known
  SPM-on-Linux linker rough edges exist for ASan under some build
  configurations (swiftlang/swift-package-manager#8869 — a SwiftPM
  self-build failure, not a consumer-package blocker).
- **TSan platform asymmetry** (Swift Forums, "ThreadSanitizer in a Swift
  Concurrency World", 2026-02): reliable on macOS for current toolchains
  (Jon Shier: "I run it with my test suites"); ~50% false-positive rate
  reported on Linux around Swift concurrency (Tim Condon). SR-15444's
  async-test false positives were Linux-only. Hence: TSan on macOS,
  advisory; ASan/UBSan on Linux, blocking.
- **TSan operational reality**: data races fire ~1-in-15 sanitized runs
  (documented audit of a Swift app, CodexBar issue #2200), TSan warnings
  exit 66 without failing XCTest assertions, and sentry-cocoa PR #5216
  shows the failure mode of blocking CI on an unstabilized TSan lane
  (temporarily disabled to unblock releases). Mitigations adopted:
  advisory-at-introduction, suppression file + `halt_on_error=1` (Bitcoin
  Core's documented sanitizer CI pattern), promotion criteria stated in the
  workflow.
- **Generated-file gates**: the industry "regenerate + `git diff
  --exit-code`" drift check applies to *committed* generated output. This
  repo's generated Xcode project is deliberately git-ignored
  (`Projects/.gitignore:62–63`), so the correct gate is liveness —
  regenerate fresh and run a test scheme — not diffing.
- **swift-crypto scope doctrine** (apple/swift-crypto#9): application
  protocols and low-level primitives for composition are explicitly out of
  scope; the library ships safe high-level constructions only. This wave's
  docs-only protocol recipes follow that line. CryptoKit's `SharedSecret`
  ships `hkdfDerivedSymmetricKey`/`x963DerivedSymmetricKey`; this package's
  `SharedSecret` does not have them, and adding them in-code is assigned to
  Phase 5 (`Development/Roadmap/phase-5-sha2-tower.md` already plans exposing
  the C `secp256k1_hmac_sha256` core plus HKDF), not this wave.
- **Dependency-witness precedent for `strict:`-style Boolean flags:** Swift
  API Design Guidelines discourage Boolean mode parameters; the redesign
  replaces the flag with distinctly-named methods.

## E. Falsified working assumptions (closed, not open)

- "The BIP-340 verify-after-sign footnote is 16" — **wrong**; it is 14
  (16 is the pre-hashing footnote). Verified on the rendered master text.
- "`signature(for:auxiliaryRand:)` takes a defaulted `auxiliaryRand`" —
  **wrong**; the parameter is required. The redesign's "drop `nil`"
  covers the real footgun. Closed into plan §3.1.
- "The recipe hashes the shared x-coordinate before HKDF" — **wrong**;
  NIP-44 feeds it unhashed. Closed into plan §3.6.
- "Sanitized `swift test` runs also execute the vendored upstream C test
  binary" — **wrong** as scoped: upstream's test harness (`tests.c`) is a
  Tuist-only macOS command-line target with no SwiftPM or Linux path. The
  true two-part claim (SwiftPM's flag propagation instruments the vendored C
  *library* in every sanitized lane; upstream's *harness* runs only on the
  macOS lane via the WWDC-412-documented
  `-enableThreadSanitizer YES` + `TSAN_OPTIONS=halt_on_error=1` flow) is
  closed into plan §3.5 and T021.
- "The redesign drops `signature(for:auxiliaryRand:)`" — **wrong**; the
  method is kept, retyped to `some ContiguousBytes` (its `[UInt8]`
  conforming callers compile unchanged; the un-zeroed copy inside it
  disappears). Closed into plan §3.1 and T004.
- "T005 retypes the digest verification overload" — **wrong**;
  `isValidSignature(_:for:)` is the `DigestValidator` protocol requirement
  and keeps its `Digest` signature. Closed into plan §3.1 and T005.
- "The public cache-blob surface is two x-only initializers" — **wrong**;
  `MuSig.PublicKey.init(dataRepresentation:format:cache:)` takes the same
  blob with `cache` *required* (no default), making five public sites —
  three initializers plus a `cache` accessor on each x-only type. Closed
  into plan §3.4 and T016.
