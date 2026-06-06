# Migrating to P256K from secp256k1.swift

@Metadata {
    @TitleHeading("How-to Guide")
}

Move a Swift project off the original `secp256k1` module — GigaBitcoin's `secp256k1.swift` or a fork such as jb55's or Damus's — onto the maintained ``P256K`` module by repointing the package dependency and renaming imports and type prefixes.

## Overview

``P256K`` is the current module name of `21-DOT-DEV/swift-secp256k1` — the direct successor to GigaBitcoin's `secp256k1.swift`. This guide covers the rename path within that library lineage.

For the GigaBitcoin lineage, migrating to ``P256K`` is a mechanical rename, not a rewrite. The module `secp256k1` became `P256K` in a single breaking change, and the type-safe API carried over unchanged — so you repoint the dependency at the maintained repository, move to a release at or above the rename, and replace `import secp256k1` with `import P256K` (and the `secp256k1.` type prefixes with `P256K.`). Most GigaBitcoin-lineage migrations are a 5–10 minute change; porting from the raw C API — Boilertalk, status-im, or a vendored copy — is a per-call-site rewrite, covered in the final section.

The rename landed in **0.20.0** (April 2025): the primary module was renamed from `secp256k1` to `P256K`, and the C-bindings module from `secp256k1_bindings` to `libsecp256k1`. Releases at or below **0.19.0** vend the old `secp256k1` module; **0.20.0** and later vend `P256K`. The current release is **0.23.2**, and the supported toolchain since 0.22.0 is **Swift 6.1 / Xcode 16.3** or newer.

> Important: This guide covers the GigaBitcoin lineage — `GigaBitcoin/secp256k1.swift` (now `21-DOT-DEV/swift-secp256k1`) and its forks. If your `import secp256k1` instead resolves to Boilertalk or status-im's `secp256k1.swift` — both of which just package the raw bitcoin-core C API — or to a vendored C copy, the move is a port, not a rename. Identify which one you have before editing anything; the section *Coming from the raw libsecp256k1 C API* covers that case.

### Identify which secp256k1 you depend on

The line `import secp256k1` is ambiguous: it resolves against at least three different packages. Open your `Package.swift` (or `Package.resolved`, or `Podfile`), find the dependency URL, and match it against this map.

| Your dependency | What it is | Module today | How to migrate |
|---|---|---|---|
| `GigaBitcoin/secp256k1.swift` | the original repo, renamed to `21-DOT-DEV/swift-secp256k1` (old URL redirects) | `import secp256k1` (≤ 0.19.0) | **Rename** — this guide |
| `jb55/secp256k1.swift` | a fork of that repo, frozen around mid-2022 | `import secp256k1` | **Rename** (mind the version gap) |
| `damus-io/secp256k1.swift` | a fork of jb55's fork (the Damus app's line) | `import secp256k1` | **Rename** (mind the version gap) |
| any other fork of the repo | same upstream, same API | `import secp256k1` | **Rename** — this guide |
| `Boilertalk/secp256k1.swift`, `status-im/secp256k1.swift`, or a vendored bitcoin-core C copy (CocoaPod / module map) | the raw libsecp256k1 **C API** — Boilertalk and status-im just package it for SwiftPM behind a re-export shim | `import secp256k1` → C functions | **Port** — see *Coming from the raw libsecp256k1 C API* below |
| `21-DOT-DEV/swift-secp256k1` at ≥ 0.20.0 | this package, already current | `import P256K` | already migrated |

Many public Swift manifests still reference the pre-rename `GigaBitcoin/secp256k1.swift` URL. The redirect keeps them building, but new resolves and contributors still see the old name — repointing the URL in Step 1 removes that ambiguity for good.

### Before you begin

Confirm from the map above that you are on the rename path (the GigaBitcoin lineage). Then commit or stash your working tree first: Steps 2 and 3 are a find-and-replace across your codebase, and a clean starting diff makes the rename reviewable and trivially reversible.

If you are on an older toolchain than Swift 6.1 / Xcode 16.3, you can pin a 0.20.x–0.21.x release during the move (those have `P256K` but predate the Swift 6.1 floor), but migrating straight to the current **0.23.2** is recommended — a frozen fork misses every libsecp256k1 update and API addition made upstream since.

``P256K`` builds on Linux as well as Apple platforms, so server-side Swift migrations follow the same steps — with one exception: the `UInt256` type is Apple-only.

### Step 1 — Repoint the package dependency

