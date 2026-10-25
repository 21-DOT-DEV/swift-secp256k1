---
feature: 004
title: Audit-hardening wave — Schnorr signing redesign, verify-after-sign, BIP-327 MuSig conformance, and CI assurance
phase: null
status: Planned
updated: 2026-10-25
adrs: []
---

# Audit-hardening wave — Schnorr signing redesign, verify-after-sign, BIP-327 MuSig conformance, and CI assurance

A corrective wave against the findings of two independent security audits of
the same package (2026-10-22, plus a follow-on single-target pass; evidence
ledger: [research.md](./research.md)). The first audit found no correctness
defect in the shipped signing or verification paths, but measured a set of
preventable misuse and assurance gaps: the Schnorr
arbitrary-message entry point signs raw unhashed input with no complaint, no
signing path proves its own output, one convenience overload routes caller
randomness through an un-zeroed array copy, three public accessors named
`bytes` return `[UInt8]` where the library's convention is
`dataRepresentation` returning `Data`, upstream-internal parameters leak into
public initializers, and continuous integration never runs a sanitizer across
the Swift↔C boundary. The follow-on audit adds six findings against this
package — `SharedSecret.description` prints the agreed ECDH key in full
(B-1); `MuSig.aggregate` sorts keys internally, contradicting BIP-327's
order-preserving aggregation and the official vectors (B-2); MuSig message
inputs silently pad or truncate to 32 bytes (B-3); the partial-signature
verifier accepts a `digest` parameter it never consults (B-4); the
recoverable-signature `normalize` name promises low-S normalization it does
not perform (B-5); and `Context.create()` returns an unmanaged raw pointer
with no `secp256k1_context_destroy` pairing (B-6). Consumers are pre-1.0; the wave ships its breaking
changes as one 0.25.0 tag cut after the final breaking change lands, and the
wave's first change-set updates the consumer version-pinning advice in
`README.md`, `Development/constitution.md`, and the published
`GettingStarted` guide — today all three advise `exact:` pins, yet SwiftPM's
default `from:` requirement means "any 0.x up to 1.0.0", so an unwarned
consumer using `from:` would auto-update straight into the breakage. Ordered work: [tasks.md](./tasks.md). Evidence:
[research.md](./research.md).

## 1. Goal & success criteria

- The low-level Schnorr signing surface cannot silently sign a raw,
  unhashed, non-32-byte message: the 32-byte and arbitrary-length intents
  are spelled with distinct method names, and auxiliary randomness is a
  length-checked byte container instead of a raw pointer. Measured by a
  test that feeds 100 unhashed bytes and observes a thrown error.
- Every signing path the library ships — Schnorr, ECDSA, recoverable ECDSA,
  and MuSig2 partial signatures — proves its own output before returning:
  a produced signature that fails verification terminates via
  `P256K.invariantFailure` (the existing crash-on-impossible-state channel).
  Measured by fault-injection tests that corrupt the produced bytes and
  observe the channel firing.
- The three public `bytes` accessors get a `Data`-returning
  `dataRepresentation` sibling, with `@available(*, deprecated, renamed:)`
  forwarding aliases that keep the old `[UInt8]` shape until 1.0: old call
  sites compile with only a deprecation warning and a rename fix-it (the
  deprecation practice swift-crypto itself applied for years before removing
  members at a major); **adopting** the new `Data` name is where any
  type adjustment happens, and the migration note says exactly that.
- Continuous integration proves the pointer-heavy Swift↔C boundary on every
  pull request: the memory-error and undefined-behavior sanitizers block
  merges in dedicated Linux container jobs, and the thread sanitizer runs
  macOS-side in advisory mode with a suppression file; a separate job
  regenerates the project's generated Xcode workspace from scratch and runs
  one vector test scheme so a broken regeneration path cannot hide until
  release time.
- The MuSig2 surface conforms to BIP-327: `aggregate(_:)` preserves caller
  key order and passes the official `key_agg_vectors.json`, canonical
  sorting is an explicit `sortedPublicKeys(_:)` step that works on parsed
  points of either stored format, every *signing-path* message input
  (`Nonce.generate` `msg32:`, `partialSignature`) requires exactly 32
  bytes — libsecp256k1's `msg32` limit, since BIP-327 itself permits
  variable-length messages — while both verifiers check at the message's
  natural length (the digest overload drops its silent `msg32Bytes`
  reduction; `isValid(_:for:)` already passes length through to
  `secp256k1_schnorrsig_verify`), and no verifier takes a parameter it
  ignores.
  Measured by the vectors plus negative probes (38-byte input throws;
  reordering keys changes the aggregate).
- No string-rendering path leaks secret material: `SharedSecret.description`
  is redacted, and a contract test asserts every secret-bearing type prints
  nothing but type names. Measured by the redaction contract.
- A created context has a typed owner: a managed type destroys the native
  context in `deinit`, `Sendable` follows upstream's const-call
  thread-safety, and the raw `create()` is deprecated toward it.
- Consumer guidance is truthful before the tag: README and the constitution
  recommend `.upToNextMinor(from:)` — the pre-1.0 constraint Apple's own
  packages advise — and the changelog's existing breaking `[Unreleased]`
  entries roll into 0.25.0 as the migration note's opening section.

## 2. Scope

**In scope:**

