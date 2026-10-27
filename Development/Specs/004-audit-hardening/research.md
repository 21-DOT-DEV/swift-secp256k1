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

### A.1 Follow-on audit findings (Target B only; IDs B-1 through B-6)

A second, single-target audit pass against this package reported six
findings; its A-1 belongs to the other codebase and stays out of this wave.

- **B-1 — `SharedSecret.description` prints the complete ECDH shared
  secret.** `Sources/P256K/DH.swift`'s `CustomStringConvertible`
  conformance interpolated `ss.hexString` — any `print`, interpolation,
  or log call disclosed the agreed key. Verified: the only
  `CustomStringConvertible` conformance on a secret-bearing type.
- **B-2 — `MuSig.aggregate` sorts keys internally, violating ordered
  BIP-327 aggregation.** `MuSig+Aggregate.swift` calls
  `secp256k1_ec_pubkey_sort` before `secp256k1_musig_pubkey_agg`, so caller
  key order has no effect and the official `key_agg_vectors.json` cannot
  distinguish the wrapper from a conforming implementation.
- **B-3 — MuSig message parameters silently pad or truncate to 32 bytes.**
  `Digest.msg32Bytes` (`Utility.swift:203`) performs SEC1 §4.1.3 reduction —
  left-pad for short inputs, leftmost-32 for long — and every MuSig message
  path routes through it (`Nonce.generate` `msg32:`,
  `partialSignature(for digest:)`, `isValidSignature(_:for digest:)`).
  libsecp256k1's MuSig API takes a fixed `msg32` — BIP-327 itself permits
  variable-length messages as an optional feature — so a 38-byte message
  silently signs its first 32 bytes.
- **B-4 — `MuSig.PublicKey.isValidSignature(_:publicKey:nonce:for digest:)`
  ignores `digest`.** The doc comment states it verbatim: "not consulted —
  the signed message is bound inside `PartialSignature/session`".
- **B-5 — `Signature.Recoverable.normalize` only converts format, no
  low-S normalization.** It calls
  `secp256k1_ecdsa_recoverable_signature_convert`; the property's own doc
  warns the output "may fail `secp256k1_ecdsa_verify`" for low-S.
- **B-6 — `Context.create()` returns an unmanaged `OpaquePointer`.**
  `Context.swift:129` performs create + callbacks + randomize correctly,
  but the returned pointer has no owner; nothing pairs it with
  `secp256k1_context_destroy`.

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
- **BIP-327 key aggregation preserves caller order**
  (`bips/bip-0327.mediawiki`, `key_agg_vectors.json`): the spec's `KeyAgg`
  aggregates keys in the order supplied; sorting is an application-layer
  choice (BIP-390 `musig()` descriptors sort at the descriptor layer).
  Upstream agrees at every level — `examples/musig.c` sorts only when the
  application wants canonical order, `doc/musig.md` describes sorting as
  optional and caller-controlled, `secp256k1_ec_pubkey_sort` exists as a
  separate helper, and `secp256k1_ec_pubkey_cmp` orders the compressed
  33-byte serialization. Bindings mirror it: rust-secp256k1's
  `KeyAggCache::new` keeps supplied order with `sort_pubkeys` as a
  separate free function; rust `musig2` preserves iterator order and
  recommends deterministic pre-sorting; Bitcoin Core's MuSig code
  aggregates keys "in their current order".
