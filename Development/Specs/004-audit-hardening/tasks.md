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

- [ ] T001 [P] Consumer pin advice in both documents the wave names —
      README: replace the `exact: "0.24.0"` dependency example
      (`README.md:39`) with `.upToNextMinor(from: "0.24.0")` plus one
      sentence explaining that SwiftPM's `from:` spans every 0.x below 1.0.0
      and why the minor is the stability boundary pre-1.0, and one sentence
      stating the example moves to `0.25.0` when that tag is cut (the
      tag-time bump lives in the release task T017 — never name an
      untagged version in a published example); constitution: in the
      Versioning & Stability section of `Development/constitution.md`,
      replace "Users advised to pin exact versions" with the same
      `.upToNextMinor(from:)` advice and a one-line rationale pointing at
      the Apple swift-configuration pre-1.0 wording; bump the document's
      version/changelog block — the plan names these two files the wave's
      first change-set, so the advice cannot land half-updated ·
      `README.md`, `Development/constitution.md`
- [ ] T002 _Folded into T001 — the plan calls the README and constitution
      edits "the wave's first change-set": one advice change across two
      consumer-facing documents, not two commits that briefly disagree.
      Tick this box in T001's commit._ · `Development/constitution.md`
- [ ] T003 [P] Migration-note skeleton: CHANGELOG `[Unreleased]` gains the
      wave's section header and the standing instruction reproduced verbatim
      ("each breaking change lands with its replacement named here; tag cut
      after the last breaking change, never between") · `CHANGELOG.md`

**Checkpoint:** a consumer reading README today learns the correct
pre-1.0 constraint; the constitution's advice no longer contradicts the
wave; `swift run --package-path Development/Tools plans --check` and
`vale Development/` pass.

## Group B — Secret-output redaction (PR 2)

- [ ] T025 [P] `SharedSecret.description` never prints secret bytes —
      `Sources/P256K/DH.swift:126–128` interpolates the complete ECDH
      shared secret as hex (`"\(Self.self): \(ss.hexString)"`), so any
      `print`, `String(describing:)`, interpolation, or log call on a
      `SharedSecret` discloses the agreed key (audit finding B-1; the
      `secrecy`/rust-secp256k1 convention: secret-bearing types redact,
      byte exposure stays explicit through an opt-in accessor). The
      conformance prints a type-and-length form (`"SharedSecret: <32
      bytes>"`) — never the bytes — and a new redaction-contract test
      asserts `String(describing:)`, `String(reflecting:)`, and `\(…)`
      interpolation on every *copyable* secret-bearing type
      (`SharedSecret`, the `Signing`/`KeyAgreement`/`Schnorr`/`Recovery`
      private keys) contains none of the value's secret bytes — the
      other types pass today (their material sits behind `SecureBytes`'
      class-backed storage, which `String(describing:)` renders as a
      type name), and the `~Copyable` types (`SecureNonce`,
      `SessionSecretRand`) are deliberately uncovered: the type system
      rejects them as arguments to `String(describing:)`,
      `String(reflecting:)`, and interpolation, so the leak is impossible
      at compile time rather than merely absent at runtime. The contract
      exists so a future raw-byte stored property can't silently
      reopen the leak · `Sources/P256K/DH.swift`,
      `Tests/P256KTests/` (new redaction-contract file)

**Checkpoint:** no `print`/interpolation/logging path emits secret bytes
for any secret-bearing type; `swift test` green.

## Group C — Schnorr signing/verification redesign (PR 3, the wave's largest)

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
      the one retyped one; the same commit migrates every call site and
      test naming the removed methods — the BIP-340 signing rows run
      through the new surface with their declared `auxRand` (index 0
      supplying the zero case), so no intermediate commit fails to
      compile (carries T007's Schnorr-signing share) ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift`,
      `Tests/P256KTests/` (Schnorr signing) · **breaking**
- [ ] T005 Verification mirrors the shape: the raw-bytes
      `isValid(_:for:)` takes non-mutating `ContiguousBytes` (the
      `inout [UInt8]` requirement is gone); the digest overload
      `isValidSignature(_:for:)` **keeps its `Digest` signature** — it is
      the `DigestValidator` protocol requirement (`Schnorr+Signature.swift:202`)
      — and changes only internally, dropping the inout array it builds;
      the same commit migrates the verify call sites — the BIP-340
      verification rows pass unchanged through the retyped method
      (carries T007's Schnorr-verify share) ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift`,
      `Tests/P256KTests/` (Schnorr verification) · **breaking**
- [ ] T006 Extend the wave's verification retype to MuSig:
      the public multi-party verifier
      `P256K.MuSig.XonlyKey.isValid(_ signature:for message: inout [UInt8])`
      takes `some ContiguousBytes`, mirroring the Schnorr retype — without
      it, the solo and multi-party verify APIs diverge on the exact pattern
      this wave names a defect (mutability demanded for an unmutated buffer);
      the same commit migrates the MuSig call sites — the BIP-327 vector
      drivers pass unchanged through the retyped verifier (carries T007's
      MuSig share) · `Sources/P256K/MuSig/MuSig+Signing.swift:268`,
      `Tests/P256KTests/` (MuSig), `Projects/Sources/` vector loaders as
      needed · **breaking**
- [ ] T007 _Folded into T004–T006 — a commit that deletes a method without
      updating its callers fails to compile, so each breaking task lands
      its own call-site and test updates (the BIP-340 signing rows ride
      T004, the verification rows T005, the BIP-327 drivers T006). Tick
      this box across T004–T006's commits._ · `Tests/P256KTests/`,
      `Projects/Sources/`
- [ ] T008 New probes as permanent tests: 100-byte unhashed input throws
      through `signature(message:)`; `customMessage:` signs and verifies;
      zero-aux reproduces the all-zero-auxiliary vector (index 0) exactly ·
      `Tests/P256KTests/`

**Checkpoint:** no public Schnorr entry point accepts a raw pointer or a
Boolean mode flag; the entire pre-wave corpus of vectors still passes;
the 100-byte misuse now errors explicitly; `swift test` green. Diff budget:
largest slice of the wave — split tests into their own commit inside the PR
if the total nears ~400 authored lines.

## Group D — MuSig BIP-327 conformance (PRs 4–7)

- [ ] T026 `MuSig.aggregate(_:)` preserves caller key order, and key
      sorting becomes an explicit opt-in helper — today the method runs
      `secp256k1_ec_pubkey_sort` inside aggregation
      (`MuSig+Aggregate.swift`), so two different signer orders silently
      produce the same aggregate key and the official BIP-327 vectors
      cannot distinguish the wrapper from a conforming implementation
      (audit finding B-2). Upstream's `secp256k1_musig_pubkey_agg`
      preserves caller order, `examples/musig.c` sorts only when the
      application wants canonical order, rust-secp256k1's
      `KeyAggCache::new` keeps the supplied order with `sort_pubkeys`
      as a separate helper, and Bitcoin Core aggregates keys in their
      current order — the primitive preserves order; sorting is an
      application choice. The sort call leaves `aggregate(_:)`; a new
      `P256K.MuSig.sortedPublicKeys(_:) -> [P256K.Schnorr.PublicKey]`
      wraps `secp256k1_ec_pubkey_sort` and documents BIP-327's
      canonical key-sort — lexicographic on the compressed
      serialization of each *parsed point*: upstream's comparator
      canonicalizes internally, so keys sort identically whether they
      arrived `.compressed` or `.uncompressed`, each returned key keeps
      its own stored format, and the helper needs no `throws` (infallible
      on parse-validated keys) — making the migration note's "exact
      pre-wave behavior" claim literally true for every caller. No
      `Comparable` on `Schnorr.PublicKey`: canonical order is a multisig
      convention better named where it's meaningful — no CryptoKit key
      type carries `Comparable`, upstream ships ordering as functions
      (`ec_pubkey_cmp`, `ec_pubkey_sort`), and rust-secp256k1 documents
      `sort_pubkeys` rather than its `Ord` impl as the way to sort for
      MuSig2; no `sorted:` flag revives the implicit behavior. Tests
      drive `key_agg_vectors.json` *expected-value* comparisons through
      the ordered API — the current `KeyAggVectorTests.swift` driver
      only asserts repeatability and 32-byte length, so it gains real
      expected-aggregate assertions — the existing order-independence
      assertion inverts (different orders now produce different
      aggregates), `aggregate(sortedPublicKeys(_:))` is asserted to
      reproduce the canonical output, and a mixed-format probe sorts
      compressed- and uncompressed-form keys of the same points
      identically ·
      `Sources/P256K/MuSig/MuSig+Aggregate.swift`,
      `Tests/P256KTests/` (MuSig),
      `Projects/Sources/MuSig2VectorTests/` (expected values +
      the inverted assertion) · **breaking** — unordered call sites
      see their aggregate key change; the changelog names
      `sortedPublicKeys(_:)` as the migration
- [ ] T027 MuSig signing-path message inputs require exactly 32 bytes —
      libsecp256k1's MuSig API takes a fixed `msg32` at `nonce_gen`,
      `nonce_gen_counter`, and `nonce_process` (`partial_sign` takes no
      message — the session binds it at `nonce_process`, which is where
      `partialSignature`'s digest lands), while BIP-327 itself permits
      variable-length messages as an optional feature (the official
      `sign_verify_vectors.json` carries 32-byte, empty, and 38-byte
      messages) — but every signing path runs the input through
      `Digest.msg32Bytes` (`Utility.swift:203`), the SEC1 §4.1.3
      reduction that left-pads short inputs and truncates long ones — a
      38-byte message silently signs its first 32 bytes (audit finding
      B-3). Both `Nonce.generate` overloads (`msg32:`) and
      `partialSignature(for digest:…)` gate at exactly 32 bytes or
      `secp256k1Error.incorrectParameterSize` — upstream cannot sign
      any other length, and reducing would silently commit to the wrong
      message; the error and the DocC comments say "unsupported by
      libsecp256k1", not "invalid". The aggregate digest verifier
      `MuSig.XonlyKey.isValidSignature(_:for digest:)` gets the opposite
      fix: it stays `-> Bool`, drops `msg32Bytes`, and verifies the
      digest at natural length through `secp256k1_schnorrsig_verify`'s
      arbitrary-length `(msg, msglen)` — matching its sibling
      `Schnorr.XonlyKey.isValidSignature(_:for:)` (which already verifies
      "at natural length… no msg32 reduction",
      `Schnorr+Signature.swift:205-207`), its own arbitrary-length
      `isValid(_:for:)`, and every upstream/CryptoKit/btcd convention
      (verify returns 0/1 or `Bool`, never throws — a wrong-length
      input fails closed rather than reducing). `msg32Bytes` itself is
      untouched: ECDSA's `signature(for:)` reduction is spec-correct
      SEC1 behavior. Regression probes: a 38-byte message throws on the
      signing inputs instead of behaving as its first 32 bytes — the
      repo's `sign_verify_vectors.json` already carries the empty and
      38-byte payloads at `msgs[1]`/`msgs[2]` (every `valid_test_cases`
      row uses `msg_index` 0 and the error sections are empty, so the
      driver probes those indices directly — no vector-file change in
      this task; T030 restores the full file and drives all its
      sections); and the
      positive natural-length probe is self-contained — a signature
      produced over a >32-byte `customMessage:` by the package's own
      Schnorr path verifies true through `isValidSignature(_:for:)`,
      where a reducing verifier would fail it ·
      `Sources/P256K/MuSig/MuSig+Nonces.swift`,
      `Sources/P256K/MuSig/MuSig+Signing.swift`, `Tests/P256KTests/`,
      `Projects/Sources/MuSig2VectorTests/` · **breaking** — non-32-byte
      signing inputs that silently reduced now throw; the digest
      verifier's semantics change for non-32-byte input (it checks the
      actual digest, not its truncation — the changelog names both)
- [ ] T028 The partial-signature verifier drops its unconsulted
      `for digest:` — `MuSig.PublicKey.isValidSignature(_:publicKey:
      nonce:for digest:)` documents the parameter as "not consulted"
      because the signed message is bound inside the session at
      `secp256k1_musig_nonce_process` time (audit finding B-4). The
      parameter — and the method's `D: Digest` generic — leaves the
      signature; call sites passing `for:` fail to compile with the
      fix-it obvious (delete the argument), and the changelog names the
      removal · `Sources/P256K/MuSig/MuSig+Signing.swift`,
      `Tests/P256KTests/` · **breaking**

- [ ] T030 Restore the full upstream `sign_verify_vectors.json` and drive
      every expressible case — the repo's copy under
      `Projects/Resources/MuSig2VectorTests/` was trimmed to three
      `msg_index`-0 `valid_test_cases` with all three error/fail sections
      emptied, so it silently shadows upstream case additions and
      exercises no error path at all. Restore the official file (six
      valid, six `sign_error`, three `verify_fail`, two `verify_error`
      cases) and rewrite `SignVerifyVectorTests` — which today only
      load-checks counts and parses nonces, never executing a case — on
      the stated-skip pattern `NonceGenVectorTests` already runs
      (`skipReason(for:index:)` returning a human-readable reason plus
      verified/skipped count assertions,
      `NonceGenVectorTests.swift:39-73`). The four `msg_index`-0 valid
      cases drive the real `partialSignature` → partial-verify path —
      the vector's 97-byte spec secnonce materializes into the internal
      132-byte `secp256k1_musig_secnonce` layout that
      `NonceGenVectorTests.swift:101-120` already documents, via
      `@testable` internals; the empty and 38-byte cases stated-skip
      with the `NonceGenVectorTests`-style reason "not representable in
      `msg32` — unsupported by libsecp256k1" (upstream's own C suite
      skips them the same way). `sign_error`/`verify_fail`/
      `verify_error` rows assert throw/`false` where the wrapper's
      types can express the fault and stated-skip where they can't —
      the skip table names each condition and why it is inexpressible
      (e.g. a secnonce bound to a different pubkey is an
      upstream-internal state the Swift API cannot construct).
      `vectorsLoadCorrectly`'s hardcoded counts update to the full
      file. Lands last in the group — the skips cite T027's gate, the
      valid cases ride T026's ordered aggregation, and the verify
      sections exercise the post-T028 signature ·
      `Projects/Resources/MuSig2VectorTests/sign_verify_vectors.json`,
      `Projects/Sources/MuSig2VectorTests/` · non-breaking — test-side
      only

**Checkpoint:** ordered aggregation matches the official
`key_agg_vectors.json`; a 38-byte message throws on every MuSig
signing-path input while a 38-byte digest verifies at natural length;
no MuSig verifier takes an unconsulted parameter; the restored
`sign_verify_vectors.json` drives every expressible case — `msg_index`-0
valid cases end to end, empty/38-byte stated-skipped, error/fail
sections asserted or skipped; `swift test` green. T026–T028 land
breaking — the migration note names `sortedPublicKeys(_:)`, the
exact-32 signing gate as an upstream limit, and the dropped label;
T030 is test-side only.

## Group E — Verify-after-sign (PRs 8–12 — the T024 seam PR, then one path per PR)

- [ ] T024 [P] Corruption-seam infrastructure — lands inert as its own
      small PR, nothing consulting it until T009 (spec 002's T019
      inert-skeleton precedent): the package-internal (never `public`)
      hook that signing methods consult between producing signature
      bytes and self-verifying them — a `nonisolated(unsafe)` static
      closure stored `nil` in production and set only from `@testable`
      test code, guarded by the same `NSRecursiveLock` pattern
      `Invariant.swift` already uses for its handler state (Swift 6
      strict concurrency rejects an unadorned mutable static) — plus the
      exit-test helper reusing the existing child-process pattern,
      `#expect(processExitsWith:)` observing a stderr marker, as
      `Tests/P256KTests/InvariantTests.swift` already does for the crash
      channel · `Sources/P256K/` (the seam definition), new file under
      `Tests/P256KTests/`
- [ ] T009 Schnorr: after `secp256k1_schnorrsig_sign_custom` succeeds,
      re-verify against the derived x-only key via
      `secp256k1_schnorrsig_verify`; failure → `P256K.invariantFailure`.
      DocC cites BIP-340 footnote 14 and upstream's "does not strictly
      follow BIP-340" doc note; the method also gains the one-line consult
      of T024's corruption seam between producing the signature bytes and
      self-verifying them, and this path's fault-injection exit test lands
      — corrupted bytes observed terminating via `invariantFailure`
      (carries T013's Schnorr share); run `benchmark-pr.yml` on the PR and
      attach the comparison to its description (carries T014's share) ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift`, `Tests/P256KTests/`
- [ ] T010 ECDSA: verify the parsed `secp256k1_ecdsa_signature` struct
      against the stored public key — no compact round-trip; the method
      gains the one-line T024 seam consult and this path's fault-injection
      exit test (carries T013's ECDSA share); run `benchmark-pr.yml` on
      the PR and attach the comparison to its description (T014) ·
      `Sources/P256K/ECDSA/ECDSA+Signature.swift`, `Tests/P256KTests/`
- [ ] T011 Recovery: verify via `secp256k1_ecdsa_recover` +
      `secp256k1_ec_pubkey_cmp` against the derived public key (Bitcoin
      Core `SignCompact` technique); the method gains the one-line T024
      seam consult and this path's fault-injection exit test (carries
      T013's Recovery share); run `benchmark-pr.yml` on the PR and attach
      the comparison to its description (T014) ·
      `Sources/P256K/Recovery/Recovery+Signature.swift`, `Tests/P256KTests/`
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
      BIP-327 reference.py's assert; the follow-on audit's unnumbered
      reservation folds in here — the same discipline reaches
      `aggregateSignatures(_:)`: the produced 64-byte aggregate signature
      is verified via `secp256k1_schnorrsig_verify` against the aggregate
      x-only key before returning, `invariantFailure` on failure, with its
      own seam consult and exit test. The method gains the one-line T024
      seam consult and this path's fault-injection exit test (carries
      T013's MuSig share); run `benchmark-pr.yml` on the PR and attach
      the comparison to its description (T014) ·
      `Sources/P256K/MuSig/MuSig+Signing.swift`,
      `Sources/P256K/MuSig/MuSig+Aggregate.swift`,
      `Sources/P256K/MuSig/MuSig+Nonces.swift`,
      `Sources/P256K/Schnorr/Schnorr+Nonces.swift` (the `SecureNonce`
      definition itself — its new companion-pubnonce stored property
      lands here), `Tests/P256KTests/` · **breaking** — the previously
      ignored `pubnonce` becomes validated and can throw
- [ ] T013 _Split into T024 + folds into T009–T012 on review — the
      corruption tests can't exist before the self-checks they exercise
      (the `[P]` marker was wrong for them), and a trailing hook commit
      would re-edit all four signing files: the shared seam lands inert
      as T024's own PR, and each path's one-line consult plus its
      fault-injection exit test rides its own verify task, so every PR
      self-proves. Tick this box in the last of T009–T012._ ·
      `Sources/P256K/`, `Tests/P256KTests/`
- [ ] T014 _Folded into T009–T012 — the run produces no diff, so it is a
      per-PR requirement rather than a reviewable change: each path task
      now carries "run `benchmark-pr.yml`, attach the comparison to the
      PR description", and the checkpoint below asserts the outcome. Tick
      this box when all four comparisons are attached._

**Checkpoint:** T024's seam is in place and all four paths consult it
before returning; corrupted outputs never escape; benchmark deltas are
measured and published on each PR (the "measure-first" promise kept).

## Group F — Rename sweep and initializer trim (PRs 13–14)

- [ ] T015 [P] Rename the three public `bytes` accessors to
      `dataRepresentation`, returning `Data`, plus
      `Signature.Recoverable`'s `var normalize` to `signature` — it
      converts recoverable-to-standard format via
      `secp256k1_ecdsa_recoverable_signature_convert` and never touches
      the S scalar, so `normalize` promises low-S work it doesn't do
      (audit finding B-5; the property's own doc already warns the output
      is not guaranteed low-S). All four get
      `@available(*, deprecated, renamed:)` aliases returning the old shape
      — one PR, four renames · `Sources/P256K/ECDSA/ECDSA+XonlyKey.swift:48`,
      `Sources/P256K/Schnorr/Schnorr+XonlyKey.swift:50`,
      `Sources/P256K/MuSig/MuSig.swift:243`,
      `Sources/P256K/Recovery/Recovery+Signature.swift:115` ·
      **breaking-soft** (aliases carry consumers until 1.0)
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
a scratch consumer calling the renamed accessors compiles
(the removed signing, verify, and cache-initializer names intentionally
fail); the public signature surface names no upstream-internal type.

## Group G — Managed context ownership (PR 15)

- [ ] T029 [P] A managed owner for `secp256k1_context` —
      `Context.create()` returns a raw `OpaquePointer` with no typed
      lifecycle (`Context.swift:129`): nothing pairs the pointer with
      `secp256k1_context_destroy`, so a consumer-created context leaks
      a few hundred bytes of ecmult-generator blinding state, callbacks,
      and flags per context — the vendored
      `secp256k1_context_struct` carries no per-context tables — small
      per leak, unbounded in count, with the destroy contract
      unenforced (audit finding B-6). The wave adds a managed owning
      type in swift-crypto's `BackingStorage` idiom — a value-type facade
      holding `final class` storage that owns the pointer — whose init
      runs `create()`'s existing sequence verbatim
      (`secp256k1_context_create`, the illegal/error callbacks routed to
      `P256K.invariantFailure`, `secp256k1_context_randomize` on 32
      `SecureBytes`) and whose `deinit` calls
      `secp256k1_context_destroy` — the exact lifecycle
      rust-secp256k1's `Secp256k1` implements via `Drop`, and the
      create-once-randomize-once path upstream's context contract
      prescribes for lock-free shared use. `Sendable` follows from
      upstream's const-call thread-safety — randomize and destroy exist
      only at init and deinit (`~Copyable` was rejected: contexts are
      long-lived and shared, unlike the one-shot `SecureNonce`). Raw
      access stays explicit through a labeled interop accessor — rust's
      `ctx()` equivalent — `Context.create()` gains
      `@available(*, deprecated, message:)` naming the managed type
      (`renamed:` is wrong here: its fix-it would rewrite callers into
      code returning the managed type where an `OpaquePointer` is
      expected, and cannot typecheck), and the shared
      `rawRepresentation` global is unchanged
      (process-lifetime by design). Tests cover create/use/deallocate
      ordering, `Sendable` concurrent use, and the interop accessor
      reaching the C API · `Sources/P256K/Context.swift` or a new file
      beside it, `Tests/P256KTests/` · **breaking-soft** — `create()`
      deprecated, forwarding until 1.0

**Checkpoint:** a consumer-held managed context deallocates cleanly under
`deinit`; `create()` callers get a deprecation warning naming the managed
type; `swift test` green.

## Group H — Tag (release step, no code)

- [ ] T017 Roll `[Unreleased]` into `[0.25.0]`, cut the tag only after
      every breaking task merges (T004–T006, T012, T015–T016, T026–T028)
      and the deprecation pairs land (T025's redaction rides along; T029's
      managed type plus `create()` deprecation ships inside the same
      tag); in the same change bump the README example from
      `.upToNextMinor(from: "0.24.0")` to `.upToNextMinor(from: "0.25.0")`;
      publish the migration note as the release body ·
      `CHANGELOG.md`, `README.md`, git tag

**Checkpoint:** exactly one tag exists between the wave's pre-state and
post-state; every breaking symbol in the changelog names its replacement.

## Group I — Documentation recipes (PR 16)

- [ ] T018 [P] DocC article: fixed-32-byte signing flow (hash → sign via the
      32-byte method → verify), shown only against the post-redesign API;
      the test compiling this article's exact code against the library
      lands with it (carries T020's share) · `Sources/P256K/P256K.docc/`,
      `Tests/P256KTests/`
- [ ] T019 DocC article: key agreement + key derivation — slice the
      compressed-point prefix byte for the bare 32-byte shared x, feed it
      unhashed to `HKDF<SHA256>` (CryptoKit/swift-crypto), salt guidance
      with the verified NIP-44 v2 shape as the worked example; states it is
      an example composition; the test compiling this article's exact code
      lands with it (carries T020's share) · `Sources/P256K/P256K.docc/`,
      `Tests/P256KTests/`
- [ ] T020 _Folded into T018/T019 — each article lands with the test that
      exercises its own code (the same change-carries-its-proof shape as
      the Group C folds); one compile-scaffold file, extended per article.
      Tick this box in T019's commit._ · `Tests/P256KTests/`

**Checkpoint:** articles build in the DocC catalog; their code is exercised
by tests; no protocol-named public API exists anywhere in the diff.

## Group J — CI assurance (PRs 17–18)

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

T001–T003 (A) before everything. T025 (B) is independent — its own early
PR. T004–T008 (C) before Group D (conformance reshapes the MuSig surface
the verify tasks exercise) and before T018–T020 (articles show the final
API). Group D (T026–T028, T030) before Group E for the same reason — T012's
self-verify rides the post-conformance API. T024 lands first in Group E —
inert machinery with no prerequisites; T009–T012 may parallelize among
themselves after C + D + T024 — T012 is breaking, so it lands before T017
alongside the other breaking tasks. Group F any time after C but before
T017. Group G (T029) before T017 — the managed type and its deprecation
ship inside the same tag. Groups I and J parallel after their gates.
