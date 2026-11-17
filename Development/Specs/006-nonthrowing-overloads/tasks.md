# Tasks — 006 · Non-throwing signing and key generation + fail-closed verifier

Ordered work for [the plan](./plan.md); measured evidence in
[research.md](./research.md).

Format: `- [ ] TNNN [P?] what lands · files`. Four review slices, one PR —
the `throws` removal, keygen retry, and verify helper are independent, land
in any order, and each closes on its own test slice. The breaking changelog
entry lands in the same PR.

## Dead-`throws` removal

- [ ] T001 [P] Remove `throws` from `signature(for:)` and
      `signature(customMessage:)`; rewrite both doc comments (drop
      `- Throws:` clauses and "Never throws in practice" notes) ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift`
- [ ] T002 Sweep: `try`/`try?`/`try!`/`do`–`catch` on both methods in
      `Sources/` and `Tests/` — all warn (`UnnecessaryEffectMarker`),
      erroring only under warnings-as-errors · `Sources/`, `Tests/`
- [ ] T003 Tests: non-throwing-call compile proofs for both methods;
      BIP-340 vector round-trip through `signature(for:)` · `Tests/`

**Checkpoint:** both methods call with zero `try` and round-trip correctly;
the `message:`/`auxiliaryRand:` variants still carry `throws` for their
reachable length contracts.

## Keygen retry

- [ ] T004 [P] `PrivateKeyImplementation(format:)`: draw→`ec_seckey_verify`→retry
      loop (8-draw exhaustion → `P256K.invariantFailure`) delegating to
      `init(validatedBytes:format:)`; drop `throws` + `- Throws:` docs there
      and on the four public forwarding inits ·
      `Sources/P256K/Keys/PrivateKeyImplementation.swift`,
      `Sources/P256K/ECDSA/ECDSA+PrivateKey.swift`,
      `Sources/P256K/Schnorr/Schnorr+PrivateKey.swift`,
      `Sources/P256K/Recovery/Recovery.swift`, `Sources/P256K/ECDH.swift`
- [ ] T005 Sweep `try` on the four public keygen inits in `Sources/` and
      `Tests/` · `Sources/`, `Tests/`
- [ ] T006 Tests: non-throwing-call proofs for all four public keygens;
      produced keys still parse; internal test-only RNG seam on the
      funnel (project-owned — never inside vendored `SecureBytes`) plus a
      `CorruptionSeamTests`-style exit test asserting 8-draw exhaustion
      reports through `invariantFailure` without hanging · `Tests/` +
      seam in `Sources/P256K/Keys/PrivateKeyImplementation.swift`

**Checkpoint:** all four public keygen inits call with zero `try`; the
verify still runs inside the loop — no validation removed; a defective
CSPRNG exhausts to `invariantFailure`, not a hang.

## Verify one-shot

- [ ] T007 [P] `static XonlyKey.isValid(_:for:publicKey:) -> Bool` composing
      `try?` on both parses + `xonly.isValid` ·
      `Sources/P256K/Schnorr/Schnorr+Signature.swift`
- [ ] T008 Tests: valid → `true`; bad signature → `false`; short public key
      → `false`; `0xFF…FF` X coordinate → `false` · `Tests/`

**Checkpoint:** raw-bytes verify is one `Bool` call with zero `try`;
every malformed input yields `false`.

## Release artifacts

- [ ] T009 `CHANGELOG.md` `[Unreleased]` — `**Breaking**` entry naming both
      methods, the four keygen inits, and the consumer-visible effect
      (former `try` sites warn; error under warnings-as-errors), plus
      an `Added` entry for the verifier · `CHANGELOG.md`
- [ ] T010 DocC topic lists name the changed/new members ·
      `Schnorr+Signature.swift` `## Topics` blocks

**Checkpoint:** diff shows the `throws` removals, the `init(format:)`
retry-loop rewrite, and additive insertions — no other signature touched;
`swift build` and `swift test` clean; the break is named for the next
breaking tag.