- **Context lifecycle contract** (`include/secp256k1.h` and
  `include/secp256k1_preallocated.h`): contexts are deliberately
  long-lived — "Do not create a new context object for each operation,
  as construction and randomization can take non-negligible time"
  (`include/secp256k1.h:292-293`, verbatim from the vendored tree); the
  context itself is a few hundred bytes (`src/secp256k1.c:61-66`: an
  ecmult-generator blinding state, two callbacks, a flag — the
  precomputed tables are static data); randomize "either once at creation time (then you need
  no locking for the other calls), or use a read-write lock";
  `secp256k1_context_destroy` and `secp256k1_context_randomize` require
  exclusive access while const-pointer calls are thread-safe;
  `secp256k1_context_static` cannot perform secret-key operations.
  rust-secp256k1 implements the managed shape: `Secp256k1` owns the
  pointer, `Drop` calls destroy, `Send`/`Sync` are hand-justified on the
  native API's const-thread-safety and exclusive-mutation model,
  `randomize` requires `&mut self`, and `ctx()` is the explicitly-named
  raw escape hatch. In the Swift ecosystem, swift-nio-ssl wraps its
  expensive `SSL_CTX *` in the thread-safe `final class NIOSSLContext`,
  and swift-crypto owns BoringSSL resources with `final class`
  `BackingStorage` + `deinit` behind value-type facades
  (`ArbitraryPrecisionInteger`).
- **Secret redaction convention**: Rust's `secrecy` crate redacts `Debug`
  and exposes bytes only through explicit `expose_secret` accessors;
  rust-secp256k1's issue #226 records the same discussion for secret
  debug output (resolved by PR #311/#312 — `SecretKey`'s `Debug` prints a
  hash fingerprint — and PR #396, which obfuscated `SharedSecret`'s
  print for this same type). On the Apple side the convention is
  inverted from the early assumption: CryptoKit's `SharedSecret` *does*
  print the full hex today (verified live), and upstream swift-crypto
  `main` still ships the identical `"\(Self.self): \(ss.hexString)"`
  line this file inherited — the in-family redaction precedent is
  `CryptoKit.SymmetricKey` ("Key representation contains 32 bytes."),
  whose byte-count phrasing the fix adopts. The vendored
  `Digest.description` prints full hex because digests are public
  outputs, not secrets.
- **BIP-327 message length**: the spec defines the message as "a byte
  array" and lists "messages that are not exactly 32 bytes" as an
  optional feature; its 0.6.0 changelog reads "Allow variable length
  messages … and add test vectors", and `sign_verify_vectors.json`
  carries 32-byte, empty, and 38-byte messages. The fixed `msg32` is
  libsecp256k1's implementation limit (`include/secp256k1_musig.h` —
  `nonce_gen`, `nonce_gen_counter`, `nonce_process`; `partial_sign`
  takes no message — the session binds `msg32` at `nonce_process`),
  which remains conforming to the spec's optional feature. The repo's
  copy under `Projects/Resources/MuSig2VectorTests/` keeps the full
  `msgs` table but only the `msg_index`-0 `valid_test_cases`, with all
  error sections emptied — T030 restores the full file and drives every
  expressible case on the stated-skip pattern `NonceGenVectorTests`
  already runs (`skipReason(for:index:)` + verified/skipped counts,
  `NonceGenVectorTests.swift:39-73`; upstream's own C suite skips the
  same variable-length cases).
- **The aggregate signature is a plain BIP-340 signature**: BIP-327
  states the final signature "passes BIP340 verification for the
  aggregate public key and a message"; `secp256k1_schnorrsig_verify`
  takes `(msg, msglen)` at any length. A variable-length-capable
  implementation (e.g. BIP-327's reference Python) can legitimately
  produce an aggregate signature over a 38-byte message.
- **Verifier error-shape conventions**: every upstream verify function
  returns 0/1 (`schnorrsig_verify` among them); every CryptoKit
  `isValidSignature` returns `Bool` and never throws; btcd's public
  `schnorr.Verify` collapses its internal `ErrInvalidHashLen` to
  `false`. The in-package precedent already exists:
  `Schnorr.XonlyKey.isValidSignature(_:for:)` documents that the digest
  is "verified … at their natural length … there is no msg32 reduction
  here" (`Schnorr+Signature.swift:205-207`). Signing differs: the
  message binds at `nonce_process`'s fixed `msg32` (`partial_sign`
  takes no message), so upstream cannot produce a signature over a
  non-32-byte input at all — signing throws while verification
  checks at natural length — an asymmetry that is principled, not a
  half-gate (a >32-byte digest can never match a 32-byte-produced
  signature, so verify fails closed with nothing shortened).

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
- "No correctness defect exists in the shipped paths" — **wrong as a
  blanket claim**: it was true of the first audit, but the follow-on pass
  found three BIP-327 conformance defects in MuSig (B-2 unordered
  aggregation, B-3 silent message reduction, B-4 unconsulted verifier
  parameter), one secret-disclosure defect (B-1), one misleading name
  (B-5), and one unmanaged-resource defect (B-6). Closed into plan §3.8,
  §3.9, §3.10 and T025–T029.