Change the dependency URL to `21-DOT-DEV/swift-secp256k1` and pin a version at or above 0.20.0.

```swift
// Package.swift — before (a GigaBitcoin-lineage URL or a fork)
.package(url: "https://github.com/GigaBitcoin/secp256k1.swift", from: "0.18.0"),

// after
.package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.23.2"),
```

The product and package names changed too, so update the target dependency:

```swift
// before
.product(name: "secp256k1", package: "secp256k1.swift")

// after
.product(name: "P256K", package: "swift-secp256k1")
```

The pin uses `exact:` because the package is pre-1.0: under [SemVer §4][semver-4], releases below `1.0.0` may break the public API, so `exact:` keeps upgrades deliberate. (`.upToNextMinor(from: "0.23.2")` is a reasonable alternative if you want patch-level fixes within a minor release; this guide uses `exact:` so the migration is a single deterministic version bump.) In Xcode, the equivalent flow is **File → Add Package Dependencies…**, pasting `https://github.com/21-DOT-DEV/swift-secp256k1`.

GitHub redirects the old `GigaBitcoin` URL, so a stale URL may still resolve — but pin the canonical `21-DOT-DEV` URL so your manifest names the repository that actually receives updates. If you are coming from a fork (jb55, Damus, or another), replace the fork URL entirely: the fork is frozen, and this step rejoins the maintained line.

Most migrations need no package traits — the default set (`ecdh`, `musig`, `recovery`, `schnorrsig`) covers the core ``P256K`` module. The optional modules are off by default under [SE-0450 package traits][se-0450]: if your old code used the ZKP modules (`zkp` / `zkp_bindings`), ElligatorSwift (`ellswift`), or `UInt256` (`uint256`), enable the matching trait in the dependency.

```swift
.package(
    url: "https://github.com/21-DOT-DEV/swift-secp256k1",
    exact: "0.23.2",
    traits: ["zkp"]   // ZKP bundle; add "ellswift" or "uint256" as needed
),
```

Xcode compiles every optional module regardless of traits, so a missing trait bites only `swift build` (see Troubleshooting). The full trait list is in <doc:GettingStarted>.

### Step 2 — Rename the import and type prefixes

Replace `import secp256k1` with `import P256K`, and the `secp256k1.` type prefix with `P256K.`. The API shape is identical, so call sites change only in name:

```swift
// before
import secp256k1
let key = try secp256k1.Signing.PrivateKey()

// after
import P256K
let key = try P256K.Signing.PrivateKey()
```

Four module names were renamed in 0.20.0; apply whichever your project imports:

| Old module (≤ 0.19.0) | New module (≥ 0.20.0) |
|---|---|
| `secp256k1` | `P256K` |
| `secp256k1_bindings` | `libsecp256k1` |
| `zkp` | `ZKP` (requires the `zkp` trait) |
| `zkp_bindings` | `libsecp256k1_zkp` (requires the `zkp` trait) |

The `ZKP` and `libsecp256k1_zkp` modules also sit behind the `zkp` package trait — if you used them, enable that trait as shown in Step 1.

Make the change as two scoped replacements — `import secp256k1` → `import P256K`, then `secp256k1.` (including the trailing dot) → `P256K.` — using your editor's project-wide find with whole-word matching, and review the resulting diff. The compiler will flag anything the search misses.

> Warning: Do not blanket-replace the bare token `secp256k1`. The error type is still named ``secp256k1Error`` after the rename, and the curve name legitimately appears in comments, string literals, and BIP references. Replacing every `secp256k1` would rename ``secp256k1Error`` to a type that does not exist. Scope the replacement to `import secp256k1` and the `secp256k1.` prefix only.

### Step 3 — Resolve, trust the plugin, and build

Refresh the resolved dependency graph, then build. From the command line, `swift package resolve` (or `swift package update`) re-pins against the new URL; in Xcode, the package resolves on the next build. If SPM clings to the old repository, see Troubleshooting.

> Note: New since the GigaBitcoin era, ``P256K`` compiles its C sources through a `SharedSourcesPlugin` build-tool plugin. If your previous setup predates it, the first Xcode build surfaces a one-time **Trust & Enable Plugin** prompt, and headless CI running `xcodebuild` needs `-skipPackagePluginValidation`. Building with `swift build` requires no trust step. See <doc:GettingStarted> for the full plugin-trust and CI details.

### Verify the migration

The smallest end-to-end check is an ECDSA sign-and-verify round-trip against ``P256K/Signing/PrivateKey``:

```swift
import Foundation
import P256K

let privateKey = try P256K.Signing.PrivateKey()
let message = "migration check".data(using: .utf8)!
let signature = privateKey.signature(for: message)   // non-throwing on Signing.PrivateKey since 0.23.0
print(privateKey.publicKey.isValidSignature(signature, for: message))  // true
```

If it prints `true`, the dependency, the import, and the plugin are wired correctly. Build your remaining targets; the compiler flags any leftover `secp256k1.` references the find-replace missed. For the broader API — ``P256K/Schnorr`` for BIP-340, ``P256K/KeyAgreement`` for ECDH, ``P256K/MuSig`` for BIP-327 — the surface matches what you used before the rename.

### Coming from the raw libsecp256k1 C API

This path is a port, not a rename: you replace raw C calls with the ``P256K`` Swift API rather than renaming an import. The payoff: no per-call context lifecycle, type-safe key and signature values instead of raw byte buffers, `Sendable` key types (since 0.22.0), and one source path that builds on both Apple platforms and Linux.

Boilertalk's `secp256k1.swift` and its status-im fork are not separate Swift libraries — each packages the [bitcoin-core C library][libsecp256k1] for SwiftPM (and CocoaPods) and re-exports it through a one-file shim, so `import secp256k1` hands you the raw `secp256k1_*` C functions directly. Calling a vendored copy of the C library through your own module map is the same situation. There is no mechanical find-replace here, but the rewrite is usually small, because ``P256K`` collapses the C ceremony into a few typed calls — most visibly the per-call context setup, which the shared ``P256K/Context`` removes entirely.

```swift
// Before — raw libsecp256k1 C API (Boilertalk/status-im, or a vendored copy). Error handling elided.
import secp256k1

let ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))!
defer { secp256k1_context_destroy(ctx) }
var seed = [UInt8](repeating: 0, count: 32)   // fill from a CSPRNG
_ = secp256k1_context_randomize(ctx, &seed)

var pubkey = secp256k1_pubkey()
_ = secp256k1_ec_pubkey_create(ctx, &pubkey, privateKeyBytes)

var sig = secp256k1_ecdsa_signature()
_ = secp256k1_ecdsa_sign(ctx, &sig, messageHash, privateKeyBytes, nil, nil)

var der = [UInt8](repeating: 0, count: 72)
var derLen = der.count
_ = secp256k1_ecdsa_signature_serialize_der(ctx, &der, &derLen, &sig)
```

```swift
// After — P256K. The shared Context handles creation and randomization.
import P256K

let privateKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKeyBytes)
let signature = privateKey.signature(for: message)   // SHA-256 applied internally
let der = signature.derRepresentation                // DER-encoded Data
let isValid = privateKey.publicKey.isValidSignature(signature, for: message)
```

Two behavioral shifts to watch when porting: ``P256K`` hashes `Data` arguments with SHA-256 itself before signing (matching CryptoKit), whereas the C `secp256k1_ecdsa_sign` takes a pre-computed 32-byte hash — so pass the *original message*, not the digest your C code built. And ``P256K`` ECDSA signatures are lower-S normalized; <doc:ECDSASigningAndBitcoinTransactions> covers the DER, compact, and low-S details Bitcoin verifiers expect.

The C calls seen most often in Swift code map to P256K as follows:

| Raw C call | P256K equivalent |
|---|---|
| `secp256k1_context_create` / `_randomize` / `_destroy` | nothing to call — the shared ``P256K/Context`` is created and randomized once at startup |
| `secp256k1_ec_pubkey_create` | ``P256K/Signing/PrivateKey`` → `.publicKey` |
| `secp256k1_ecdsa_sign` | `privateKey.signature(for:)` |
| `secp256k1_ecdsa_verify` | `publicKey.isValidSignature(_:for:)` |
| `secp256k1_ec_pubkey_serialize` / `_parse` | ``P256K/Signing/PublicKey`` `dataRepresentation` / `init(dataRepresentation:format:)` |
| `secp256k1_ecdsa_signature_serialize_der` / compact | ``P256K/Signing/ECDSASignature`` `derRepresentation` / `compactRepresentation` |
| `secp256k1_ecdsa_sign_recoverable` / `secp256k1_ecdsa_recover` | ``P256K/Recovery/PrivateKey`` / ``P256K/Recovery/PublicKey`` — see <doc:RecoveringPublicKeys> |
| `secp256k1_ecdh` | `sharedSecretFromKeyAgreement(with:)` on ``P256K/KeyAgreement/PrivateKey`` — see <doc:EllipticCurveDiffieHellman> |
| `secp256k1_ec_pubkey_tweak_add` / `_seckey_tweak_add` (older `_privkey_tweak_add`) | `add(_:)` on ``P256K/Signing/PrivateKey`` / ``P256K/Signing/PublicKey`` — see <doc:WorkingWithKeys> |
| `secp256k1_schnorrsig_sign` / `_verify` | ``P256K/Schnorr`` — see <doc:WorkingWithKeys> |

