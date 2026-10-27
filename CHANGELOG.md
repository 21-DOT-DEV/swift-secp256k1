# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Migrating from 0.24.x

<!-- each breaking change lands with its replacement named here; tag cut after the last breaking change, never between -->

- **Breaking**: `P256K.Recovery.PublicKey.init(_:signature:format:)` (both `Data` and `Digest` overloads) now `throws` — `secp256k1Error.underlyingCryptoError` when `secp256k1_ecdsa_recover` rejects the signature — where a failed recovery previously reached `fatalError` and terminated the process
- **Breaking**: `P256K.Signing.XonlyKey.init(dataRepresentation:keyParity:)`, `P256K.Schnorr.XonlyKey.init(dataRepresentation:keyParity:cache:)`, and `P256K.MuSig.XonlyKey.init(dataRepresentation:keyParity:cache:)` now `throws` — the coordinate is validated with `secp256k1_xonly_pubkey_parse` at construction (length **and** curve-point membership), so a malformed x-only key is no longer representable: wrong byte counts throw `secp256k1Error.incorrectKeySize` and an X coordinate with no curve point throws `secp256k1Error.underlyingCryptoError`. Downstream APIs lean on the invariant instead — `init(xonlyKey:)` on all three public-key types remains non-throwing
- **Breaking**: `P256K.Signing.ECDSASignature.dataRepresentation` now stores the canonical 64-byte `r || s` big-endian wire form — identical to `compactRepresentation` — instead of the platform-dependent opaque layout of the `secp256k1_ecdsa_signature` C struct. `init(dataRepresentation:)` validates through `secp256k1_ecdsa_signature_parse_compact` before storing: a wrong byte count throws `secp256k1Error.incorrectParameterSize`; `r`/`s` scalars at or above the curve order throw `secp256k1Error.underlyingCryptoError`. **Do not reload `dataRepresentation` bytes persisted by ≤0.24.0**: they are a different format — old bytes may still parse but decode as a different `(r, s)` pair, so verification would fail or the initializer would throw. The migration path is `compactRepresentation` (already canonical under ≤0.24.0) re-supplied through `init(dataRepresentation:)`
- **Breaking**: `P256K.Recovery.ECDSASignature.dataRepresentation` is now `private(set)` (it can no longer be mutated after initialization) and stores the canonical 65-byte `r || s || recoveryId` wire form — big-endian `r || s` plus one recovery-ID byte, i.e. what `secp256k1_ecdsa_recoverable_signature_serialize_compact` produces — instead of the platform-dependent opaque layout of the `secp256k1_ecdsa_recoverable_signature` C struct (a limb-order memory dump on 64-bit platforms). Both initializers (`init(dataRepresentation:)` and `init(compactRepresentation:recoveryId:)`) now validate through `secp256k1_ecdsa_recoverable_signature_parse_compact` before storing: wrong byte counts throw `secp256k1Error.incorrectParameterSize`; a recovery ID outside `0...3` or `r`/`s` scalars at or above the curve order throw `secp256k1Error.underlyingCryptoError`. **Do not reload `dataRepresentation` bytes persisted by ≤0.24.0**: they are a different format — old bytes may still parse but decode as a different `(r, s)` pair, so recovery would return the wrong public key or throw. The migration path is `compactRepresentation` (already canonical under ≤0.24.0) re-supplied through `init(compactRepresentation:recoveryId:)`
- **Breaking**: `P256K.Schnorr.PartialSignature.dataRepresentation` is now `private(set)` and stores the canonical 32-byte wire form produced by `secp256k1_musig_partial_sig_serialize` — previously it stored the 36-byte opaque `secp256k1_musig_partial_sig` struct (32 wire bytes followed by 4 unused bytes). `init(dataRepresentation:session:)` validates both inputs before storing: the signature must parse via `secp256k1_musig_partial_sig_parse` and the session must carry the exact 133-byte size and upstream magic prefix; violations throw `secp256k1Error.incorrectParameterSize` or `secp256k1Error.underlyingCryptoError`. **Do not reload `dataRepresentation` bytes persisted by ≤0.24.0** — they include the trailing padding and are rejected
- **Breaking**: `HashDigest.init(_:)` — also reachable via the `SHA256Digest` typealias — now `throws`: anything other than exactly 32 bytes throws `secp256k1Error.incorrectParameterSize`, where previously fewer than 32 bytes trapped on out-of-range slicing and more than 32 silently kept only the first 32. `SHA256.hash`/`taggedHash` produce their digest through an internal validated initializer instead
- **Breaking**: `HashDigest.byteCount` no longer has a public setter — the setter existed only to `fatalError`, so the property is now get-only, matching the `Digest` protocol's requirement
- **Breaking**: The `ContiguousBytes.bytes` convenience accessor is renamed `byteArray` and gated on the new public `CopyableBytes` marker protocol. The rename removes a collision with Foundation's `Data.bytes` (`RawSpan`) on newer SDKs, where `Data`'s own member shadows any extension; the gate keeps the accessor from materializing a never-zeroed `[UInt8]` copy of secret storage (`SecureBytes`, which backs `SharedSecret` and the MuSig `SecureNonce`, is internal and deliberately non-conforming). Reading `.byteArray` on a non-conforming type fails to compile with "requires that … conform to 'CopyableBytes'"; `.bytes` remains as a `@available(deprecated, renamed: "byteArray")` alias on conforming types. Conformances ship for `Data`, `Array`, `ArraySlice`, `SharedSecret`, `HashDigest`, `P256K.Signing.ECDSASignature`, `P256K.Recovery.ECDSASignature`, `P256K.Schnorr.SchnorrSignature`, `P256K.Schnorr.Nonce`, `P256K.MuSig.Nonce`, `P256K.MuSig.AggregateSignature`, and `P256K.Schnorr.PartialSignature` — every public non-secret `ContiguousBytes` type in the package. Other conformers — consumer-defined types, `String.UTF8View`, `DispatchData`, CryptoKit types — lose the member; the migration is `withUnsafeBytes { Array($0) }` at the call site, or `extension MyType: CopyableBytes` to restore it