- Redesign of `P256K.Schnorr.PrivateKey.signature(message:auxiliaryRand:strict:)`
  and its verification counterpart (the five-method surface in §3.1), plus
  the identical retype of the multi-party verifier
  `P256K.MuSig.XonlyKey.isValid(_:for:)` — post-wave, solo and multi-party
  verification share one non-mutating byte-input pattern.
- Verify-after-sign on all four signing paths (§3.2), including the new
  MuSig2 partial-signature self-check.
- Rename-with-alias sweep for the three `bytes` accessors plus the
  misleading recoverable-signature `normalize` (§3.3), and the
  initializer/accessor trim across the upstream-cache surfaces — both
  x-only types plus `MuSig.PublicKey` (§3.4).
- Follow-on audit remedies: `SharedSecret` redaction plus a redaction
  contract over every secret-bearing type (§3.8), BIP-327 MuSig
  conformance — ordered aggregation, an explicit canonical sort helper,
  exact-32-byte messages, and a parameter-honest partial-signature
  verifier (§3.9), and a managed owner for `secp256k1_context` (§3.10).
- Four continuous-integration assurance lanes and one contributor note
  (three sanitizers plus generation liveness; §3.5).
- Documentation recipes for the fixed-32-byte signing flow and the
  key-agreement-plus-key-derivation flow (§3.6), including the NIP-44 shape
  verified against the official spec.
- Versioning artifacts: pin-advice change, changelog roll-up, single tag.

**Out of scope (with owners):**

- *Upstream v0.7.1 → v0.8.0 pin bump, bundled with vendoring upstream's
  exhaustive and constant-time test suites* — deliberate deferral; it
  re-validates the vendored C tree and belongs with release tooling, not
  this API wave. Owner: a future spec; recorded in
  `Development/Roadmap/backlog.md`.
- *Code-level HMAC / HKDF / SHA-512 / HMAC-DRBG* — already planned as
  **Phase 5 (SHA-2 tower)** in `Development/Roadmap/phase-5-sha2-tower.md`,
  which will expose the C `secp256k1_hmac_sha256` core. This wave ships the
  *documentation recipe only*, delegating to CryptoKit/swift-crypto `HKDF`,
  so the library grows no hash-function namespace that Phase 5 would later
  have to reconcile. Owner: the Phase 5 spec when scheduled.
- *Custom nonce-function (`noncefp`) exposure* — Roadmap phase 6 (adaptor
  signatures) needs the hook by design; exposing it early without its
  consumer invites speculative API. Owner: Phase 6.
- *Ellswift trait wrap-or-drop* — decision deferred to the v0.8.0 bump,
  whose changelog changes `ellswift_xdh` secret-key validation behavior.
- *Performance work on per-signature keypair rebuilding* — measure-first
  via the existing `Projects/` benchmarks; only if the verify-after-sign
  benchmarks show a real regression does a caching task enter scope.
- *Target A's out-of-box test failure* — the other codebase audited;
  informational to this repo only. Owner: block/buzz.

## 3. Design

### 3.1 Schnorr signing and verification surface redesign

One public entry point today carries four failure modes the audit measured:
a Boolean `strict:` flag defaulting to *off* (silently permitting any message
length), a required `auxiliaryRand: UnsafeMutableRawPointer?` (a raw pointer
whose "point to 32 bytes" contract is invisible to the compiler, and whose
`nil` silently requests deterministic, zero-randomness nonces), an inout
message array (mutability demanded for a buffer never mutated), and an
internal copy of caller randomness that is freed un-zeroed. Three of these
four belong to the raw-message function (`signature(message:auxiliaryRand:
strict:)`); the un-zeroed copy lives in a different public method (the
digest-with-randomness overload). The wave replaces the first function and
retypes the second — both changes stated, numbered, and migration-noted,
under the pre-1.0 policy:

