# Backlog: Future Consideration

**Purpose**: Items deferred for future consideration, not currently scheduled as phases  
**Last Updated**: 2026-10-18

> Items with strong downstream demand were **promoted to first-class phases** (see [roadmap](README.md)): adaptor signatures & MuSig2-L2 (Phase 6), HD-wallet / BIP-32 serialization (Phase 7), Cashu BDHKE + DLEQ (Phase 8), Silent Payments & ellswift (Phase 10), FROST & half-aggregation (Phase 11). General-purpose crypto (ChaCha20, AES, scrypt, SHA-3) is **sourced from swift-openssl** per the Package Separation section — not a backlog item.

---

## ZKP-tier modules not yet phased

`libsecp256k1_zkp` C is vendored; these are lower-priority than the phased adaptor sigs (Phase 6) and BDHKE/DLEQ (Phase 8):

| C module | Capability | Cohort | Priority |
|----------|-----------|--------|----------|
| `secp256k1_ecdsa_s2c` | Sign-to-contract / anti-exfil | Bitcoin | Low |
| `secp256k1_rangeproof` / `secp256k1_surjectionproof` | Confidential assets | Liquid-style | Low |

---

## Niche / deprecated primitives

| Item | Notes | Priority |
|------|-------|----------|
| **SipHash-2-4** | Zone C (built-here low; swift-openssl fallback). Needed by the BIP-152/158 filters below | Low |
| **MurmurHash3 (32-bit)** | BIP-37 Bloom filters; deprecated, not in OpenSSL → only if a consumer needs it | Low |
| **Strict DER validation (BIP-66)** | Likely already handled by libsecp256k1; review only | Low |

---

## Data Structures

General-purpose structures supporting specific BIPs (in-repo vs recommend-external is undecided):

| Item | BIP | Notes |
|------|-----|-------|
| **Bloom Filters** | BIP-37 | Uses MurmurHash3; deprecated (privacy); low |
| **Golomb-Coded Sets** | BIP-158 | Uses SipHash; modern filter; medium if SipHash is built |
| **Merkle Trees / taptrees** | BIP-341 | Tagged-hash based; medium-high for Taproot completeness |

---

## Deferred applications (CLIs)

**Promoted 2026-08-01**: the CLI tools (MuSig2 CLI, address generator, ECDSA signing CLI, Schnorr verifier) were promoted from this backlog to **Phase 9.5 — Command-Line Tool** for the 2026 funding window (Q5 of the shared 2026 roadmap). See [phase-9.5-cli-tool.md](phase-9.5-cli-tool.md).

---

## Platform Support

### Windows Build Support

**Status**: Deferred — placeholder `#if os(Windows)` in `Plugin.swift`  
**Priority**: Low (Windows is not a primary Swift platform)  
**Notes**: `SharedSourcesPlugin` uses POSIX `find + cp`; Windows needs `robocopy /E` or `xcopy /E /I` + a Windows CI runner.  
**Acceptance**: `swift build` succeeds on Windows without symlink errors; Windows CI job passes.

---

## Hardening

### Fixed-size input validation across the C boundary

**Status**: Deferred from the MuSig nonce-generation fix (2026-10-18)  
**Priority**: Medium — memory-safety hardening; every remaining site is an out-of-bounds *read* on a caller-provided length (the only out-of-bounds *write*, `session_secrand32`, was fixed with the MuSig work)  
**Notes**: Public `[UInt8]`/`Digest` parameters reach upstream functions that read a fixed 32 bytes with no length check — a short input reads out of bounds. Sites: `Schnorr+Tweak.swift` `add(_ tweak:)` ×2, `Schnorr+Signature.swift` `signature(for:auxiliaryRand:)` (`ndata`), `ECDSA+Tweak.swift` `add`/`multiply` ×4, `ECDSA+Signature.swift` `signature(for:)` + `isValidSignature(_:for:)` digests, `Recovery+Signature.swift` `signature(for:)`. The MuSig-side instances (`nonce_gen` inputs, `partialSignature` digest, `MuSig+Tweak` ×2) were fixed in the MuSig nonce-generation change — fix pattern there: `guard count == P256K.ByteLength.dimension else { throw secp256k1Error.incorrectParameterSize }` plus `#expect(throws:)` regression tests per `Tests/AGENTS.md`.  
**Acceptance**: Every public `[UInt8]`/`Digest` input feeding a fixed-size C read is length-checked before the call; regression test per site; `swift test` green.