### Added

- `P256K.setInvariantViolationHandler(_:)` — installs (or clears, with `nil`) an optional `(@Sendable (String) -> Void)` reporter invoked when the library detects a state the libsecp256k1 API contract makes unreachable (e.g. `secp256k1_ecdsa_sign` failing on an already-validated key, which can only indicate memory corruption or a defect in this library). The handler is for observability only — logging, metrics, crash artifacts — and the process still terminates via `fatalError` after it returns, following libsodium's `sodium_set_misuse_handler` model where proven-impossible states fail-stop rather than continue with undefined cryptographic state. Installs are serialized under an internal lock and may happen at any time; the handler is invoked at most once per process, and a concurrent violation on another thread waits for the first report to complete before the process terminates (the dispatching thread holds the lock through the handler and `fatalError`, matching libsodium's `sodium_crit` behavior). Contexts created by `P256K.Context.create()` also route libsecp256k1's own illegal-argument (`ARG_CHECK`) and internal-error callbacks through the same reporter, so those are observed identically rather than aborting anonymously to stderr

### Changed

- `Digest` parameters feeding fixed 32-byte upstream `msg32` reads are now normalized per SEC1 §4.1.3 instead of rejected or read out of bounds — a digest longer than 32 bytes contributes its leftmost 32 bytes and a shorter digest contributes its integer value (left-padded with zeros). Applies to `P256K.Signing.PrivateKey.signature(for:)` and `isValidSignature(_:for:)`, `P256K.Recovery.PrivateKey.signature(for:)` and `Recovery.PublicKey.init(_:signature:format:)`, MuSig `partialSignature(for:…)` and aggregate-signature verification, and `P256K.MuSig.Nonce.generate(…msg32:)` — matching how Go `crypto/ecdsa`, OpenSSL, and FIPS 186-5 treat the message representative. `isValidSignature(_:for:)` verifies the normalized digest honestly rather than failing closed. Fixed-size *non-digest* inputs — ECDSA/Schnorr/MuSig tweaks, Schnorr `auxiliaryRand`, MuSig `extraInput32`, `SessionSecretRand` — still throw `secp256k1Error.incorrectParameterSize` on the wrong byte count
- Every trap guarding a state the libsecp256k1 API contract makes unreachable — upstream serialize/parse/key-generation calls on already-validated values — now routes through `P256K.invariantFailure`, which notifies the handler installed via `P256K.setInvariantViolationHandler(_:)` before terminating, instead of bare `fatalError`/`precondition`. Unreachable-class calls that shared a `guard` with reachable ones inside throwing methods — keypair creation and accessors in Schnorr/MuSig tweaks, MuSig key aggregation and nonce generation, Schnorr and MuSig signing, key combination and derivation — are now split into per-call checks, so only genuinely reachable failures (invalid tweaks, point-at-infinity results, malformed caller-supplied bytes) still throw `secp256k1Error.underlyingCryptoError`