- "MuSig's `msg32` reduction is standard digest behavior" — **wrong for
  MuSig, right for ECDSA**: SEC1 §4.1.3 digest-to-integer reduction is
  spec-correct for ECDSA `signature(for:)` (Go/OpenSSL/CryptoKit), but
  MuSig binds the message into the signing session — the signing-side
  rule is require-32-or-throw because upstream takes a fixed `msg32`
  (BIP-327 itself permits variable length), and the verify-side rule is
  natural-length checking with no gate at all. Closed into plan §3.9
  and T027.
- "BIP-327's `msg32` is a fixed 32-byte message parameter" — **wrong**:
  BIP-327 defines the message as "a byte array" and permits variable
  length as an optional feature (vectors include 32-byte, empty, and
  38-byte cases); the fixed `msg32` is libsecp256k1's implementation
  limit. The spec's error wording says "unsupported by libsecp256k1",
  not "invalid".
- "The digest verifier should throw on non-32-byte input" — **wrong**:
  the finished aggregate signature is a plain BIP-340 signature
  verifiable at any message length via `secp256k1_schnorrsig_verify`;
  throwing or returning `false` on the input would reject a signature
  a conforming implementation could produce. `isValidSignature(_:for:)`
  stays `-> Bool` and checks at natural length, matching its Schnorr
  sibling and every upstream/CryptoKit convention. Closed into plan
  §3.9 and T027.
- "Comparable or a `sorted:` flag is the right B-2 API" — **wrong**:
  canonical key order is a multisig convention better named where it's
  meaningful than promised type-wide — upstream ships ordering as
  functions (`ec_pubkey_cmp`, `ec_pubkey_sort`) rather than as a
  property of the key, rust-secp256k1 documents `sort_pubkeys` rather
  than its `Ord` impl as the canonical way to sort for MuSig2, and no
  CryptoKit key type carries `Comparable`. The helper itself imposes no
  format rule: `ec_pubkey_sort` orders the *parsed point* via its
  compressed serialization, so `.compressed` and `.uncompressed` inputs
  sort identically and keep their own stored format on return. A flag
  would revive the implicit behavior the finding objects to. Closed
  into plan
  §3.9 and T026.
- "`Schnorr.PublicKey` is x-only" — **wrong** (an earlier draft of the
  B-2 rationale claimed it): it is a full curve point in compressed or
  uncompressed form; `XonlyKey` is the x-only type. The corrected
  Comparable rationale above stands on the format-variance argument.
- "CryptoKit's `SharedSecret` redacts its `description`" — **wrong**:
  verified live that CryptoKit prints the secret's full hex, and
  upstream swift-crypto `main` still ships the identical
  `"\(Self.self): \(ss.hexString)"` line — the leak is inherited from
  Apple, not introduced by this wrapper. The actual in-family precedent
  is `CryptoKit.SymmetricKey` — "Key representation contains 32 bytes."
  — the byte-count phrasing the new `description` adopts (the earlier
  `<32 bytes>` example was also wrong on the count: the stored value is
  a 33- or 65-byte serialized point). Closed into plan §3.8 and T025.