### `keyagg_cache` input on MuSig nonce generation

**Status**: Deferred from the MuSig nonce-generation fix (2026-10-18)  
**Priority**: Medium — misuse-resistance hardening  
**Notes**: BIP-327 recommends feeding the aggregate public key into nonce derivation as defense-in-depth; `secp256k1_musig_nonce_gen` takes it as `keyagg_cache`, which `Nonce.generate` currently passes as `nil`. An optional `publicKeyAggregate:` parameter (accepting `P256K.MuSig.PublicKey`, which already carries the 197-byte cache) would expose it. Once exposed, BIP-327 nonce-gen vector case 1 (`aggpk` set) becomes reproducible at the Swift layer — the vector suite currently skips it with that reason stated. Motivate by misuse resistance, not vector coverage.  
**Acceptance**: `generate` accepts an optional aggregate key and forwards its cache to upstream; BIP-327 case 1 verifies `expected_pubnonce`/`expected_secnonce` exactly.

### `SecureNonce` storage → `SecureBytes`

**Status**: Deferred from the MuSig nonce-generation fix (2026-10-18) — same class as the `SessionSecretRand` storage fix  
**Priority**: Medium — secret-material hygiene  
**Notes**: `P256K.Schnorr.SecureNonce` stores its 132-byte `secp256k1_musig_secnonce` as plain `Data` (`Schnorr+Nonces.swift`); the local C struct it is copied from is never zeroed, and `Data` does not zero on deinit. A leaked secret nonce compromises the signing key just as leaked session randomness does. Moving the storage to `SecureBytes` (auto-`memset_s` on release) mirrors the `SessionSecretRand` fix and the `SharedSecret`/`PrivateKey` precedent. Same sweep: the repo-wide `Array(key.dataRepresentation)` → C-call pattern (signing, tweak, and ECDH paths) also leaves unzeroed secret copies — those sites should read from the key's `SecureBytes` backing via `withUnsafeBytes`, as `Nonce.generate` now does for `secretKey`.  
**Acceptance**: `SecureNonce` holds its bytes in `SecureBytes`; the local `secp256k1_musig_secnonce` copies in `Nonce.generate` (output struct holding the secret nonce) and `partialSignature` (input copy — upstream already zeroes it on success) are explicitly `memset_s`-zeroed after use (`Zeroization.swift` provides the cross-platform shim); secret-key bytes reach C via `withUnsafeBytes` into `SecureBytes` storage rather than `Array` copies; docs updated; `swift test` green.

### Upstream doc links track the vendir pin

**Status**: Split out of the MuSig nonce fix into its own PR (2026-10-18) — drafted, then reverted to keep the security diff pure  
**Priority**: Low  
**Notes**: `Sources/P256K` doc comments link `bitcoin-core/secp256k1` headers on `blob/master`; the vendir pin is `v0.7.1` = commit `1a53f4961f337b4d166c25fce72ef0dc88806618` — verified 2026-10-18: the annotated tag dereferences to the `vendir.lock.yml` SHA (`git ls-remote … refs/tags/v0.7.1^{}`), so `blob/v0.7.1` URLs resolve to the vendored tree. The repoint sweeps ~35 URLs across `Sources/P256K` (incl. 2 `.docc` articles) and should land as a dedicated change; a pin bump should re-sweep the same URLs. Optional automation: extend `Scripts/vendir-check.sh` with a link-consistency probe against the locked ref. `SECURITY.md`'s upstream `SECURITY.md` link correctly stays on `master` (a living policy doc, not pinned code).

---

## Prioritization Criteria

When promoting an item from backlog to a phase:
1. **Downstream reach** — how many in-scope cohorts need it (RICE)
2. **Spec coverage** — fills a real BIP/NIP/NUT/BOLT gap
3. **Dependency chain** — unblocks other work (WSJF opportunity-enablement)
4. **Effort** — cheap overlaps (SHA-2 tower) before standalone primitives
5. **Scope alignment** — secp256k1-native or Bitcoin-utility; general crypto → swift-openssl

---

## Adding to Backlog

New items should include: **Purpose**, **spec reference** (if any), **dependencies**, **priority signal** (with rationale), and **notes**.