### Fixed

- A malformed or unrecoverable 65-byte `P256K.Recovery.ECDSASignature` passed to `P256K.Recovery.PublicKey.init(_:signature:format:)` no longer terminates the process via `fatalError` — it throws `secp256k1Error.underlyingCryptoError` (remote-input DoS)
- A recovery ID outside `0...3` passed to `P256K.Recovery.ECDSASignature.init(compactRepresentation:recoveryId:)` no longer aborts the process inside upstream's `ARG_CHECK` — it is validated before the C call and throws; a compact input shorter than 64 bytes no longer causes an out-of-bounds read
- Public `[UInt8]`/`Digest` parameters feeding fixed 32-byte upstream reads can no longer read out of bounds — digest parameters are normalized per SEC1 §4.1.3 (see Changed), and fixed-size non-digest inputs (ECDSA tweaks `add`/`multiply` ×4, Schnorr tweaks `add` ×2, Schnorr `signature(for:auxiliaryRand:)`, MuSig tweaks) throw `secp256k1Error.incorrectParameterSize` before the call
- `P256K.Signing.ECDSASignature.init(compactRepresentation:)` no longer reads out of bounds on a non-64-byte input — it throws `secp256k1Error.incorrectParameterSize` before reaching `secp256k1_ecdsa_signature_parse_compact`
- An x-only key with the wrong byte count or a coordinate that does not lift to a curve point can no longer be constructed — `XonlyKey.init` parses through `secp256k1_xonly_pubkey_parse` before storing, so the fixed-32-byte upstream read and the `fatalError` reachable through lifting a malformed key into `PublicKey` (`negation`) are both unreachable
- `P256K.MuSig.aggregateSignatures(_:)` and `P256K.MuSig.Nonce.init(aggregating:)` no longer pass an empty collection to upstream's `ARG_CHECK(n > 0)`, which aborts the process — they throw `secp256k1Error.incorrectParameterSize` first. `aggregateSignatures` also parses every partial signature through `secp256k1_musig_partial_sig_parse` and validates the session blob instead of copying untrusted bytes into C structs that upstream magic-checks by aborting
- MuSig session and key-aggregation-cache blobs are validated by exact size plus upstream magic prefix before reaching `secp256k1_musig_session_load`/`secp256k1_musig_keyagg_cache_load`, whose `ARG_CHECK`s abort the process — malformed persisted state now throws `secp256k1Error.underlyingCryptoError` (or returns `false` from the Boolean partial-signature verifier) at `P256K.MuSig.XonlyKey`/`Schnorr.XonlyKey` construction, `partialSignature(for:…)`, both MuSig tweak methods, `aggregateSignatures`, and partial-signature verification
- `P256K.Schnorr.SchnorrSignature.dataRepresentation` and `P256K.MuSig.AggregateSignature.dataRepresentation` are now `private(set)` — reassigning either to fewer than 64 bytes previously let `secp256k1_schnorrsig_verify` read past the end of the buffer
- Internal `secp256k1_pubkey`/`secp256k1_xonly_pubkey` reconstructions now go through the upstream parse entry points with an invariant `precondition` instead of copying serialized bytes into the C struct or ignoring the parse result — the struct's `data` field holds internal field-element encoding, so a failed or bypassed parse previously produced a garbage (or abort-inducing all-zero) point
- `P256K.Schnorr.PartialSignature.init(dataRepresentation:session:)` now accepts independent `DataProtocol` types for each parameter (`<D: DataProtocol, S: DataProtocol>`)
- `P256K.Schnorr.SecureNonce` now holds its secret-nonce bytes in auto-zeroing `SecureBytes` storage instead of plain `Data` — the 132-byte `secp256k1_musig_secnonce` is secret key material until `secp256k1_musig_partial_sign` consumes it, so it is zeroed on release rather than left in freed heap
- `P256K.Schnorr.Nonce` and `P256K.MuSig.Nonce` public `withUnsafeBytes`/`makeIterator` accessors now expose the stable 66-byte BIP-327 wire form (identical to `dataRepresentation`) instead of the platform-dependent 132-byte internal struct dump
- `P256K.MuSig.aggregateSignatures(_:)` rejects signatures carrying different session blobs — partial signatures from different sessions previously aggregated silently under the first signature's session, producing an invalid result with no error
- `HashDigest.init(_:)` no longer terminates the process on fewer than 32 bytes or silently discards bytes past the 32nd — it throws `secp256k1Error.incorrectParameterSize` (a public byte-consuming initializer reachable with attacker-supplied length)
- Under `-Ounchecked` builds, `precondition`-guarded upstream calls were skipped entirely because the condition expression is not evaluated — `secp256k1_context_randomize` never ran (leaving the shared context unblinded against side channels) and serialization calls wrote nothing, returning zeroed buffers as if valid. Those checks now go through `P256K.invariantFailure`, which is never elided
- `P256K.Context.create()` no longer leaves the 32-byte blinding seed in un-zeroed memory — no copy is taken at all now: `secp256k1_context_randomize` reads the seed through a pointer borrowed from `SecureBytes` storage
- MuSig `SessionSecretRand.init(bytes:)` rejects an all-zero seed with `secp256k1Error.underlyingCryptoError` — the same value `secp256k1_musig_nonce_gen` rejects as a faulty-RNG defense; `init()` reports an all-zero system-CSPRNG result through the invariant handler as an operating-system entropy defect. The all-zero test ORs every byte in place rather than copying or short-circuiting on the secret, matching upstream's `secp256k1_is_zero_array`
- `P256K.Schnorr.PrivateKey.partialSignature(for:…)` consuming a `SecureNonce` bound to a different public key no longer aborts inside `secp256k1_musig_partial_sign`'s `ARG_CHECK` — `SecureNonce` now records the public key it was generated for and the mismatch throws `secp256k1Error.underlyingCryptoError`; `P256K.MuSig.Nonce.generate(…)` likewise throws when a provided `secretKey` disagrees with `publicKey`
- A point-at-infinity `P256K.MuSig.aggregate(_:)` result — which upstream declares unreachable ("negligible probability" via hash-derived coefficients) and guards only with a `VERIFY_CHECK` compiled out in release builds — can no longer serialize into a bogus key: the zeroed point trips `secp256k1_pubkey_load`'s `ARG_CHECK` inside `secp256k1_ec_pubkey_serialize`, reporting through the invariant handler before the process terminates

