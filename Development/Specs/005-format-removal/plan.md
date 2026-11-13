---
feature: 005
title: Remove `format:` parameters — representations at the boundary, points inside
phase: null
status: Planned
updated: 2026-11-12
adrs: []
---

# Remove `format:` parameters — representations at the boundary, points inside

GHSA-7g3x-fj89-693j exposed `MuSig.PublicKey.add(_:format:)` feeding a caller-chosen
*output* format into the *input* parse of stored bytes — a reachable state that was
misclassified as unreachable. The 0.25.x fix restores the parameter's documented
contract; this feature removes the parameter class that admitted the bug. `P256K.Format`
itself stays as the stored-form vocabulary (`.format`, `.length`, internal serialize
flags). What goes away is `format:` *as a caller-supplied parameter* everywhere it names
a pure representation choice: public-key operations always return compressed storage,
65-byte output moves to `uncompressedRepresentation` accessors (already present on two
of five public-key types, added here to the other three), and byte-describing
initializers infer 33-vs-65 from `data.count` — `secp256k1_ec_pubkey_parse` sniffs the
tag either way, so the label was redundant. One parameter survives:
`sharedSecretFromKeyAgreement(with:format:)` changes the shared secret's *own bytes*,
which is a protocol choice, not an encoding preference. Ordered work: tasks.md.
Evidence: research.md.

## 1. Goal & success criteria

- No *non-deprecated* public `format:` parameter remains except
  `sharedSecretFromKeyAgreement(with:format:)`, which is documented as the deliberate
  exception. `grep -rn 'format: P256K.Format' Sources/P256K` returns only expected
  survivors: that signature, the `@available(*, deprecated)` forwarding shims enumerated
  in research.md §4 (kept until 1.0), the public `.format` reporting properties, and
  internal parameters — including `SharedSecret`'s internal stored `format`
  (`DH.swift:70`, no access modifier).
- Every public-key type (`Signing`, `Recovery`, `Schnorr`, `MuSig`, `KeyAgreement`)
  can produce a 65-byte `uncompressedRepresentation`; the three accessors added here
  match the two that exist byte-for-byte.
- Every removal lands with a replacement named: bare overloads for operations,
  inferred-length initializers for byte inputs, `uncompressedRepresentation` for
  65-byte output, `init()`/`init(dataRepresentation:)` for private keys — plus
  `init(_:)` on `Signing.PrivateKey`, the only private-key type with a `UInt256`
  initializer today (`ECDSA+PrivateKey.swift:191`).
- Deprecated shims preserve observable behavior for callers who keep the explicit
  `format:` label — same stored format, same thrown error class (`incorrectKeySize`
  where a length/format mismatch threw before) — so a caller who ignores the warning
  sees no behavioral change.
- Un-parametered call shapes keep compiling without warnings where they exist today:
  `PrivateKey()` and `add(tweak)` resolve to the new overloads (Swift prefers the
  candidate requiring fewer default arguments — the ambiguity check is in §6).
  `PublicKey(dataRepresentation: bytes)` is new API on `Signing`, `Schnorr`, and
  `MuSig` — their `init(dataRepresentation:format:)` declares no default — and a
  documented `Breaking:` widening on `KeyAgreement` (recorded decision in §3).

## 2. Scope

**In scope:**

- 17 removable `format:` sites across `Sources/P256K/` — full taxonomy in research.md §4:
  - Operations (6): `MuSig.PublicKey.add`, `Signing.PublicKey.add`, `Signing.PublicKey.multiply`,
    `Signing.PublicKey.combine`, `Recovery.PublicKey.init(_:signature:format:)` ×2 overloads.
  - Private-key initializers (7): `Signing.PrivateKey` ×3, `Recovery.PrivateKey` ×2,
    `KeyAgreement.PrivateKey` ×2 — the parameter only ever steered the companion
    `publicKey`'s stored form; private-key input bytes are always a 32-byte scalar.
  - Public-key byte initializers (4): `Signing`, `Schnorr`, `MuSig`, `KeyAgreement`
    `init(dataRepresentation:format:)` — replaced by `init(dataRepresentation:)`
    inferring format from byte count.
- Three new `uncompressedRepresentation` accessors (`Recovery.PublicKey`,
  `Schnorr.PublicKey`, `MuSig.PublicKey`).
- Deprecated forwarding shims for every removed signature.
- DocC article and doc-comment updates wherever `format:` is named; `[Unreleased]`
  CHANGELOG `Breaking:`/`Deprecated:` entries.

**Out of scope (with owners):**

- The GHSA-7g3x-fj89-693j fix itself — already landed; this spec removes the class, it is not the patch.
- `P256K.Format` enum and the public `.format` property — stay. Uncompressed storage
  remains reachable via inferred initializers, so `.format` still reports a real state.
- Internal `format:` parameters on `PublicKeyImplementation` / `PrivateKeyImplementation` /
  `XonlyKeyImplementation` — they are how stored form is set; deprecated public shims
  forward through them.
- `sharedSecretFromKeyAgreement(with:format:)` and the internal `SharedSecret.format`
  stored property (`DH.swift:70`) — semantic (see §3), deliberately retained.
