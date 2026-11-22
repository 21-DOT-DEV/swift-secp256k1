# Tasks — 005 · Remove `format:` parameters

Ordered work for [the plan](./plan.md); measured evidence in
[research.md](./research.md).

Format: `- [ ] TNNN [P?] what lands · files`. Groups are review slices; accessors land
first because every later removal leans on them. The Accessors group is non-breaking
and is a valid standalone PR; the remaining groups are one breaking-change PR in
commit order.

## Accessors — the replacement lands first

- [x] T001 [P] `uncompressedRepresentation` on `Recovery.PublicKey` — same delegation
  to stored serialization as the two existing accessors · `Sources/P256K/Recovery/Recovery.swift`
- [x] T002 [P] `uncompressedRepresentation` on `Schnorr.PublicKey` · `Sources/P256K/Schnorr/Schnorr+PublicKey.swift`
- [x] T003 [P] `uncompressedRepresentation` on `MuSig.PublicKey` · `Sources/P256K/MuSig/MuSig.swift`
- [x] T004 Same-point tests: each new accessor returns 65 bytes encoding the same
  point as `dataRepresentation`, verified by SEC1 byte correspondence — `0x04` tag,
  bytes 1–32 equal the key's compressed X coordinate, byte 64's low bit equals the
  `0x02`/`0x03` tag parity (the `serialize33`/`serialize65` contract in vendored
  `eckey_impl.h:38-55`) — uniform across all five public-key types (`Recovery.PublicKey`
  exposes no `xonly`/`parity`), on both compressed- and uncompressed-stored keys ·
  `Tests/P256KTests/TweakTests.swift` (or a representation-focused file if one
  exists by then)

**Checkpoint:** all five public-key types produce 65-byte output through an accessor;
nothing removed yet; `swift test` green.

## Inferred-format initializers

- [x] T005 Internal `P256K.Format.inferred(serializedPublicKeyCount:)` — 33 →
  `.compressed`, 65 → `.uncompressed`, else throws `incorrectKeySize`; the four
  internal `secp256k1_ec_pubkey_parse` sites that fed `format.length` as the
  input length now pass the buffer's own count, with the three constructors
  (both `validatedBytes` inits, recovery `init(_:signature:format:)`) gaining
  `precondition(buffer.count == format.length)` while
  `XonlyKeyImplementation.generate`'s existing count guard already covers it —
  the caller-length-into-stored-parse shape the advisory exposed, retired
  inside the module · `Sources/P256K/Keys/P256K.swift`,
  `Sources/P256K/Keys/PublicKeyImplementation.swift`,
  `Sources/P256K/Keys/PrivateKeyImplementation.swift`,
  `Sources/P256K/Keys/XonlyKeyImplementation.swift`,
  `Tests/P256KTests/FormatInferenceTests.swift`
- [x] T006 `init(dataRepresentation:)` on the four byte-describing public-key types
  (`Signing`, `Schnorr`, `MuSig`, `KeyAgreement`) delegating through T005 ·
  `Sources/P256K/ECDSA/ECDSA+PublicKey.swift`, `Sources/P256K/Schnorr/Schnorr+PublicKey.swift`,
  `Sources/P256K/MuSig/MuSig.swift`, `Sources/P256K/ECDH.swift`