| Call | Behavior |
|---|---|
| `signature(for: digest)` | Unchanged API shape; fresh randomness drawn into zeroizing storage |
| `signature(for: digest, auxiliaryRand: some ContiguousBytes)` | Retyped from `[UInt8]` — same name, same length check, caller's storage borrowed for the C call instead of copied, so the un-zeroed array copy of the audit finding dies. Existing `[UInt8]` call sites compile unchanged (array conforms); binary consumers relink, which the breaking tag permits |
| `signature(message: some ContiguousBytes)` | Exactly 32 bytes or throws `incorrectParameterSize`; fresh randomness |
| `signature(message: some ContiguousBytes, auxiliaryRand: some ContiguousBytes)` | Auxiliary randomness must be exactly 32 bytes; passing a 32-byte zero array reproduces the all-zero-aux BIP-340 vector (index 0) |
| `signature(customMessage:auxiliaryRand:…)` | Any message length (backs upstream's `secp256k1_schnorrsig_sign_custom`) |

This is a **five-method** surface: every pre-redesign public signing method
has a stated fate in this table (the outgoing `strict:`-flagged method's
intents split across the 32-byte and custom rows), and every removal is a
named, migration-noted break.

`nil` is no longer expressible: the all-zero deterministic choice is made by
passing a zeroed byte container, exactly as the vendored header documents
("A NULL argument is treated the same as an all-zero one",
`include/secp256k1_schnorrsig.h`). `ContiguousBytes` — not `InlineArray`
(requires macOS 26) and not `Span` (back-deployment through a compatibility
library that Xcode app bundles do not guarantee) — matches the deployment
floor. Verification mirrors the shape for the raw-bytes overload:
`isValid(_:for:)` takes non-mutating byte containers. The digest overload
`isValidSignature(_:for:)` keeps its `Digest`-typed signature — it is the
`DigestValidator` protocol requirement (conformance at
`Schnorr+Signature.swift:202`; the requirement itself at `EdDSA.swift:39`), so it
changes internally only, stopping the inout array construction. The public
multi-party verifier `P256K.MuSig.XonlyKey.isValid(_:for:)`, which takes
`inout [UInt8]` today (`MuSig+Signing.swift:268`), takes the same
non-mutating byte input in this wave.

The before/after pocket sketch at signature grain (the first application of
`Development/README.md` → "Design diagrams"):

```mermaid
classDiagram
    class `Schnorr.PrivateKey — before` {
        signature(for digest: any Digest) throws
        signature(for digest: any Digest, auxiliaryRand: [UInt8]) throws
        signature(message: inout [UInt8], auxiliaryRand: UnsafeMutableRawPointer?, strict: Bool) throws
    }
    class `Schnorr.PrivateKey — after` {
        signature(for digest: any Digest) throws
        signature(for digest: any Digest, auxiliaryRand: some ContiguousBytes) throws
        signature(message: some ContiguousBytes) throws
        signature(message: some ContiguousBytes, auxiliaryRand: some ContiguousBytes) throws
        signature(customMessage: some ContiguousBytes, auxiliaryRand: some ContiguousBytes) throws
    }
    class `Schnorr.XonlyKey — before` {
        isValidSignature(_ sig: SchnorrSignature, for digest: any Digest) Bool
        isValid(_ sig: SchnorrSignature, for message: inout [UInt8]) Bool
    }
    class `Schnorr.XonlyKey — after` {
        isValidSignature(_ sig: SchnorrSignature, for digest: any Digest) Bool
        isValid(_ sig: SchnorrSignature, for message: some ContiguousBytes) Bool
    }
```

Because this change rewires how secret material (the auxiliary randomness)
is handled across the package's trust boundary, the security-trigger rule in
`Development/README.md` → "Design diagrams" requires a data-flow diagram,
bounded to the delta — what crosses the Swift↔C boundary, by which mechanism
(copy vs. borrow), and whether any residue gets wiped:

```mermaid
flowchart LR
    subgraph caller["Caller memory — no wiping by default"]
        aux["aux randomness array<br/>caller-owned, 32 bytes"]
    end
    subgraph wrapper["P256K wrapper — zeroizing storage available"]
        before["Before: aux copied into a plain array freed unwiped"]
        after["After: caller storage borrowed for the call — no copy exists"]
        fresh["Default path: fresh randomness in zeroizing storage"]
    end
    subgraph clib["libsecp256k1 — opaque keypair + BIP-340 nonce derivation"]
        sign["secp256k1_schnorrsig_sign_custom"]
    end
    aux -->|"copied bytes — residue unwiped"| before
    aux -->|"borrowed pointer — reads only"| after
    fresh -->|"borrowed pointer — zeroed on release"| sign
    before -->|"array as aux_rand32 — residue stays unwiped in freed heap"| sign
    after -->|"borrowed pointer as aux_rand32"| sign
```

Protocol/data-type labels per SDL practice: every arrow into the C side
names the datum (the 32-byte auxiliary input) and the mechanism (copy vs.
borrowed pointer); the two `before` edges are exactly the wave's defect —
the only crossing that leaves unwiped secret-related residue — and they are
the paths this redesign deletes.

What the sketch makes visible that prose alone hid during the audit: every
pre-wave method survives under a name (nothing vanishes silently), while
*one* parameter bundle — `UnsafeMutableRawPointer?` plus a `Bool` called
`strict` —
carried every failure mode (any-length silence, invisible 32-byte contract,
deterministic-by-nil nonces, and a caller-randomness copy). After the
redesign, each intent is a separately named method and every byte input has
its length checked in the type system or at the boundary.

### 3.2 Verify-after-sign, unconditional

Every signature the library produces re-verifies before it escapes.
Precedent and its citations: BIP-340 makes it part of the signing algorithm
itself (footnote 14 on the current master text — *"Verifying the signature
before leaving the signer prevents random or attacker provoked computation
errors"*, with the omission carve-out only for prohibitive cost); upstream
libsecp256k1's signing function documents that it deliberately omits the step
and instructs callers to perform it; Bitcoin Core added it to all three of
its signing paths (PR #22934) and the Ledger hardware-wallet app does the
same. BIP-327's reference MuSig2 implementation ends its `sign()` with the
equivalent `assert partial_sig_verify_internal(...)`. A failure means memory
corruption or a library defect, so the channel is `P256K.invariantFailure`
everywhere, including MuSig2 — every boundary blob has already passed the
wrapper's magic-and-size validation before load, which keeps the state
contractually impossible rather than peer-reachable. The MuSig2 self-verify
closes its last provenance gap before entering the proof: because
`partialSignature(...)`'s `pubnonce` parameter is documented "not
consulted" in the wrapper's own doc comment — upstream's
`secp256k1_musig_partial_sign` takes no pubnonce argument at all, nonce
generation having bound it inside the secnonce — `SecureNonce` retains
the companion public nonce from its `Nonce.generate` pair, and
mismatched caller-supplied pubnonces
throw `underlyingCryptoError` before any C call — the self-verify then
proves against material whose provenance is established, never against a
caller-input that could otherwise reach the crash channel (BIP-327's
reference `Sign()` recomputes the public nonce from the secret-nonce
scalars inside the function; carrying the companion is the equivalent the
opaque-struct rule permits here). ECDSA verifies the parsed signature
struct directly (no compact round-trip). The benchmark CI workflow runs on
these PRs to quantify the cost of one extra verification per signature.

### 3.3 Renames with deprecation aliases

Three public accessors named `bytes` accrue on key types
(`ECDSA+XonlyKey.swift:48`, `Schnorr+XonlyKey.swift:50`, `MuSig.swift:243`),
all returning `[UInt8]`. The library-wide convention — eleven public
`var dataRepresentation: Data` declarations (reproducible:
`grep -rh 'public var dataRepresentation' Sources/P256K --include='*.swift' | wc -l`) — is
`dataRepresentation: Data`. All three gain a `Data`-returning
`dataRepresentation` in one change; the old names stay public-deprecated
with `@available(*, deprecated, renamed:)`, forwarding with the old
`[UInt8]` shape until 1.0, matching the mechanism already on `main` for
`Utility.swift`'s `bytes → byteArray` (same-type forwarder) and
swift-crypto's own keep-deprecated-then-remove-at-major practice
(its 4.0 major removed setter members deprecated years earlier).
(swift-crypto's own accessor family name is `rawRepresentation`;
self-consistency with the existing convention wins over cross-package
matching.)

A fourth rename rides the same alias machinery (follow-on audit B-5):
`Signature.Recoverable`'s `var normalize` is a format conversion — it calls
`secp256k1_ecdsa_recoverable_signature_convert`, which decodes the
recoverable form and never touches the S scalar — so the name promises
low-S normalization it doesn't perform, and its own doc comment already
warns the output may fail `secp256k1_ecdsa_verify`'s low-S rule. It becomes
`signature`, matching upstream's `convert` naming and rust-secp256k1's
`to_standard`; `normalize` stays public-deprecated with
`@available(*, deprecated, renamed:)`. A real low-S normalization would be
`secp256k1_ecdsa_signature_normalize` — deliberately not added here: the
misleading name is the defect, and a new API deserves its own spec.

### 3.4 Public-initializer trim for the upstream-cache surfaces

Three public initializers hand callers the opaque
`secp256k1_musig_keyagg_cache` blob as `[UInt8]` —
`Schnorr.XonlyKey.init(dataRepresentation:keyParity:cache:)` (the
audit's finding), `MuSig.XonlyKey.init(dataRepresentation:keyParity:
cache:)` (both also exposing `keyParity: Int32`), and
`MuSig.PublicKey.init(dataRepresentation:format:cache:)` — the only
site where the blob is *required* rather than defaulted — with a public
`cache` accessor on each x-only type to supply it. Upstream's contract
settles the remedy: `include/secp256k1_musig.h` gives the opaque
`secp256k1_musig_keyagg_cache` "No serialization and parsing functions
(yet)" and warns it is "not guaranteed to be portable between different
platforms or versions", so a public byte parameter is a wrapper-invented
serialization upstream deliberately withholds. The reference bindings
agree — `rust-secp256k1`'s `musig::KeyAggCache` has private fields and a
single re-aggregation constructor, `btclib-secp256k1` wraps it as a
declined no-serialization handle, and Bitcoin Core's merged MuSig2 wallet
keeps all signing session state in memory, re-deriving from the
participant pubkeys on restart (citations in `research.md` §B). So the
trim reaches all five sites: the public initializers take the key bytes,
parity stays an explicitly labeled parameter where the type truly needs
it, and the cache-taking initializers and public `cache` accessors move
internal. A reconstructed aggregate is then verification-only — resuming
a signing session means re-running `MuSig.aggregate(_:)` on the
participant pubkeys, the deterministic, version-safe path upstream
designed. `MuSig.PublicKey.init(xonlyKey:)` stays public — it reads the
now-internal `cache` accessor in-module. The ECDSA `Signing.XonlyKey`
(`init(dataRepresentation:keyParity:)`) needs nothing: it has no cache
to leak. Hard break on all three initializers, flagged in the migration
note — consumers persisting cache bytes keep the member pubkeys and
re-aggregate instead.

The pocket sketch for the removed surfaces (signature grain, shared
verbatim with the migration note — `internal` marks what moves out of
public reach):

```mermaid
classDiagram
    class `XonlyKey types — before` {
        init(dataRepresentation: D, keyParity: Int32 = 0, cache: [UInt8] = []) throws
        var cache: Data
    }
    class `XonlyKey types — after` {
        init(dataRepresentation: D, keyParity: Int32 = 0) throws
        internal var cache: Data
    }
    class `MuSig.PublicKey — before` {
        init(dataRepresentation: D, format: Format, cache: [UInt8]) throws
    }
    class `MuSig.PublicKey — after` {
        init(dataRepresentation: D, format: Format) throws
    }
```

### 3.5 Continuous-integration assurance legs

The lane topology (`Development/README.md` → "Design diagrams," deployment
row — the first instance of a CI change carrying its own figure):

```mermaid
flowchart LR
    subgraph linux["Linux container jobs — swift:6.4.1 image, SYS_PTRACE"]
        asan["ASan: swift test --sanitize=address — merge-blocking"]
        ubsan["UBSan: swift test --sanitize=undefined — merge-blocking"]
    end
    subgraph mac["macOS runner"]
        regen["Generation liveness: tuist generate fresh + xcodebuild test — merge-blocking"]
        tsan["TSan: swift test --sanitize=thread — advisory"]
        charness["C harness: xcodebuild -enableThreadSanitizer + run libsecp256k1Tests (count 2) — advisory"]
    end
    pr["Pull request"] --> linux & mac
```

Four additive lanes — ASan and UBSan (Linux, merge-blocking), thread
sanitizer including the sanitized C-harness step (macOS, advisory together),
and generation liveness (macOS-only by tool, merge-blocking) — following
`.github/AGENTS.md` conventions (`permissions:
{}` on each new job, `env:` blocks, no new third-party actions, verdict
steps gated `!cancelled()`):

1. **Sanitizer lane** — `swift test --sanitize=address` and
   `swift test --sanitize=undefined`, each its own merge-blocking job on
   `ubuntu-latest` inside `container: swift:6.4.1` — the image the
   Dockerfile already pins — with `options: --cap-add SYS_PTRACE`.
   Container jobs rather than the existing `docker build` lane because
   LeakSanitizer, bundled inside ASan on Linux, attaches to the process
   through `ptrace`, which Docker denies by default and a `docker build`
   step cannot be granted at all; `container.options` accepts any
   `docker create` flag, and checkout plus the repo's `env:` and
   `permissions: {}` conventions work natively inside it — no new
   third-party actions. Each job repeats the existing lane's `--traits
   ecdh,musig,recovery,schnorrsig,uint256` for parity — `--traits`
   *replaces* the default trait set, so a flagless run would silently
   drop the `uint256` sources and tests — and UBSan runs with
   `UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1` so reports fail
   the job rather than warn. `swift test --sanitize=thread` on the
   macOS runner in advisory mode (reports land in the job summary;
   promotion to blocking after a stability window), with a
   `TSAN_OPTIONS` suppression file after Bitcoin Core's documented
   pattern and `halt_on_error=1`. Each sanitizer is a separate job
   with its own scratch path — sanitizer-instrumented object files
   from different sanitizers must not share a build directory.
   Platform placement is evidence-driven: 2026 Swift-forums operational
   reports (Apple's Jon Shier; Vapor's Tim Condon) put thread-sanitizer
   false-positive rates near 50% on Linux versus reliable on macOS for
   current toolchains. Two instrumentations stay distinct here: sanitizer
   flags propagate to C sources under SwiftPM, so *every* sanitized
   `swift test` run already instruments the vendored `libsecp256k1` target —
   the shipped C bytes execute under the sanitizer whenever the Swift suite
   calls into them. What that never runs is upstream's hand-written test
   harness (`tests.c`, vendored under `Projects/Sources/libsecp256k1Tests`
   as a Tuist-only macOS command-line tool with no SwiftPM or Linux path).
   The macOS thread-sanitizer lane therefore adds one concrete step — build
   `libsecp256k1Tests` with `xcodebuild -enableThreadSanitizer YES` and
   execute the binary with `TSAN_OPTIONS=halt_on_error=1` at a low iteration
   count (the flow Apple documents for sanitized command-line targets in
   WWDC 2016 session 412) — so upstream's own harness runs instrumented
   without inventing
   Linux build machinery for a documentedly macOS-only target.
2. **Generation liveness** — on pull requests, regenerate the Tuist-managed
   Xcode project fresh and run one vector test scheme through `xcodebuild
   test`. Release CI already *regenerates the project*
   (`xcframework-release.yml:25`), but only at release time and without a
   PR-time test of the regeneration path; this lane catches a broken
   regeneration on the change that causes it. macOS-only by tool (Tuist and
   `xcodebuild`). A companion note in `Projects/AGENTS.md` tells contributors
   the generated project is git-ignored and can go stale locally — delete
   and re-run the documented generate command.

### 3.6 Documentation recipes (no protocol-named API)

Two DocC catalog articles, each mirrored by a test that compiles its exact
code. Both recipes use only building blocks this library plus
CryptoKit/swift-crypto already provide — no protocol-specific API ships.

- **Fixed-32-byte signing flow** (the sequence Nostr event signing needs):
  hash to 32 bytes, sign via the 32-byte-checked method from §3.1, verify
  against the x-only key.
- **Key agreement plus key derivation**: the shared-secret type yields its
  bytes through its documented extraction accessor; the recipe slices the
  compressed-point prefix byte to obtain the bare 32-byte shared x
  coordinate and feeds it (unhashed — verified against `nips/44.md`) to
  `HKDF<SHA256>.deriveKey(...)` from CryptoKit or swift-crypto with the
  caller's chosen salt (NIP-44 v2 uses the UTF-8 bytes of the string
  `nip44-v2`). The article states plainly that the recipe is an example
  composition, not a Nostr implementation.

### 3.8 Follow-on audit: secret-output redaction

`SharedSecret`'s `CustomStringConvertible` conformance interpolates the
complete ECDH shared secret as hex (`DH.swift:126–128`) — any `print`,
interpolation, or log call discloses the agreed key. The convention the
finding cites is uniform across ecosystems: Rust's `secrecy` crate redacts
`Debug` output and forces byte exposure through an explicit accessor,
rust-secp256k1's own discussion (issue #226) settled on redacted secret
output, and CryptoKit's `SharedSecret` exposes no raw bytes through its
description (digests may print hex because digests are public — secrets are
not). The fix prints a type-and-length form (`"SharedSecret: <32 bytes>"`)
— never the bytes. The rest of the secret-bearing types already pass: each
`PrivateKey` and `SecureNonce` holds its material inside `SecureBytes`,
whose class-backed storage renders as a type name under
`String(describing:)` rather than child bytes. So the task's second half is
a contract, not a sweep: one test asserting `String(describing:)`,
`String(reflecting:)`, and `\(…)` on every *copyable* secret-bearing type
emit none of the value's secret bytes — a guardrail against a future
raw-byte stored property silently reopening the leak. The `~Copyable`
types (`SecureNonce`, `SessionSecretRand`) need no coverage: the type
system rejects them as arguments to every render channel, so the leak is
impossible at compile time rather than merely absent at runtime.

The secret-material path the rule protects (security-triggered change, so
it carries its own sketch):

```mermaid
flowchart LR
    subgraph channels["Render channels — all reach description"]
        pr["print / String(describing:)"]
        interp["\\(sharedSecret)"]
        log["log interpolation"]
    end
    subgraph store["SharedSecret — SecureBytes-backed"]
        desc["description → SharedSecret: <32 bytes><br/>(was: full hex)"]
        bytes["explicit byte accessors<br/>(withUnsafeBytes — opt-in, unchanged)"]
    end
    pr & interp & log --> desc
    desc -.->|"never reads"| bytes
```

### 3.9 Follow-on audit: BIP-327 MuSig conformance

Three findings share one theme — the wrapper's MuSig layer diverges from
BIP-327 where the spec and upstream are unambiguous:

**Ordered aggregation (B-2).** `MuSig.aggregate(_:)` runs
`secp256k1_ec_pubkey_sort` before `secp256k1_musig_pubkey_agg`, so key order
has no effect and the official `key_agg_vectors.json` cannot distinguish the
wrapper from a conforming implementation. Every reference disagrees with the
implicit sort: BIP-327's `KeyAgg` preserves caller order (sorting is an
application-layer choice — BIP-390 sorts at the descriptor layer, not the
primitive), upstream's `examples/musig.c` sorts only when the application
wants canonical order, `doc/musig.md` calls sorting optional and
caller-controlled, rust-secp256k1's `KeyAggCache::new` keeps supplied order
with `sort_pubkeys` as a separate helper, and Bitcoin Core aggregates keys
in their current order. The primitive preserves order; the helper
`sortedPublicKeys(_:)` wraps `secp256k1_ec_pubkey_sort` as an explicit,
documented BIP-327 canonical sort — lexicographic on the compressed
serialization of each parsed point: `secp256k1_ec_pubkey_sort` compares
canonicalized 33-byte serializations internally, so keys sort identically
whether they arrived `.compressed` or `.uncompressed`, and each returned
key keeps its own stored format (the migration note's "exact pre-wave
behavior" promise then holds for every caller). No `Comparable` lands on
`Schnorr.PublicKey`: canonical order is a multisig convention better
named where it's meaningful than promised type-wide — no CryptoKit key
type carries `Comparable`, upstream ships ordering as functions
(`ec_pubkey_cmp`, `ec_pubkey_sort`) rather than as a property of the key,
and rust-secp256k1 documents `sort_pubkeys` — not its `Ord` impl — as
the canonical way to sort for MuSig2. This is also the contract BOLT-3's
funding output, BIP-383's `sortedmulti()`, and BIP-390's `musig()` all
demand: lexicographic on the compressed serialization.

**Exact-32-byte signing inputs, natural-length verification (B-3).**
BIP-327 defines the message as "a byte array" and permits variable-length
messages as an optional feature — its official `sign_verify_vectors.json`
carries 32-byte, empty, and 38-byte messages — while libsecp256k1's MuSig
API takes a fixed `msg32` at `nonce_gen`, `nonce_gen_counter`, and
`nonce_process` (`partial_sign` takes no message; the session binds it at
`nonce_process`, which is where `partialSignature`'s digest lands).
Every wrapper path routes the input through `Digest.msg32Bytes` — the
SEC1 §4.1.3 reduction that left-pads short inputs and truncates long
ones — so a 38-byte message silently signs its first 32 bytes and a
16-byte input silently pads. The split fix matches each side's actual
contract: the *signing* inputs (both `Nonce.generate` overloads'
`msg32:` and `partialSignature(for digest:…)`) gate at exactly 32 bytes
or `incorrectParameterSize`, documented "unsupported by libsecp256k1"
rather than "invalid" — upstream cannot produce that signature, and
reducing would silently commit to the wrong message. The *verify* side
does the opposite: `MuSig.XonlyKey.isValidSignature(_:for digest:)`
stays `-> Bool`, drops the reduction, and verifies at natural length
through `secp256k1_schnorrsig_verify`'s arbitrary-length `(msg, msglen)`
— the aggregate signature is a plain BIP-340 signature a
variable-length-capable implementation could legitimately produce, and
rejecting the input (throw or `false`) would reject a valid signature.
This matches the in-package sibling `Schnorr.XonlyKey.isValidSignature`
("verified… at natural length… no msg32 reduction",
`Schnorr+Signature.swift:205-207`), upstream's 0/1 verifiers,
CryptoKit's Bool-only `isValidSignature`, and btcd's collapse of an
internal length error to `false`. `msg32Bytes` stays: ECDSA's
`signature(for:)` reduction is spec-correct SEC1 digest-to-integer
behavior (Go `hashToInt`, OpenSSL `bits2int`, CryptoKit).

**Honest verifier (B-4).** `MuSig.PublicKey.isValidSignature(_:publicKey:
nonce:for digest:)` documents `digest` as "not consulted" — the signed
message is bound inside the session at `secp256k1_musig_nonce_process`
time. The parameter and the `D: Digest` generic leave the signature; call
sites break at compile time with an obvious fix. (The alternative —
threading the message into `PartialSignature` so the parameter could be
checked — was rejected: BIP-327 binds the message in the session, and
upstream provides no accessor to compare against.)

```mermaid
flowchart LR
    subgraph before["Before — divergence hidden"]
        keys["pubkeys in caller order"] --> sort["internal secp256k1_ec_pubkey_sort"] --> agg["musig_pubkey_agg"]
        msg["message — any length"] --> red["msg32Bytes reduce/pad"] --> proc["nonce_process"]
        dig["verify digest — any length"] --> red
    end
    subgraph after["After — BIP-327 conformant"]
        keys2["pubkeys in caller order"] --> agg2["musig_pubkey_agg<br/>order preserved"]
        keys2 -.->|"opt-in"| helper["sortedPublicKeys(_:)<br/>canonical BIP-327 order"] --> agg2
        msg2["message — exactly 32 bytes<br/>else throw (upstream limit)"] --> proc2["nonce_process"]
        dig2["verify digest — natural length<br/>no gate, no reduction"] --> ver["schnorrsig_verify (msg, msglen)"]
    end
```

### 3.10 Follow-on audit: managed context ownership

`Context.create()` returns a raw `OpaquePointer` and documents the destroy
contract in prose — nothing enforces it. What actually leaks per abandoned
context is a few hundred bytes — the vendored `secp256k1_context_struct`
(`src/secp256k1.c:61-66`) holds an ecmult-generator blinding state, two
callbacks, and a flag; the precomputed tables are static data in this
version — so the finding is a lifecycle-and-hygiene defect: small per leak,
unbounded in count, and an unmanaged contract nothing enforces. The precedent for the fix is uniform: rust-secp256k1's
`Secp256k1` owns the pointer and destroys it in `Drop` (raw access only via
an explicit `ctx()`); swift-nio-ssl wraps its expensive `SSL_CTX *` in a
thread-safe `final class NIOSSLContext`; and swift-crypto itself uses the
`final class BackingStorage` + `deinit` idiom behind value-type facades.
Upstream's contract supplies the lifecycle verbatim — randomize once at
creation and "you need no locking for the other calls" (the alternative is
a read-write lock), `destroy`/`randomize` need exclusive access, and
const-pointer calls are thread-safe throughout — so the managed type
randomizes once in `init` and takes `Sendable` from the const-only
post-init surface. `~Copyable` was rejected: noncopyable types suit
one-shot resources like `SecureNonce`; a context is deliberately long-lived
and shareable — forcing `borrowing` across the API would punish the common
case for a resource upstream designed for shared const access.

```mermaid
classDiagram
    class `P256K.Context — facade` {
        +static rawRepresentation: OpaquePointer (shared, process-lifetime)
        +create() OpaquePointer — deprecated
        +ManagedContext
    }
    class `ManagedContext — value facade` {
        +init() — create + callbacks + randomize (32B)
        +withContext / raw accessor — explicit interop only
    }
    class `Storage — final class` {
        +deinit → secp256k1_context_destroy
        +Sendable via const-only post-init calls
    }
    class `secp256k1_context — upstream` {
        +randomize once at init — exclusive
        +destroy at deinit — exclusive
        +all other calls — const, thread-safe
    }
    `ManagedContext — value facade` --> `Storage — final class` : owns
    `Storage — final class` --> `secp256k1_context — upstream` : OpaquePointer
```

### 3.11 Versioning and migration artifacts

One tag — 0.25.0 — cut after the last breaking change lands; no tag between
breaking changes. The first change-set of the wave updates consumer advice:
`README.md:39`'s `exact:` example becomes `.upToNextMinor(from: "0.24.0")`
with a sentence explaining that SwiftPM's `from:` spans all of 0.x up to
1.0.0 and a note that the example moves to `0.25.0` when the tag is cut —
a published example never names an untagged version, so the tag-time bump —
a sorted sweep over every published current-version string — rides in the
release task, not here. The DocC `GettingStarted` guide — the
published install walkthrough — gets the same example and rationale;
`MigratingToP256K` keeps its `exact:` pin, a deliberate deterministic
one-time-bump choice that already names `.upToNextMinor` as the
alternative. `Development/constitution.md`'s
Versioning & Stability section trades "Users advised to pin exact
versions" for the same advice (Apple's pre-1.0 wording, used on
swift-configuration, is the template). The changelog's existing breaking
`[Unreleased]` entries open the 0.25.0 section, followed by this wave's.
Every breaking change-set extends the migration note in the same edit.
Pre-1.0, the minor version *is* the stability boundary — the wave's
breaking work batches into 0.25.0 rather than waiting for a major.

## 4. Implementation steps

Ordered reviewable slices with checkpoints are in
[tasks.md](./tasks.md). Headline order: versioning artifacts first; the
standalone `SharedSecret` redaction; the Schnorr redesign; BIP-327 MuSig
conformance (ordered aggregation, exact-32-byte messages, honest
partial-signature verifier); verify-after-sign on its four paths; rename
sweep; initializer trim; managed context; tag 0.25.0; then documentation
recipes and CI legs, which interleave freely.

## 5. Verification

- [ ] `swift test` green; `swift package swiftlint` and formatting hooks clean.
- [ ] All official BIP-340 vectors (19 rows) pass through the redesigned API,
      each signing row driven with its declared `auxRand` — index 0 supplies
      the all-zero case; the remaining rows are verify-only.
- [ ] New tests: 100-byte unhashed input throws via the 32-byte method;
      `customMessage:` signs and round-trips; fault-injection tests fire
      `invariantFailure` on corrupted outputs for all four signing paths —
      plus the produced aggregate MuSig signature.
- [ ] Official BIP-327 `key_agg_vectors.json` passes through the ordered
      `aggregate(_:)`; reordering the input keys changes the aggregate key;
      `aggregate(sortedPublicKeys(_:))` reproduces the pre-wave canonical
      output.
- [ ] A 38-byte message throws `incorrectParameterSize` on every MuSig
      signing-path input (`Nonce.generate` `msg32:`, `partialSignature`)
      instead of silently truncating; a short input throws rather than
      padding; a digest longer than 32 bytes verifies at natural length
      through `isValidSignature(_:for:)`; T030 restores the full upstream
      `sign_verify_vectors.json` (the repo's copy was trimmed to
      `msg_index`-0 cases with emptied error sections) and drives every
      expressible case on the `NonceGenVectorTests` stated-skip pattern —
      `msg_index`-0 valid cases end to end, empty/38-byte stated-skipped,
      error/fail sections asserted or skipped; a `customMessage:`-signed
      Schnorr signature over >32 bytes verifies true at natural length.
- [ ] `String(describing:)`, `String(reflecting:)`, and interpolation on
      every copyable secret-bearing type (`SharedSecret`, the private-key
      types) emit no secret bytes; the `~Copyable` types are
      compile-time-excluded from render channels.
- [ ] A consumer-held managed context deallocates via `deinit` →
      `secp256k1_context_destroy`; `Sendable` concurrent use; deprecated
      `create()` warns toward the managed type.
- [ ] Deprecated aliases compile existing call sites with warnings.
- [ ] `benchmark-pr.yml` comparisons attached to the verify-after-sign PRs.
- [ ] Sanitizer jobs green on the wave's final state; TSan job summary
      attached as non-blocking evidence.
- [ ] Generation-liveness job regenerates and passes on a pull request
      whose only change is a new source file (the regression class observed
      during the audit).
- [ ] `swift run --package-path Development/Tools plans --check` and
      `vale Development/` clean; DocC builds with the two new articles.
- [ ] A scratch consumer package pinned `from: "0.25.0"` builds; a scratch
      package consuming the pre-wave API fails to compile with clear,
      migration-note-mapped errors at each removed/changed symbol.

## 6. Risks and mitigations

- **`from:`-pinned consumers auto-update into the break.** Mitigation: the
  pin-advice change lives in the wave's first change-set, the tag lands only
  after every breaking change, and the changelog names each removed symbol
  with its replacement.
- **Ordered aggregation changes consumers' existing aggregate keys.** A
  multisig that passed unsorted keys gets a different aggregate — the
  intended BIP-327 semantics. Mitigation: the migration note names
  `aggregate(sortedPublicKeys(_:))` as the exact pre-wave behavior, so
  consumers preserving a deployed aggregate key have a one-line fix.
- **The exact-32 gate rejects callers the silent reduction once served.**
  Those callers were signing truncated or padded messages — arguably a
  latent bug the gate now surfaces; the migration note states the fix is to
  hash to 32 bytes first.
- **Deprecated `create()` remains reachable.** Accepted as a deliberate
  breaking-soft choice: the deprecation warning and migration note point at
  the managed type; removal waits for a major.
- **Verify-after-sign regresses signing latency.** Mitigation: benchmark CI
  runs on the hardening PRs; no published baseline exists, so the wave
  establishes it rather than guessing.
- **TSan advisory job rots.** Mitigation: explicit promotion criteria
  (N consecutive clean weeks) written into the workflow, matching the repo's
  existing advisory-gate convention.
- **The custom-message path drifts into routine use.** Mitigation: the
  method name is deliberately unattractive and its DocC comment states the
  BIP-340 domain-separation requirement.
- **NIP-44 recipe rots against the spec.** Mitigation: the article links
  `nips/44.md` and states the composition is example-grade; the companion
  test asserts only the library's own steps, not the payload format.

## 7. Out of scope (follow-ups)

Tracked as backlog owners per §2: the v0.8.0 pin bump + constant-time and
exhaustive suite vendoring (seed for a future spec); code-level HMAC/HKDF
(Phase 5); `noncefp` exposure (Phase 6); ellswift trait decision;
benchmark-driven keypair caching only if measured.

## 8. Division of labor

Each `tasks.md` entry is one independently-implementable change-set with its
files, acceptance evidence, and dependencies. Slices are sized for a
reviewer: nothing over ~300 authored lines; the spec documents ship as one
coherent set. No task touches `Sources/libsecp256k1/`,
`Sources/P256K/swift-crypto/`, or `vendir.yml`/`vendir.lock.yml` — the
vendored trees are vendir-managed and untouched this wave.