## [0.24.0] - 2026-10-19

### Added

- swift-crypto's `LICENSE.txt`/`NOTICE.txt` now ship in the XCFramework zip
- A `MigratingToP256K` DocC guide covering the `import secp256k1` → `import P256K` rename across the GigaBitcoin lineage — and how to tell when the move is a port, not a rename

### Changed

- **Breaking**: `P256K.MuSig.Nonce.generate(sessionID:secretKey:publicKey:msg32:extraInput32:)` replaced by `generate(sessionSecretRand:secretKey:publicKey:msg32:extraInput32:)` taking the new `~Copyable` `P256K.MuSig.SessionSecretRand`, which is consumed by the call so session randomness cannot be reused and stores its bytes in auto-zeroing `SecureBytes` (the buffer handed to `secp256k1_musig_nonce_gen` is the value's own storage — zeroed in place on success and again on release); `msg32` is now `[UInt8]?` (`nil` = message not yet known, matching upstream's `NULL msg32`) in both `generate` overloads
- Replaced git-subtree vendoring with vendir — upstream sources sync directly into `Sources/`/`Projects/` per `vendir.yml` + `vendir.lock.yml`; `libsecp256k1Tests` compiles the shipped `Sources/libsecp256k1` tree instead of a duplicated copy
- The shipped `P256K.xcframework` is now built on Xcode 27 (Bitrise stack and release workflow pinned — the previous pipeline generated an Xcode project and used the runner default) and verified end-to-end before shipping — per-slice export allowlists plus real consumer builds on every platform (`Scripts/verify-p256k-xcframework.sh`) — instead of post-editing module interfaces; emitted interfaces carry Xcode 27's `P256K::P256K` module-selector spelling, so binary consumers (CocoaPods) need a Swift ≥6.3 toolchain to read them — source and SwiftPM builds are unaffected