- [x] T007 Deprecate `init(dataRepresentation:format:)` at the same four sites via
  `renamed:` (output-identical for both labels) — each shim checks
  `data.count == format.length` (preserving `incorrectKeySize`) then delegates
  to `self.init(dataRepresentation:)`. Companion change the task's hybrid
  assertion requires: `XonlyKeyImplementation.generate` now also reserializes
  its already-parsed point (`secp256k1_ec_pubkey_serialize` can never emit the
  hybrid tag), so `PublicKeyImplementation` stores canonical `0x02`/`0x03`/`0x04`
  bytes rather than the input verbatim — new and deprecated paths canonicalize
  identically, matching upstream's parse-lenient/emit-canonical architecture and
  rust-secp256k1's `from_slice`. Tests split by file charter: inferred-init
  acceptance, hybrid canonicalization, and non-SEC1-length rejection land in
  `FormatInferenceTests.swift` (including a parity-inconsistent `0x07` vector
  upstream rejects); shim byte-parity and the `count`/`format` mismatch →
  `incorrectKeySize` contract land in `DeprecatedAliasTests.swift` under
  `@available(*, deprecated)` marks; incidental `format:` callers in
  `AsymmetricTests.swift`, `MusigTests.swift`, `SilentPaymentsAPIShapeTests.swift`
  migrate to the inferred init; the same migration reaches
  `Projects/Sources/MuSig2VectorTests/` (14 sites — Tuist-only, invisible to
  `swift test`) · `Sources/P256K/Keys/XonlyKeyImplementation.swift`,
  `Sources/P256K/Keys/PublicKeyImplementation.swift`,
  `Sources/P256K/Keys/PrivateKeyImplementation.swift`, the four public-key files,
  `Tests/P256KTests/FormatInferenceTests.swift`,
  `Tests/P256KTests/DeprecatedAliasTests.swift`,
  `Tests/P256KTests/AsymmetricTests.swift`, `Tests/P256KTests/MusigTests.swift`,
  `Tests/P256KTests/SilentPaymentsAPIShapeTests.swift`,
  `Projects/Sources/MuSig2VectorTests/` (8 files)

**Checkpoint:** `PublicKey(dataRepresentation: b)` compiles warning-free for 33- and
65-byte inputs; mismatched explicit labels still throw `incorrectKeySize` via the shim.

## Bare operations

- [x] T008 `add(_:)`, `multiply(_:)` on `Signing.PublicKey`; `add(_:)` on
  `MuSig.PublicKey` — compressed storage always; deprecate the `format:` overloads
  via `message:` naming `uncompressedRepresentation` as the `.uncompressed`
  migration, keeping current bodies so `.uncompressed` still stores uncompressed
  until 1.0. Test policy (subject rule): tests whose subject is the deprecated
  signature keep their calls under `@available(*, deprecated)` marks —
  `musigTweakUncompressedOutput`, `musigTweakChainedFormats`,
  `musigUncompressedTweakExitsNormally`, `publicKeyOperationsHonorBothFormats`;
  incidental callers migrate (`musigTweakMatchesPublicKeyOracle`'s uncompressed
  oracle line; the five `init(dataRepresentation:format:)` calls T004 left in
  `TweakTests.swift` move to `init(dataRepresentation:)`, output-identical);
  parity pins for the three deprecated ops land in `DeprecatedAliasTests.swift` ·
  `Sources/P256K/ECDSA/ECDSA+Tweak.swift`,
  `Sources/P256K/MuSig/MuSig+Tweak.swift`,
  `Tests/P256KTests/DeprecatedAliasTests.swift`,
  `Tests/P256KTests/TweakTests.swift`, `Tests/P256KTests/MusigTests.swift`,
  `Tests/P256KTests/InvariantTests.swift`
- [x] T009 `combine(_:)` on `Signing.PublicKey`; deprecate `combine(_:format:)` via
  `message:` naming `uncompressedRepresentation` for `.uncompressed` callers,
  keeping the body until 1.0. Parity pin lands in `DeprecatedAliasTests.swift`;
  two permanent pins cover the `combine([])`-returns-self edge and the
  uncompressed-stored-input leg that previously existed only inside the
  deprecated-marked `publicKeyOperationsHonorBothFormats`; the README example
  drops the deprecated label · `Sources/P256K/Combine.swift`,
  `Tests/P256KTests/DeprecatedAliasTests.swift`,
  `Tests/P256KTests/AsymmetricTests.swift`, `Tests/P256KTests/TweakTests.swift`,
  `README.md`