Repoint your dependency at `21-DOT-DEV/swift-secp256k1` first (Step 1), then rebuild each call site. For the operations past the basics — key formats, tweaks, and BIP-341 Taproot output keys (<doc:WorkingWithKeys>), public-key recovery (<doc:RecoveringPublicKeys>), ECDH (<doc:EllipticCurveDiffieHellman>), and BIP-327 MuSig2 (<doc:MuSig2MultiSignatures>) — follow the cross-links from <doc:GettingStarted>.

#### Staying on CocoaPods

Boilertalk and status-im also ship via CocoaPods, so if that's how you consume them today, you can stay there: `21-DOT-DEV/swift-secp256k1` publishes a pre-built XCFramework to the CocoaPods Trunk (`pod 'swift-secp256k1'`). Swift Package Manager is the primary path and gets features first, and CocoaPods support may be deprecated in a future release — so SPM is the better target for a long-lived migration.

### Troubleshooting

**"No such module 'secp256k1'" after editing imports.** Expected mid-migration — the import is renamed but the dependency still vends the old module, or the graph has not re-resolved. Confirm Step 1 repointed both the URL and the product name, then re-resolve.

**SPM keeps resolving the old URL or fork.** A cached `Package.resolved` can pin the old repository. Remove its `secp256k1.swift` / `swift-secp256k1` entry and re-resolve, or in Xcode choose **File → Packages → Reset Package Caches**.

**Symbols moved or renamed since your fork (version-gap drift).** jb55's fork last received commits in June 2022, and the Damus fork descends from it — so migrating from either crosses every upstream API change made since, not just the rename. The two you are most likely to hit: `rawRepresentation` became `dataRepresentation` on keys (so `PrivateKey(rawRepresentation:)` becomes `PrivateKey(dataRepresentation:)`), and ECDSA signing moved from `privateKey.ecdsa.signature(for:)` to `privateKey.signature(for:)`. Beyond those, MuSig2 (BIP-327) arrived in 0.18.0 and the `Asymmetric` public-key helper in 0.19.0; if a call site still fails to compile after the rename, check the [CHANGELOG][changelog] for the symbol's current shape rather than assuming the rename broke it.

**Two packages both vend `secp256k1`.** If your graph pulls in both Boilertalk's `secp256k1` and a pre-rename GigaBitcoin `secp256k1`, the module names collide. Completing the move to `P256K` resolves the clash, because the maintained module no longer uses the `secp256k1` name.

**Optional modules or types missing under `swift build`.** ZKP features, ElligatorSwift, and `UInt256` are gated behind non-default package traits. Enable the matching trait — `zkp`, `ellswift`, or `uint256` — in your dependency (Step 1). Because Xcode ignores trait conditions and compiles them anyway, this fails only on the command line: a build that works in Xcode but breaks under `swift build` is almost always a missing trait.

**A transitive dependency still pins the old URL.** While you migrate, another dependency (say, a Lightning library) may still depend on the pre-rename `secp256k1` package. The resolver allows both — their package identities and Swift module names differ — but each bundles its own copy of libsecp256k1 exporting the *same* C symbols, which can surface at link time as `duplicate symbol '_secp256k1_ec_pubkey_create'` (and similar). Whether it triggers depends on your linkage and target layout. Resolve it by completing the migration on both sides: move the transitive dependency to `P256K`, or pin a version of it that already has. This is the one case where a one-target-at-a-time migration may not link cleanly.

## See Also

- <doc:GettingStarted>
- <doc:WorkingWithKeys>
- <doc:ECDSASigningAndBitcoinTransactions>
- <doc:CryptoKitP256AndSecp256k1>
- <doc:SecurityConsiderations>
- ``P256K``
- ``secp256k1Error``

[changelog]: https://github.com/21-DOT-DEV/swift-secp256k1/blob/main/CHANGELOG.md
[libsecp256k1]: https://github.com/bitcoin-core/secp256k1
[se-0450]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md
[semver-4]: https://semver.org/#spec-item-4
