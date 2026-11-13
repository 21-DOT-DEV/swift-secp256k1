# Research — 005 · Remove `format:` parameters

Measured evidence for [the plan](./plan.md). Sections: §1 advisory lineage, §2 peer
precedent, §3 this repo's own direction, §4 the complete site taxonomy, §5 deprecation
mechanics.

## 1. Advisory lineage — why this spec exists

`GHSA-7g3x-fj89-693j` (Low, availability-only): `MuSig.PublicKey.add(_:format:)`
reconstructed the internal C key by parsing `baseKey.bytes` with `pubKeyLen =
format.length`. Aggregate-derived MuSig keys store 33 bytes, so `format: .uncompressed`
passed `inputlen = 65` to `secp256k1_ec_pubkey_parse`, which rejected the encoding —
and `P256K.invariantFailure` converted that reachable failure into process termination.

Two-layer history, verified against git:

- **PR #560** (`57ce9af`, "Swift APIs for MuSig2", 2024-10-16) introduced the wrong
  parse-length argument. It was *silently broken* from day one — `.uncompressed` threw
  `underlyingCryptoError` instead of returning an uncompressed key. No caller could
  have been using the documented capability.
- **PR #1219** (`d2e77e0`, audit-hardening invariant split, 2026-10-22, shipped in
  0.25.0) split the combined throwing guard and reclassified the parse failure as
  unreachable — turning the silent throw into the disclosed crash.

The 0.25.x fix on the same branch deletes the reparse outright —
`secp256k1_musig_pubkey_ec_tweak_add` writes the tweaked key purely from the
key-aggregation cache, so the parse's result was never consumed (CHANGELOG 0.25.1:
"The reparse is deleted outright"). That makes the
parameter *correct*; this spec makes it *impossible to repeat*: with no `format:`
parameter, no interior call site can route an output choice into an input parse.
A post-fix audit of every `secp256k1_ec_pubkey_parse` / `secp256k1_xonly_pubkey_parse`
/ `invariantFailure` call site found the MuSig tweak was the only place
`format.length` reached a stored-bytes parse — the class of bug is what remains.

## 2. Peer precedent — the parameter is an outlier

| API | Where format lives | Evidence |
|---|---|---|
| libsecp256k1 (C) | `secp256k1_ec_pubkey_parse` (in) and `secp256k1_ec_pubkey_serialize` (out) only; `secp256k1_ec_pubkey_tweak_add` / `secp256k1_musig_pubkey_ec_tweak_add` take parsed `secp256k1_pubkey*`, no format anywhere | `Sources/libsecp256k1/include/secp256k1.h`, `secp256k1_musig.h`; vendored `eckey_impl.h:18-35` sniffs 33/65 by `inputlen` + tag |
| rust-secp256k1 | `PublicKey::add_exp_tweak`/`combine` return `PublicKey`; `serialize()` → `[u8; 33]`, `serialize_uncompressed()` → `[u8; 65]` — representation as accessor methods, never parameters | secp256k1-rs PublicKey docs |
| CryptoKit / swift-crypto P256 | `x963Representation`, `compactRepresentation`, `rawRepresentation` — named-representation accessors and initializers; no format enums or parameters anywhere | apple/swift-crypto `P256.Signing.PublicKey` |
| This repo's own additions | `uncompressedRepresentation` already on `Signing.PublicKey` (`ECDSA+PublicKey.swift`) and `KeyAgreement.PublicKey` (`ECDH.swift`) — the missing three are the gap; `KeyAgreement.PublicKey.init(x963Representation:)` already infers 33/65 format by byte length (`ECDH.swift:167-180`, throwing `CryptoKitError.incorrectParameterSize` — the spec's `inferred` keeps `incorrectKeySize` to preserve the deprecated init's error class) | this repo |

Every peer puts representation at the boundary. The `format:` parameter is a
holdover predating the accessors — the peers converged on the shape this spec adopts.

## 3. This repo was already moving this way

- `MuSig` aggregate keys hardcode `.compressed` storage (`MuSig+Aggregate.swift:50-87`)
  — the module's internals never ask for a format.
- `XonlyKey.add` (Schnorr tweak path) and all x-only tweak APIs carry **no** `format:` —
  added later, in the accessor style.
- Schnorr private-key and x-only tweak APIs already had `format:` **removed** in
  earlier API review — precedent for exactly this change.
- Spec 004 (audit-hardening) hardened the boundary vocabulary (`rawRepresentation`,
  `validatedBytes`, installable invariant reporter); this spec deletes the parameter
  that leaked across it.