- [x] T010 `Recovery.PublicKey.init(_:signature:)` (both overloads) without `format`;
  deprecate the `format:` overloads via `message:` naming `uncompressedRepresentation`
  as the `.uncompressed` migration, keeping current bodies so `.uncompressed` still
  stores uncompressed until 1.0. Parity pin for both deprecated overloads lands in
  `DeprecatedAliasTests.swift`; the uncompressed-stored Recovery leg of
  `uncompressedRepresentationEncodesSamePoint` folds into the same pin — the type is
  derivation-only, so that state is reachable only through the deprecated
  initializer · `Sources/P256K/Recovery/Recovery.swift`,
  `Tests/P256KTests/DeprecatedAliasTests.swift`, `Tests/P256KTests/TweakTests.swift`

**Checkpoint:** every public-key operation is format-free; deprecated calls warn but
return byte-identical results (covered in `Tests/P256KTests/DeprecatedAliasTests.swift`);
`add(t)` resolves to the new overload with no warning (compile-verified per plan §6).

## Private-key initializers

- [x] T011 `init()`, `init(_:)`, `init(dataRepresentation:)` without `format` on
  `Signing.PrivateKey`; `init()`, `init(dataRepresentation:)` on `Recovery.PrivateKey`
  and `KeyAgreement.PrivateKey` — only `Signing.PrivateKey` has an `init(_:format:)`
  to replace (`ECDSA+PrivateKey.swift:191`) — companion `publicKey` always
  compressed · `Sources/P256K/ECDSA/ECDSA+PrivateKey.swift`,
  `Sources/P256K/Recovery/Recovery.swift`, `Sources/P256K/ECDH.swift`,
  `Tests/P256KTests/AsymmetricTests.swift`, `Tests/P256KTests/ECDHTests.swift`,
  `Tests/P256KTests/RecoveryTests.swift`,
  `Sources/P256K/Schnorr/Schnorr+PrivateKey.swift` (stale `publicKey`/`init()`
  doc claims only — adjacent stored-form inconsistency recorded in
  `Development/Roadmap/backlog.md`, behavior unchanged)
- [x] T012 Deprecate the seven `format:` initializers via `message:` naming
  `publicKey.uncompressedRepresentation` as the `.uncompressed` migration,
  forwarding to the existing internal format machinery; tests cover deprecated
  private-key paths producing byte-identical results · same files +
  `Tests/P256KTests/DeprecatedAliasTests.swift`

**Checkpoint:** `PrivateKey()` compiles warning-free; `PrivateKey(format:
.uncompressed)` warns and still yields an uncompressed-stored `publicKey`.

## ECDH shared secret — the exception eliminated, not documented

- [x] T013 Re-review eliminated the last `format:` parameter rather than
  documenting it as the exception: `SharedSecret` gains
  `uncompressedRepresentation` (returns the 65-byte SEC1 form the hash closure
  captures inside `secp256k1_ecdh` — upstream hands both coordinates to the
  callback in constant time, so the accessor is a `SecureBytes` copy, never a
  `ge_set_xo_var`/`fe_normalize_var` re-parse of secret material — recorded
  decision in plan §6), the bare
  `sharedSecretFromKeyAgreement(with:)` witness goes `public` carrying the
  `.compressed` body, `sharedSecretFromKeyAgreement(with:format:)` deprecates
  via `message:` keeping its body until 1.0, and the write-only
  `SharedSecret.format` stored property is deleted (`ss.count` discriminates
  identically). Parity pin lands in `DeprecatedAliasTests.swift`; the
  SEC1-correspondence accessor test in `ECDHTests.swift`, which also gains a
  known-answer pin — stored secrets checked byte-for-byte against the published
  6·G and 7·G SEC1 encodings (odd and even Y), closing the self-consistency
  blind spot review found; incidental `format:`
  callers migrate (`ECDHTests.keyAgreement`, both `DocRecipeTests`
  uncompressed bindings, `WycheproofTests`) · `Sources/P256K/DH.swift`,
  `Sources/P256K/ECDH.swift`, `Tests/P256KTests/ECDHTests.swift`,
  `Tests/P256KTests/DeprecatedAliasTests.swift`,
  `Tests/P256KTests/DocRecipeTests.swift`,
  `Tests/P256KTests/SecretRedactionTests.swift`,
  `Projects/Sources/WycheproofTests/ECDHWycheproofTests.swift`, `README.md`