### Fixed

- `P256K.MuSig.Nonce.generate` no longer reads (and, for `sessionID`, writes) past the end of short input arrays — `sessionSecretRand` is a 32-byte type invariant, and `msg32`/`extraInput32` must be exactly 32 bytes when present or `secp256k1Error.incorrectParameterSize` is thrown before reaching libsecp256k1
- MuSig `partialSignature(for:…)` and both `MuSig` tweak methods now throw `secp256k1Error.incorrectParameterSize` on non-32-byte digest/tweak inputs instead of an out-of-bounds C read
- `secretKey: nil` no longer crashes on a force unwrap in `P256K.MuSig.Nonce.generate` — `nil` reaches upstream as `NULL` as documented, and a non-`nil` key is read from its `SecureBytes` backing rather than a temporary copy
- Internally generated session randomness is now the correct 32 bytes (was 133 — the extra bytes were never read upstream)

### Removed

- **Breaking**: The `ZKP` and `libsecp256k1_zkp` products, the `zkp` bundle trait and its eight module traits, and the `SharedSourcesPlugin` build tool (spec 003 / ADR 0008) — the package now ships `P256K` + `libsecp256k1` with zero build plugins, so Xcode, headless CI, and Xcode Cloud build with no trust prompt or `-skipPackagePluginValidation`. Vanilla-surface consumers switch `.product(name: "ZKP")` / `import ZKP` to `P256K` (identical API); consumers of the zkp-only C modules pin `exact: "0.23.2"` with `traits: ["zkp"]` — `0.23.x` receives no security fixes, so pin only until a dedicated `swift-secp256k1-zkp` package ships — see the `MigratingToP256K` article and [SECURITY.md](SECURITY.md)
- The `Vendor/` mirror, `subtree.yaml`, the `update-subtree.yml`/`check-subtree-updates.yml` workflows, and the `swift-plugin-subtree` dev dependency

## [0.23.2] - 2026-05-22

### Added

