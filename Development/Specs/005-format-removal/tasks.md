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

- [ ] T005 Internal `P256K.Format.inferred(serializedPublicKeyCount:)` — 33 →
  `.compressed`, 65 → `.uncompressed`, else throws `incorrectKeySize` ·
  `Sources/P256K/Keys/PublicKeyImplementation.swift` (or wherever `P256K.Format` lives)
- [ ] T006 `init(dataRepresentation:)` on the four byte-describing public-key types
  (`Signing`, `Schnorr`, `MuSig`, `KeyAgreement`) delegating through T005 ·
  `Sources/P256K/ECDSA/ECDSA+PublicKey.swift`, `Sources/P256K/Schnorr/Schnorr+PublicKey.swift`,
  `Sources/P256K/MuSig/MuSig.swift`, `Sources/P256K/ECDH.swift`
- [ ] T007 Deprecate `init(dataRepresentation:format:)` at the same four sites via
  `renamed:` (output-identical for both labels) — shims check
  `data.count == format.length` (preserving `incorrectKeySize`) then forward; tests
  land here: inferred init accepts 33/65 — including a valid 65-byte hybrid
  `0x06`/`0x07` vector, which parses, stores `.uncompressed`, and reserializes
  canonical `0x04` `dataRepresentation`/`uncompressedRepresentation` byte-identical
  to the same point ingested as `0x04` — and rejects other lengths with
  `incorrectKeySize`; shim `count`/`format` mismatch throws `incorrectKeySize` ·
  same files + `Tests/P256KTests/DeprecatedAliasTests.swift`

**Checkpoint:** `PublicKey(dataRepresentation: b)` compiles warning-free for 33- and
65-byte inputs; mismatched explicit labels still throw `incorrectKeySize` via the shim.

## Bare operations

- [ ] T008 `add(_:)`, `multiply(_:)` on `Signing.PublicKey`; `add(_:)` on
  `MuSig.PublicKey` — compressed storage always; deprecate the `format:` overloads
  via `message:` naming `uncompressedRepresentation` as the `.uncompressed`
  migration, keeping current bodies so `.uncompressed` still stores uncompressed
  until 1.0 · `Sources/P256K/ECDSA/ECDSA+Tweak.swift`,
  `Sources/P256K/MuSig/MuSig+Tweak.swift`
- [ ] T009 `combine(_:)` on `Signing.PublicKey`; deprecate `combine(_:format:)` via
  `message:` naming `uncompressedRepresentation` for `.uncompressed` callers,
  keeping the body until 1.0 · `Sources/P256K/Combine.swift`
- [ ] T010 `Recovery.PublicKey.init(_:signature:)` (both overloads) without `format`;
  deprecate the `format:` overloads via `message:` naming `uncompressedRepresentation`
  as the `.uncompressed` migration, keeping current bodies so `.uncompressed` still
  stores uncompressed until 1.0 · `Sources/P256K/Recovery/Recovery.swift`

**Checkpoint:** every public-key operation is format-free; deprecated calls warn but
return byte-identical results (covered in `Tests/P256KTests/DeprecatedAliasTests.swift`);
`add(t)` resolves to the new overload with no warning (compile-verified per plan §6).

## Private-key initializers

- [ ] T011 `init()`, `init(_:)`, `init(dataRepresentation:)` without `format` on
  `Signing.PrivateKey`; `init()`, `init(dataRepresentation:)` on `Recovery.PrivateKey`
  and `KeyAgreement.PrivateKey` — only `Signing.PrivateKey` has an `init(_:format:)`
  to replace (`ECDSA+PrivateKey.swift:191`) — companion `publicKey` always
  compressed · `Sources/P256K/ECDSA/ECDSA+PrivateKey.swift`,
  `Sources/P256K/Recovery/Recovery.swift`, `Sources/P256K/ECDH.swift`
- [ ] T012 Deprecate the seven `format:` initializers via `message:` naming
  `publicKey.uncompressedRepresentation` as the `.uncompressed` migration,
  forwarding to the existing internal format machinery; tests cover deprecated
  private-key paths producing byte-identical results · same files +
  `Tests/P256KTests/DeprecatedAliasTests.swift`

**Checkpoint:** `PrivateKey()` compiles warning-free; `PrivateKey(format:
.uncompressed)` warns and still yields an uncompressed-stored `publicKey`.

## Docs + bookkeeping

- [ ] T013 `sharedSecretFromKeyAgreement(with:format:)` doc comment gains the
  exception note (format selects the secret's own bytes — protocol choice, not
  encoding preference) · `Sources/P256K/DH.swift`, `Sources/P256K/ECDH.swift`
- [ ] T014 DocC articles + doc comments scrubbed of removed-parameter references;
  `[Unreleased]` CHANGELOG `Breaking:`/`Deprecated:` entries — including the
  `Breaking:` note that `KeyAgreement.PublicKey(dataRepresentation:)` now accepts
  65-byte input (the `.compressed` default previously rejected it; migration: check
  `data.count == 33` for a compressed-only filter) · `Sources/P256K/P256K.docc`,
  `CHANGELOG.md`

**Checkpoint:** plan §5 verification list all pass; `grep 'format: P256K.Format'` shows
only the enumerated survivors — no *non-deprecated* public parameter besides
`sharedSecretFromKeyAgreement(with:format:)`.