## 4. Complete `format:` site taxonomy

Every public signature carrying `format: P256K.Format` today (verified by grep):

| # | Site | Parameter's real job | Fate |
|---|---|---|---|
| 1 | `MuSig.PublicKey.add(_:format:)` — `MuSig+Tweak.swift:36` | output serialization choice | `add(_:)` + deprecated shim |
| 2 | `Signing.PublicKey.add(_:format:)` — `ECDSA+Tweak.swift:117` | same | `add(_:)` + deprecated shim |
| 3 | `Signing.PublicKey.multiply(_:format:)` — `ECDSA+Tweak.swift:151` | same | `multiply(_:)` + deprecated shim |
| 4 | `Signing.PublicKey.combine(_:format:)` — `Combine.swift:41` | same | `combine(_:)` + deprecated shim |
| 5–6 | `Recovery.PublicKey.init(_:signature:format:)` ×2 — `Recovery.swift:190,215` | recovered key's stored form | `init(_:signature:)` + deprecated shims |
| 7–9 | `Signing.PrivateKey` `init(format:)`, `init(dataRepresentation:format:)`, `init(_:format:)` — `ECDSA+PrivateKey.swift:120,129,191` | companion `publicKey` stored form only (input is a 32-byte scalar either way) | `init()`, `init(dataRepresentation:)`, `init(_:)` + deprecated shims |
| 10–11 | `Recovery.PrivateKey` ×2 — `Recovery.swift:123,132` | same | same |
| 12–13 | `KeyAgreement.PrivateKey` ×2 — `ECDH.swift:272,281` | same | same |
| 14–17 | `init(dataRepresentation:format:)` on `Signing`, `Schnorr`, `MuSig`, `KeyAgreement` public keys — `ECDSA+PublicKey.swift:141`, `Schnorr+PublicKey.swift:116`, `MuSig.swift:239`, `ECDH.swift:94` | labels self-describing bytes | `init(dataRepresentation:)` inferring from `count` + deprecated shims |
| — | `sharedSecretFromKeyAgreement(with:format:)` — `ECDH.swift:377`; `SharedSecret.format` (internal stored property) — `DH.swift:70` | **semantic**: chooses the secret's own bytes (33 vs 65 serialized point → different `ssHash` input → different secret). `SharedSecret` is opaque — no accessor can recover the other form | **kept**, documented as the exception |

`Recovery.PublicKey` has **no** `init(dataRepresentation:format:)` — recovery keys are
derivation-only, which is exactly why it needs `uncompressedRepresentation` before
`init(_:signature:format:)` can lose its parameter.

## 5. Deprecation mechanics

- `renamed:` fits only the four byte initializers — `init(dataRepresentation:format:)`
  → `init(dataRepresentation:)` is output-identical for both labels (inference maps
  65 bytes to `.uncompressed`). Operations, `Recovery.PublicKey.init`, and private-key
  initializers get `message:` naming `uncompressedRepresentation`, because their
  `.uncompressed` migration is two-step: the bare replacement stores compressed and
  65-byte output then comes from the accessor — a `renamed:` fix-it on
  `add(t, format: .uncompressed)` would silently shrink `dataRepresentation` 65 → 33
  bytes.
- Swift overload resolution prefers candidates requiring fewer default arguments,
  so `PrivateKey()` and `add(t)` resolve to the new signatures with no warning —
  compile-verified in group 3, per plan §6. (Deprecation affects diagnostics, not
  candidate ranking.)
- Of the four public-key byte initializers, only `KeyAgreement.PublicKey`'s declares
  a `format:` default (`ECDH.swift:94`); `Signing` (`ECDSA+PublicKey.swift:141`),
  `Schnorr` (`Schnorr+PublicKey.swift:116-119`), and `MuSig` (`MuSig.swift:239-242`)
  declare none. Bare `init(dataRepresentation:)` is therefore a new call shape on
  those three and a silent widening on `KeyAgreement` only — 65-byte input
  (including hybrid `0x06`/`0x07`, accepted by `eckey_impl.h:22-32`) parses where
  the `.compressed` default threw. Recorded as a `Breaking:` decision in plan §3.
- Deprecated byte-initializers must check `data.count == format.length` **before**
  forwarding, or `init(dataRepresentation: <65B>, format: .compressed)` would stop
  throwing `incorrectKeySize` — a behavioral regression hiding behind a warning.
- Internal `format:` params stay: deprecated shims produce uncompressed storage by
  forwarding to the existing `PrivateKeyImplementation`/`PublicKeyImplementation`
  format paths, so shim behavior is byte-identical to today.
