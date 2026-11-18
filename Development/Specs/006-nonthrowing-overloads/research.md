# Research — 006 · Non-throwing signing and key generation + fail-closed verifier

Measured evidence for [the plan](./plan.md). Sections: §1 the triggering CI
failure, §2 the complete `throws` inventory classified by reachability, §3
the precedent audit for removing a dead `throws`, §4 what does not reduce
and why.

## 1. The trigger — a downstream CI failure on the 0.25.1 bump

A downstream consumer's CI failed on a 0.24.0 → 0.25.1 dependency bump —
`xcodebuild` exit 65 with four errors in a single consumer source file,
all matching documented 0.25.0 breaking changes (CHANGELOG "Migrating from
0.24.x"):

| Error | Documented cause |
|---|---|
| `207: call can throw but is not marked with 'try'` on `XonlyKey(dataRepresentation:)` | X-only initializers gained `throws` — `secp256k1_xonly_pubkey_parse` now validates length **and** curve membership at construction (previously bytes were stored unvalidated and never threw) |
| `173:52` / `173:82`: `'&' used with non-inout argument` on `signature(message:auxiliaryRand:)` | `inout [UInt8]` and `UnsafeMutableRawPointer?` removed; parameters are now `some ContiguousBytes` borrowed read-only |
| `212:46`: `'&' used with non-inout argument` on `isValid(_:for:)` | Same retype `inout [UInt8]` → `some ContiguousBytes` |

Resolution: a follow-up commit on the same change ported all three call
sites (drop `&`, add `try`, plus a `SecRandomCopyBytes` return-check that
had been ignored — a failure would previously have signed with all-zero
auxiliary randomness) and added BIP-340 test vectors; the change merged.
Re-introducing `try` at `XonlyKey(dataRepresentation:)` was therefore
**valid and expected** — not a workaround.

## 2. The complete `throws` inventory, classified

Sweep: `grep -rn "public.*throws\|throws ->" Sources/P256K --include='*.swift' | grep -v swift-crypto`
excluding the vendored `swift-crypto/` tree. ~39 throwing initializers plus
~25 throwing methods, falling into four classes:

**Class 1 — validation boundary (irreducible).** Every
`init(dataRepresentation:)`/`init(derRepresentation:)`/`init(pemRepresentation:)`
across `ECDH`, `ECDSA`, `Recovery`, `Schnorr`, `MuSig`, all three
`XonlyKey` types, `SchnorrSignature`, `ECDSASignature`,
`Recovery.ECDSASignature`, `PartialSignature`, `Nonce`, `HashDigest.init(_:)`,
`SEC1PrivateKey` internals, `UInt256` Codable. The throw *is* the boundary —
bad bytes must be rejected. `try?` is the terse consumer answer.

**Class 2 — multi-condition (no reduction).** `Nonce.generate` ×2 (msg32
count, extraInput32 count, secretKey/publicKey mismatch),
`partialSignature` ×2, `MuSig.aggregate`, `aggregateSignatures`,
`MuSig.XonlyKey.isValidSignature` (msg32 check), `MuSig.PublicKey.isValidSignature`,
tweak `add`/`multiply` family, `combine`, `Recovery.PublicKey.init(_:signature:)`,
`PrivateKey.init(dataRepresentation:)` (caller-supplied bytes — cannot be
re-drawn), `Recovery.PublicKey.init(_:signature:)`'s format+point checks,
ASN1 `readOIDSubidentifier`. Several
reachable failure modes per call.

**Class 3 — dead `throws` (this spec's removals).**

| Method | Evidence |
|---|---|
| `Schnorr.PrivateKey.signature<D: Digest>(for:)` | `Schnorr+Signature.swift:107` — body contains **zero** throwing calls; doc: "Never throws in practice; `throws` is retained for API stability" |
| `Schnorr.PrivateKey.signature(customMessage:)` | `Schnorr+Signature.swift:225` — same doc statement, zero throwing calls |

Both route upstream failure through `P256K.invariantFailure` (the
verify-after-sign self-check added in 0.25.0), not through `throws` — the
keyword is a remnant of the pre-redesign failure channel, kept to cap one
wave's blast radius.

**Class 4 — RNG-bound `throws` (made unreachable by retry, also removed
here).** `PrivateKeyImplementation(format:)` (`PrivateKeyImplementation.swift:107`)
is the funnel behind all four public key-generation initializers —
`Signing.PrivateKey` (`ECDSA+PrivateKey.swift:120`), `Schnorr.PrivateKey`
(`Schnorr+PrivateKey.swift:119`), `Recovery.PrivateKey` (`Recovery.swift:124`),
`ECDH.PrivateKey` (`ECDH.swift:273`). Its single reachable throw is
`secp256k1_ec_seckey_verify` rejecting the drawn scalar (P ≈ 2⁻¹²⁸) — but
the failing input is self-generated and repeatable: `SecureBytes(count:)`
is a fresh CSPRNG draw per call (`Backing.create(randomBytes:)`), so a
draw→verify→retry loop makes the failure unreachable outright rather than
merely unlikely. This is the standard keygen shape: CryptoKit's
`P256.Signing.PrivateKey.init()` is non-throwing for the same reason, and
Bitcoin Core keygens draw until valid. The retry carries an 8-draw
exhaustion bound reporting through `P256K.invariantFailure` — P ≈ 2⁻¹⁰²¹
for a working CSPRNG, so exhaustion can only mean a broken RNG — keeping
the failure mode fail-stop rather than a hang. `init(dataRepresentation:)`
stays in Class 1: caller-supplied bytes cannot be re-drawn.

## 3. Precedent audit — removing a dead `throws`

The design question is whether the dead `throws` is a reservation (room for
the API to gain a reachable failure later) or a remnant. Four sources:

- **Vendored upstream contract** —
  `include/secp256k1_schnorrsig.h`: `secp256k1_schnorrsig_sign_custom`
  "Returns 1 on success, 0 on failure" where failure means illegal
  arguments/contract violation; on an initialized keypair the call cannot
  fail, and upstream explicitly delegates verify-after-sign to callers
  (performed by the wrapper's funnel and checked via `invariantFailure`). A
  non-throwing wrapper is faithful to the upstream contract.
- **rust-secp256k1** — `KeyPair::sign_schnorr*` returns `Signature` with no
  `Result`: the peer wrapper treats Schnorr signing as infallible on a
  validated keypair (`schnorr.rs`, `sign_schnorr_with_rng` →
  `sign_schnorr_helper` asserts the C return).
- **Apple** — pulls both ways, honestly stated: `CryptoKit`'s
  `P256.Signing.PrivateKey.signature(for:)` is `throws` (Apple keeps a
  uniform throw-capable contract on crypto ops), and in
  `apple/swift-openapi-generator#710` Apple declined to omit a dead `throws`
  citing API-evolution room — but `apple/swift-crypto#412` (merged
  2025-09, labeled `semver/patch`) removed `throws` from
  `_RSA.BlindSigning.getKeyPrimitives()`, a shipped public function,
  because "using `try` on a non throwing function only yields a warning."
  Apple removed a dead `throws` as patch-level cleanup.
- **This repo's own direction** — `P256K.Signing.PrivateKey.signature(for:)`
  (`ECDSA+Signature.swift:208`) and both Recovery signing methods
  (`Recovery+Signature.swift:264,347`) are already non-throwing, with the
  same `invariantFailure` discipline. Schnorr's `throws` is the outlier.

**Swift mechanics of the removal.** `throws` is encoded in the mangled
symbol name — immaterial here since the package has no stable ABI and every
consumer recompiles from `.swiftinterface` on any version bump. Source
effects: every `try`, `try?`, `try!`, and `do`/`catch` site compiles — each
degrades to an `UnnecessaryEffectMarker` warning (verified on the 6.1
toolchain; `try?` still yields `Optional`, so `guard let` unwraps fine).
The one hard-error surface is consumers building with warnings-as-errors —
a real but fix-trivial break, named in the changelog and justification for
keeping this on a breaking tag. `DigestSigner` conformance is
unaffected: a non-throwing witness satisfies the protocol's
`throws(CryptoKitMetaError)` requirement (`swift-crypto/Signatures/Signature.swift:35`).

**Residual risk accepted by design**: the option to add a reachable check
to these methods later is foreclosed — a future reachable failure would be
another break. The probability is low (the funnel was designed
non-throwing in the same wave that created these `throws`), and the cost is
symmetric with the change made today.

## 4. What does not reduce

- `XonlyKey(dataRepresentation:)` — the throw is the 0.25.0 validation;
  `try?` is the terse answer. A failable `init?` cannot coexist with a
  throwing `init` of the same signature (invalid redeclaration), and a
  differently-labeled `init?(parsing:)` saves nothing over `try?`.
- `signature(message:)`/`signature(message:auxiliaryRand:)`/
  `signature(for:auxiliaryRand:)`/`signature(customMessage:auxiliaryRand:)` —
  reachable length contracts; `throws` is load-bearing and now *means* the
  contract.
- `HashDigest.init(_:)` — validation boundary; `SHA256.hash(data:)` is the
  non-throwing producer path.
- `signature(for: HashDigest)` overload — considered and rejected: it was
  the additive workaround for the dead `throws`; redundant once the generic
  drops it.
- A public fixed-width 32-byte type (`Bytes32`-style) — deferred (plan §7):
  strictly additive, so no release deadline, and design-heavy enough to
  deserve its own spec; `InlineArray<32, UInt8>` (SE-0453/0483, Swift 6.2)
  is the first-party version of the same idea and is doubly gated — below
  the 6.1 tools-version floor *and* a new-runtime stdlib type — so a floor
  bump is a compatibility decision, not a `try` decision, and would
  naturally ride with the APINotes `BoundsSafety` tier (needs ≥6.2.3 —
  backlog "API Notes for the `libsecp256k1` C boundary"). `SIMD32<UInt8>`
  is a today-available alternative spelling (fixed 32-element count in the
  type under the current floor) — foreign to this codebase's conventions
  (`UInt256` is hand-rolled words, not SIMD), so a candidate shape for that
  future spec to weigh rather than a default.
- Generic `throws(Failure)` collapse — Apple's own concurrency library
  merges paired throwing/non-throwing overloads into one `throws(Failure)`
  signature where `Failure == Never` when the argument doesn't throw. Dead
  here: the mechanism needs throw-ness to derive from a *closure parameter*
  — this surface takes byte buffers, not closures.
- `rethrows`, `throws(Never)`, `Result<Success, Never>` — all dead:
  `rethrows` needs a throwing closure param (none exist), `throws(Never)`
  is literally equivalent to non-throwing, and a `Never`-failure `Result`
  presupposes the operation already can't fail — circular.
- Clang APINotes — rejected as a `try` lever (the importer-ergonomics work
  itself is tracked separately: `Development/Roadmap/backlog.md` → "API
  Notes for the `libsecp256k1` C boundary"): it reshapes how the C headers
  import (`SwiftName`, `Nullability`, `NoEscape`, `counted_by`,
  `SwiftImportAs`/`Sendable`) but has no mechanism that adds or removes
  `throws` — the only throwing-import convention (`swift_error`) needs an
  `NSError **` out-parameter secp256k1's API lacks. Every `try` on this
  surface comes from `throws` declared in `Sources/P256K` Swift sources,
  which APINotes cannot reach. It remains a plausible *internal* ergonomics
  spec — other Swift wrappers of this library already ship apinotes files
  for exactly this — gated on vendir `ignorePaths` entries and a custom
  modulemap, not this spec. Nor can `counted_by` retire the `sign` funnel's
  internal `auxiliaryRand == 32` guard: `ndata` is a `void *` struct field
  whose 32-byte bound is conditional on the default nonce function, the
  wrapper extracts a raw `baseAddress` before the boundary, and a generic
  bounds trap lacks the `invariantFailure` diagnostic + handler channel —
  the guard checks a wrapper-internal invariant no C header declares.
- Internal `try` sweep — mechanical: every `try`-family site warns
  (`UnnecessaryEffectMarker`), erroring only under warnings-as-errors;
  all swept in the same change.