- `WorkingWithKeys` DocC article consolidating the previous `KeyFormats`, `SerializingKeys`, and `TweakingKeys` articles into a single key-handling guide covering compressed/uncompressed/x-only encoding, PEM/DER serialization, and additive/multiplicative tweak operations (#1128)
- `ECDSASigningAndBitcoinTransactions` DocC article covering DER and compact encoding, low-S normalization, and a BIP-143 sighash recipe (#1128)
- Taproot key-path spend example using `SHA256.taggedHash(tag: "TapSighash", ...)` and BIP-341 reference in the Schnorr documentation (#1128)
- `SharedSourcesPlugin` trust note in the README installation section (#1106)

### Changed

- Moved CocoaPods, Arena, and Xcode plugin-trust instructions out of `README.md` into the Getting Started article; trimmed the README install section to a minimal SPM snippet and a link to the full guide (#1128)
- Tightened DocC terminology across the catalog (e.g., "public key" → "verifying key" where used for verification; "envelope" → "wrapper"/"form" for ASN.1 structures; "party" → "co-signer" in MuSig2 contexts) and replaced plain-text BIP/RFC/paper references with inline markdown links (#1126)
- Updated Docker base image from Swift 6.3.1 to 6.3.2 (#1119)
- Dropped the scheduled trigger from `check-subtree-updates.yml`; subtree updates now run only on manual dispatch or push (#1116)

## [0.23.1] - 2026-04-29

### Added

- DocC catalog articles: `KeyFormats`, `MuSig2MultiSignatures`, `RecoveringPublicKeys`, and `SecurityConsiderations` covering key representations, BIP-327 multi-signatures, ECDSA public-key recovery, and context randomization / nonce reuse / constant-time guidance (#1079)
- `EllipticCurveDiffieHellman` and `SilentPayments` DocC articles with cross-linked examples; DocC links added throughout the README usage snippets (#1103)
- `ChoosingP256KvsZKP` article and expanded `ZKP` landing page in the ZKP DocC catalog (#1096)
- `docc-release.yml` workflow to build and upload DocC archives on tagged releases (#1096)
- DocC validation job in `apple-builds.yml` (`generate-documentation --warnings-as-errors`) (#1096)
- Expanded `///` doc comments across `Sources/Shared/` with upstream citations to libsecp256k1/secp256k1-zkp headers and BIPs 32/137/146/322/324/327/340/341/352, plus `Topics` sections on major types (#1096)

### Changed

- `Package.swift` now excludes development-only dependencies (SwiftFormat, SwiftLint, Tuist, Lefthook, swift-plugin-subtree, swift-docc-plugin) at tagged releases via `Context.gitInformation?.currentTag`, so consumers resolving a tagged version no longer download dev tooling (#1082)
- Hardened workflow `env` usage in `xcframework-release.yml` and `update-subtree.yml` by moving `${{ github.ref_name }}` / `${{ inputs.subtree_name }}` into step-level env blocks (#1082)
- Refreshed all six `AGENTS.md` files to focus on non-inferable content (commands, gotchas, boundaries) (#1082)
- Adopted org-level community health defaults: project now relies on `21-DOT-DEV/.github` for `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md`; project-specific contributor onboarding moved to `AGENTS.md` (#1088)
- Bumped `SECURITY.md` Supported Versions from `0.22.x` to `0.23.x` (#1088)
- Updated vendored swift-crypto from 4.3.0 to 4.5.0 (#1072, #1086, #1094)
- Updated vendored secp256k1-zkp to latest upstream (#1069)
- Updated Docker base image from Swift 6.3.0 to 6.3.1 (#1090)
- Updated `swift-docc-plugin` dev dependency from 1.4.6 to 1.5.0 (#1098)
- Updated `actions/upload-artifact` from 4 to 7 and `actions/download-artifact` from 4 to 8 in benchmark workflows (#1066, #1067)

### Fixed

- DocC: rewrite `SharedSourcesPlugin` paths in release archives so generated documentation resolves source files correctly (#1101)

### Removed

- Top-level `CODE_OF_CONDUCT.md` and `CONTRIBUTING.md` (served from `21-DOT-DEV/.github` going forward) (#1088)

## [0.23.0] - 2026-03-29

### Added

- `benchmark-main.yml` GitHub Actions workflow: records a `package-benchmark` baseline on every push to `main` and uploads it as a 90-day artifact
- `benchmark-pr.yml` GitHub Actions workflow: downloads the cached `main` baseline, runs benchmarks on the PR branch only, and fails on regressions (exit code 2)
- `UInt256` and `Int256` types in a dedicated `Sources/Shared/UInt256/` module (`UInt256.swift`, `UInt256+Representation.swift`, `UInt256+Arithmetic.swift`, `UInt256+FixedWidthInteger.swift`, `UInt256+Modular.swift`)
- `uint256` opt-in SPM trait (not enabled by default) gating all `UInt256`/`Int256` sources and tests behind `#if Xcode || ENABLE_UINT256`; consumers with a conflicting type or awaiting a future stdlib addition can omit it
- DocC documentation catalog with Getting Started guide, API reference, and `swift-docc-plugin` 1.4.6 dependency (#1060)
- `AGENTS.md` files for AI-assisted development guidance (#1038)
- `CONTRIBUTING.md` and `SECURITY.md` project documentation (#1037)

### Changed

- CI (`bitrise.yml`, `Dockerfile`) now runs `swift test --traits ecdh,musig,recovery,schnorrsig,uint256` to cover the `uint256`-gated code paths
- Reduced `throws` propagation and reorganized `Shared` sources into subdirectories (`ECDSA/`, `Keys/`, `MuSig/`, `Recovery/`, `Schnorr/`) (#1034)
- Improved DocC doc comments across public API modules: refined summary lines, discussion sections, parameter/return/throws markup, and cross-references for `P256K.MuSig`, `P256K.Recovery`, `P256K.Signing`, `P256K.Schnorr`, `P256K.KeyAgreement`, and `P256K.Context` (#1060)
- Enabled Swift upcoming features `MemberImportVisibility` and `InternalImportsByDefault` (#1057)
- Updated vendored swift-crypto from 4.2.0 to 4.3.0 (#1042)
- Updated vendored secp256k1-zkp to latest upstream (#1026, #1028, #1036, #1045, #1047, #1051, #1053)
- Updated Docker base image from Swift 6.2.4 to 6.3.0 (#1054)
- Updated Docker registry path from finestructure to SwiftPackageIndex (#1056)
- Marked SPM build stubs as vendored in `.gitattributes` (#1043)
- Updated README with improved structure, table of contents, and clarity (#1037)
- Updated `CODE_OF_CONDUCT.md` to version 2.1 (#1037)

## [0.22.0]

### Added

- Package traits ([SE-0450](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)) for conditional module compilation (Swift 6.1+)
- Automated subtree update workflows for secp256k1 and secp256k1-zkp vendored sources
- SharedSourcesPlugin build plugin replacing symlinks for cross-platform compatibility
- `Sendable` conformance to key types (`PrivateKey`, `PublicKey`, `XonlyKey`, `SharedSecret`)
- Security, Wycheproof, Schnorr vector, and MuSig2 vector test targets via Tuist

### Changed

- Bumped swift-tools-version from 6.0 to 6.1
- Updated vendored swift-crypto from 3.11.1 to 4.2.0
- Updated vendored secp256k1 to v0.7.1
- Updated vendored secp256k1-zkp to latest upstream
- Added `@available` attributes to resolve availability requirements from swift-crypto 4.2.0
- Updated imports to use `FoundationEssentials` conditional pattern matching upstream swift-crypto
- Synced ASN1 files (`ObjectIdentifier.swift`, `SEC1PrivateKey.swift`, `SubjectPublicKeyInfo.swift`) with upstream structure
- Synced utility files (`SafeCompare.swift`, `Zeroization.swift`, `DH.swift`) with upstream patterns
- Migrated platform CI builds from Bitrise to GitHub Actions
- Replaced git submodules with subtrees for vendored dependencies

### Removed

- `@_implementationOnly` attribute from libsecp256k1 imports

## [0.21.1] - 2025-04-29

### Changed

- Added Apple-platform availability guards around `UInt256` and `Asymmetric` APIs in the `ZKP` target so the package builds on Linux where those types are unavailable (#718)
- Extended `bitrise.yml` with platform-specific test invocations (#718)

## [0.21.0] - 2025-04-27

### Added

- `UInt256` fixed-width integer type in the `ZKP` target with arithmetic, modular, and `FixedWidthInteger` conformances; enables `P256K.Signing.PrivateKey(_:)` initialization from a 256-bit integer literal (#561)

## [0.20.0] - 2025-04-24

### Added

- `P256K.xcframework` distribution and CocoaPods support: tagged releases now publish a pre-built XCFramework via `xcframework-release.yml`, and `swift-secp256k1.podspec` is pushed to the CocoaPods Trunk (#671)
- Swift Testing migration for remaining XCTest cases; XCFramework-targeted test suite (#671)

### Changed

- **Breaking:** Renamed the primary module from `secp256k1` to `P256K` and the C-bindings module from `secp256k1_bindings` to `libsecp256k1`. Consumers must update `import secp256k1` to `import P256K` and replace `secp256k1.` type-prefixes with `P256K.` (#671)
- ZKP module directories renamed from `zkp`/`zkp_bindings` to `ZKP`/`libsecp256k1_zkp` to match the new naming convention (#671)

## [0.19.0] - 2025-04-13

### Added

- `Asymmetric` format-conversion helper for translating between compressed and uncompressed public-key representations (#707) — first contribution from @zeugmaster

## [0.18.1] - 2025-03-20

### Changed

- Made `secp256k1.MuSig.aggregate` and `Nonce.pubnonce` / `Nonce.secnonce` public so downstream consumers can drive aggregation and nonce exchange directly (#696) — first contribution from @RubenWaterman
- Added VS Code development configurations (`.vscode/launch.json`, `settings.json`, `tasks.json`) for `swift build`/`swift test` debugging (#615)

## [0.18.0] - 2024-10-16

### Added

- Swift APIs for MuSig2 (BIP-327): `secp256k1.MuSig` namespace with `aggregate`, partial-signature signing/verification, and `Nonce` generation/aggregation; `secnonce` is non-`Copyable` to prevent reuse (#560)

### Changed

- Bumped `swift-tools-version` from 5.8 to 6.0
- README expanded with MuSig2 usage examples (#560)