- Vendored `Sources/libsecp256k1/` — untouched.
- Actual deletion of the deprecated shims — happens at 1.0 alongside the existing
  `Deprecated:` aliases from 0.25.0 (`.bytes`, `normalize`, `create()`).

## 3. Design

The principle: **representations live at the serialization boundary; points live
inside.** A `format:` parameter is legitimate exactly where caller bytes cross the
boundary — and even there, only when the bytes can't describe themselves. Full SEC
public keys are self-describing (33/65 length + 0x02/0x03/0x04 tag), so the parameter
was redundant at every public-key site. Inside the boundary, an EC point has no format;
the bug this spec retires existed only because an interior call-site let a boundary
vocabulary word (`format`) leak into a second parse that had no business knowing it.

```mermaid
flowchart LR
    subgraph boundary["Serialization boundary — where format exists"]
        init["init(dataRepresentation:)<br/>infers 33/65 from length"]
        read["dataRepresentation (33) ·<br/>uncompressedRepresentation (65) ·<br/>.format (reporting)"]
    end
    subgraph core["Point side — no format vocabulary"]
        impl["PublicKeyImplementation<br/>stored bytes + tweak/signature caches"]
        ops["add · multiply · combine ·<br/>init(_:signature:)"]
    end
    inBytes["caller bytes"] --> init --> impl
    impl --> ops --> impl
    impl --> read --> outBytes["caller bytes"]
    dh["EXCEPTION — sharedSecretFromKeyAgreement(format:)<br/>format selects the secret's own bytes (33 vs 65)<br/>fed to the shared-secret hash = different secret"]
```

Before/after pocket sketch:

```swift
// Before (0.25.x)
try key.add(tweak, format: .uncompressed)
try P256K.Signing.PublicKey(dataRepresentation: bytes, format: .uncompressed)
try P256K.Signing.PrivateKey(format: .uncompressed)          // companion publicKey uncompressed
let ss = try priv.sharedSecretFromKeyAgreement(with: pub, format: .uncompressed)  // stays

// After (this spec)
try key.add(tweak)                                           // always compressed storage
tweaked.uncompressedRepresentation                           // 65 bytes on demand
try P256K.Signing.PublicKey(dataRepresentation: bytes)       // 33/65 sniffed from bytes.count
try P256K.Signing.PrivateKey()                               // companion publicKey compressed
priv.publicKey.uncompressedRepresentation                    // 65 bytes on demand
let ss = try priv.sharedSecretFromKeyAgreement(with: pub, format: .uncompressed)  // unchanged
```

Deprecations, not hard removals: the repo's convention (0.25.0's `.bytes` →
`dataRepresentation`, `normalize` → `signature`, `create()` aliases) keeps renamed or
replaced API forwarding until 1.0. Only the four byte initializers earn
`@available(*, deprecated, renamed:)` — `init(dataRepresentation:format:)` →
`init(dataRepresentation:)` is output-identical for both labels, since inference maps
65 bytes to `.uncompressed`. Every other `format:` overload gets
`@available(*, deprecated, message:)` naming the two-step migration — drop the label
for the compressed-storing replacement, then `uncompressedRepresentation` for 65-byte
output — because a `renamed:` fix-it on `add(t, format: .uncompressed)` would silently
shrink `dataRepresentation` from 65 to 33 bytes. Shims forward to the existing internal
machinery, so `PrivateKey(format: .uncompressed)` still yields an uncompressed-stored
`publicKey` until the shim is deleted.

Inference rule: a new internal `P256K.Format.inferred(serializedPublicKeyCount:)` maps
33 → `.compressed`, 65 → `.uncompressed`, anything else → throw
`secp256k1Error.incorrectKeySize` — the same error the explicit-length check produced,
so error behavior is preserved for malformed input. The C parser's tag check then does
what it always did.

Recorded decision — widened byte-init acceptance (`Breaking:`): inference accepts
whatever `secp256k1_eckey_pubkey_parse` accepts at a given length — standard `0x04`
uncompressed keys *and* legacy hybrid `0x06`/`0x07` encodings at 65 bytes
(`eckey_impl.h:22-32`), matching upstream `secp256k1_ec_pubkey_parse` and
rust-secp256k1's `PublicKey::from_slice` (research.md §2). Only one call shape
silently widens: `KeyAgreement.PublicKey(dataRepresentation:)`, the sole public-key
byte initializer declaring a `format:` default today (`ECDH.swift:94`); the same call
on `Signing`, `Schnorr`, and `MuSig` is new API. Callers who used that bare call as a
compressed-only filter must check `data.count == 33` themselves — no compressed-only
labeled variant is added, since a label for the old behavior would re-admit the
vocabulary this spec removes. A hybrid-ingested key stores `.uncompressed` and
reserializes canonical `0x04` — the parser consumes the tag into a validated point, so
`dataRepresentation`/`uncompressedRepresentation` never echo `0x06`/`0x07`. T014
carries the `[Unreleased]` `Breaking:` entry and the migration note.

## 4. Implementation steps

Ordered as review slices in tasks.md:

1. **Accessors** — add `uncompressedRepresentation` to `Recovery.PublicKey`,
   `Schnorr.PublicKey`, `MuSig.PublicKey` (each delegates to the stored
   `PublicKeyImplementation` serialization path the existing two accessors use);
   same-value tests against `dataRepresentation` for the stored-format-independent
   contract. Non-breaking; could land ahead of the rest.
2. **Inferred initializers** — internal `Format.inferred(serializedPublicKeyCount:)`;
   `init(dataRepresentation:)` on `Signing`, `Schnorr`, `MuSig`, `KeyAgreement`
   public keys; deprecate `init(dataRepresentation:format:)` forwarding through a
   `count == format.length` check so `incorrectKeySize` semantics are preserved.
3. **Bare operations** — `add(_:)`, `multiply(_:)`, `combine(_:)`, and
   `Recovery.PublicKey.init(_:signature:)` without `format`; deprecate the
   `format:` overloads, keeping their bodies so `.uncompressed` still stores
   uncompressed until 1.0.
4. **Private-key initializers** — `init()`, `init(_:)`, `init(dataRepresentation:)`
   producing compressed companion `publicKey`s; deprecate the `format:` variants.
5. **Docs + bookkeeping** — doc-comment and DocC article updates, CHANGELOG
   `Breaking:`/`Deprecated:` entries, the exception documented on
   `sharedSecretFromKeyAgreement`.

## 5. Verification

- [ ] `grep -rn 'format: P256K.Format' Sources/P256K` — the only *non-deprecated*
      public parameter survivor is `sharedSecretFromKeyAgreement(with:format:)`;
      every other public match is an enumerated survivor: a `@available(*, deprecated)`
      forwarding shim at a research.md §4 site (kept until 1.0), a public `.format`
      reporting property, or an internal parameter (implementation `format:`s and
      `SharedSecret`'s internal stored `format` at `DH.swift:70`). Any match outside
      those categories fails this check.
- [ ] `swift build` clean: un-parametered calls (`PrivateKey()`, `add(t)`,
      `PublicKey(dataRepresentation: b)`) resolve without deprecation warnings.
- [ ] `swift test`: every `uncompressedRepresentation` returns the same point as
      `dataRepresentation`, checked by SEC1 byte correspondence on all five
      public-key types — `0x04` tag, identical X coordinate in bytes 1–32, and
      byte 64's low bit matching the compressed tag's `0x02`/`0x03` parity (the
      `serialize33`/`serialize65` contract in vendored `eckey_impl.h:38-55`), so no
      `xonly`/`parity` accessor is needed (`Recovery.PublicKey` has neither);
      inferred inits accept 33/65 — including valid 65-byte hybrid `0x06`/`0x07`
      vectors, which store `.uncompressed` and reserialize canonical `0x04` — and
      reject other lengths with `incorrectKeySize`; deprecated paths produce
      byte-identical results.
- [ ] Compile check that `add(t, format: .uncompressed)` and friends warn but work.
- [ ] DocC build clean — no dangling `format:` symbol references.

## 6. Risks and mitigations

- **Overload ambiguity.** `add(t)` could in principle match both `add(_:)` and
  deprecated `add(_:format:)`. Swift prefers the candidate needing fewer default
  arguments; compile-verified in group 3, and if
  any site still resolves to the deprecated overload silently, drop the default from
  the deprecated signature.
- **Error-class drift on deprecated initializers.** Forwarding `init(dataRepresentation:format:)`
  straight to inference would let `<65B>, format: .compressed` succeed where it used
  to throw. Every deprecated byte-initializer first asserts `data.count == format.length`,
  preserving `incorrectKeySize` for mismatched labels.
- **Capability loss.** Removing `.uncompressed` output with no accessor would strand
  callers who need 65-byte keys — mitigated by ordering: the accessor group lands
  first, and the sweep covers all five public-key types, not just the reported site.
- **Scope creep into `SharedSecret`.** The DH format parameter looks like the same
  shape but changes the secret bytes themselves (33- vs 65-byte serialized point
  hashed into the shared secret). It is named and justified as the exception in §3
  and the diagram so a future sweep doesn't "fix" it.
- **`.format` property staleness.** Left public and honest: uncompressed storage is
  still reachable through inferred initializers, so the property still varies.

## 7. Out of scope (follow-ups)

- Internal `format:` parameters could slim further (e.g. `PrivateKeyImplementation`
  always storing compressed) once callers can't reach uncompressed storage — revisit
  at 1.0 shim deletion.
- If `uncompressedRepresentation` proves the whole uncompressed-storage story,
  `.format` as a public property could deprecate too — deferred; inference keeps
  uncompressed storage reachable today.
- The boundary principle itself (representations at the boundary, points inside) is a
  candidate for ADR 0009 once this ships — it is the generalization this advisory
  taught.

## 8. Division of labor

Review slices map to tasks.md groups: Accessors (T001–T004), Inferred initializers
(T005–T007), Bare operations (T008–T010), Private-key initializers (T011–T012),
Docs + bookkeeping (T013–T014). The accessor group is self-contained and
non-breaking — a valid standalone early PR; the rest lands as one breaking-change PR
in commit order.