- [ ] T014 `SharedSecret` stores the captured point, not a serialization — `ss`
  and the `uncompressed` sidecar collapse into one `point: SecureBytes` holding
  the 65-byte `0x04‖x‖y` form the hash closure already writes inside
  `secp256k1_ecdh`, plus an internal `exposedForm` tag naming which view
  `withUnsafeBytes` emits (`.uncompressed` only under the deprecated shim — the
  tag retires with it at 1.0). Every byte accessor becomes total:
  `uncompressedRepresentation` is `Data(point)` with no guard branch;
  `withUnsafeBytes` returns the stored bytes for `.uncompressed`, otherwise
  materializes the 33-byte compressed view into a per-access `SecureBytes` temp
  (`0x02 | (y & 1)` + X copy, branchless — the same derivation T013 applied at
  derivation time, moved to the boundary); `==`/`hash` compare the point, so a
  deprecated-`.uncompressed` and a canonical secret for the same ECDH pair
  compare equal — a deliberate tighten over stored-serialization equality;
  `description` reports the exposed view's count so the redaction pins hold.
  `init(ss:)` becomes `init(point:exposedForm:)` — the compressed-only state is
  unconstructible at every site including fixtures, and the accessor's
  `invariantFailure` branch deletes outright; `SecretRedactionTests` keeps both
  `description` cases by building `init(point: Self.uncompressedSecret,
  exposedForm: .compressed)` for the 33-byte pin. Recorded decision in plan §6;
  §3 diagram corrected in the same edit · `Sources/P256K/DH.swift`,
  `Sources/P256K/ECDH.swift`, `Tests/P256KTests/SecretRedactionTests.swift`

**Checkpoint:** `SharedSecret` storage is the captured point; every accessor is
total over constructible states; all T013 behavior pins stay green — same review
slice, second commit after T013 stages.

## Docs + bookkeeping

- [ ] T015 DocC articles + doc comments scrubbed of removed-parameter references
  — including `DerivingKeysFromSharedSecrets.md` and
  `EllipticCurveDiffieHellman.md`, whose `sharedSecretFromKeyAgreement` examples
  move to the `uncompressedRepresentation` accessor;
  `[Unreleased]` CHANGELOG `Breaking:`/`Deprecated:` entries — including the
  `Breaking:` note that `KeyAgreement.PublicKey(dataRepresentation:)` now accepts
  65-byte input (the `.compressed` default previously rejected it; migration: check
  `data.count == 33` for a compressed-only filter), and a second `Breaking:` note
  for hybrid input on the *deprecated* `init(dataRepresentation:format:)` paths:
  pre-deprecation code echoed `0x06`/`0x07` tags through `dataRepresentation`,
  while the deprecated shims now canonicalize to `0x04` identically to the
  inferred init — plus a `Deprecated:` entry for
  `sharedSecretFromKeyAgreement(with:format:)` naming
  `SharedSecret.uncompressedRepresentation` as the 65-byte migration — plus a
  `Changed:` entry for T014's `SharedSecret` equality tighten (canonical and
  deprecated-`.uncompressed` secrets over the same point now compare equal;
  the comparison stays `safeCompare`-constant-time). The two articles'
  `sharedSecretFromKeyAgreement` snippets and the `[Unreleased]` entries
  landed early with T013's jury-review fixes · `Sources/P256K/P256K.docc`,
  `CHANGELOG.md`

**Checkpoint:** plan §5 verification list all pass; `grep 'format: P256K.Format'` shows
only the enumerated survivors — no *non-deprecated* public `format:` parameter
anywhere.
