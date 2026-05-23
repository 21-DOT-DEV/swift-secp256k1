# Getting Started with secp256k1 in Swift

@Metadata {
    @TitleHeading("How-to Guide")
}

Install P256K via Swift Package Manager, trust the SharedSourcesPlugin, and produce your first verified secp256k1 signature — the entry point for Swift developers building Bitcoin, Nostr, or Lightning Network functionality.

## Overview

P256K wraps [Bitcoin Core's `libsecp256k1`][libsecp256k1] — the production secp256k1 implementation used by every full Bitcoin node — behind a type-safe Swift API styled after [`swift-crypto`][swift-crypto]. This article walks from an empty Swift project to a verified ECDSA signature against the package's defaults.

The supported toolchain since version 0.22.0 is **Swift 6.1 / Xcode 16.3** or newer. Swift Package Manager is the primary installation path; CocoaPods is supported but may be deprecated in a future release, and [Arena][arena] lets you evaluate the package in a throwaway playground without adding it to a project.

### Add P256K with Swift Package Manager

Add `swift-secp256k1` as a dependency in your `Package.swift`:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", exact: "0.23.2"),
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "P256K", package: "swift-secp256k1"),
        ]
    ),
]
```

The pin uses `exact:` because the package is pre-1.0: under [SemVer §4][semver-4], any release below `1.0.0` is allowed to break the public API, so `exact:` ensures upgrades are deliberate rather than silent on `swift package update`.

In Xcode, the equivalent flow is **File → Add Package Dependencies…**, pasting the repository URL `https://github.com/21-DOT-DEV/swift-secp256k1`, and picking the version. Both routes resolve to the same `Package.resolved` — Xcode and `swift build` share the dependency graph.

Then import the module:

```swift
import P256K
```

### Your first signing operation

With the dependency added, the smallest end-to-end check is an ECDSA sign-and-verify:

```swift
import Foundation
import P256K

let privateKey = try P256K.Signing.PrivateKey()
let message = "Hello, secp256k1!".data(using: .utf8)!

// Sign — SHA-256 is applied internally; signature(for:) is non-throwing.
let signature = privateKey.signature(for: message)

// Verify against the matching public key.
let isValid = privateKey.publicKey.isValidSignature(signature, for: message)
print(isValid)  // true
```

If `isValid` prints `true`, P256K is installed and operational. The returned ``P256K/Signing/ECDSASignature`` is automatically normalized to lower-S form per [BIP-146][bip-146] — the only form `secp256k1_ecdsa_verify` accepts. For persistence or transmission, use `signature.compactRepresentation` (exactly 64 bytes — Nostr events, Lightning) or `signature.derRepresentation` (variable-length DER — Bitcoin transaction scripts). The in-memory layout is opaque and not a stable wire format.

For deeper signing material — DER encoding for Bitcoin transactions, BIP-340 Schnorr, ECDH key agreement, key recovery — see the cross-references at the end of this article.

### Trust the SharedSourcesPlugin

`swift-secp256k1` ships a SwiftPM build-tool plugin named `SharedSourcesPlugin` that wires shared C source files from `libsecp256k1` into the `P256K` target at build time. Xcode requires explicit user trust before running any third-party build-tool plugin, so the first build after adding the package surfaces a trust prompt.

In Xcode, an alert appears noting the plugin must be trusted before it can run. Approve via the dialog's **Trust & Enable Plugin** action — or right-click the package in the Project Navigator and choose **Trust & Enable Plugin** from the context menu. Trust persists for that project and survives package re-resolves.

> Important: For headless CI (GitHub Actions, Jenkins, Xcode Server — anything running `xcodebuild` without a UI), pass `-skipPackagePluginValidation` to the build command. Without the flag, the build fails with `"SharedSourcesPlugin" is disabled` and no plugin output is produced.

Building from the command line with `swift build` does **not** require plugin trust — plugin validation is an Xcode UX gate, not a SwiftPM CLI gate. CI pipelines invoking `swift build` or `swift test` directly skip this concern entirely.

> Note: Using Xcode Cloud? A separate `defaults write` workaround in `ci_post_clone.sh` is required because Xcode Cloud has no interactive trust prompt. See the [Swift Forums discussion][swift-forums-xcode14-trust] for the current recipe and known caveats.

### Choosing modules with package traits

P256K uses [SE-0450 Package Traits][se-0450] (Swift 6.1+) to let consumers select which secp256k1 modules compile in. By default, four traits are enabled: `ecdh`, `musig`, `recovery`, `schnorrsig`. Most use cases need nothing else.

To opt into additional modules, pass `traits:` in your dependency declaration:

```swift
.package(
    url: "https://github.com/21-DOT-DEV/swift-secp256k1",
    exact: "0.23.2",
    traits: ["zkp"]
),
```

The `zkp` bundle trait enables every zero-knowledge-proof module — `bppp`, `ecdsaAdaptor`, `ecdsaS2C`, `ellswift`, `generator`, `rangeproof`, `schnorrsigHalfagg`, `surjectionproof`, `whitelist`. The `uint256` trait — which exposes the `UInt256` and `Int256` fixed-width integer types — is opt-in and requires macOS 15, iOS 18, macCatalyst 18, watchOS 11, tvOS 18, or visionOS 2 or later. The authoritative list of available traits lives in `Package.swift` itself.

> Note: Xcode does not currently resolve trait conditions for Swift settings; all optional modules compile when building in Xcode. Trait selection is enforced when building with `swift build` from the command line.

### Alternative installation methods

#### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'swift-secp256k1', '0.23.2'
```

CocoaPods consumes a pre-built `P256K.xcframework` produced by the release pipeline rather than building from source. Swift Package Manager remains the recommended path and receives feature parity first; CocoaPods support may be deprecated in a future release.

#### Try P256K without installing

[Arena][arena] generates a temporary Swift playground with the package pre-resolved — useful for evaluating P256K's API before committing to it in a project:

```
arena 21-DOT-DEV/swift-secp256k1
```

The generated playground includes a starter import; the ECDSA snippet shown above works unchanged.

## See Also

- <doc:CryptoKitP256AndSecp256k1>
- <doc:EllipticCurveDiffieHellman>
- <doc:SilentPayments>
- <doc:MuSig2MultiSignatures>
- <doc:WorkingWithKeys>
- <doc:RecoveringPublicKeys>
- <doc:SecurityConsiderations>

[arena]: https://github.com/finestructure/Arena
[bip-146]: https://github.com/bitcoin/bips/blob/master/bip-0146.mediawiki
[libsecp256k1]: https://github.com/bitcoin-core/secp256k1
[se-0450]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md
[semver-4]: https://semver.org/#spec-item-4
[swift-crypto]: https://github.com/apple/swift-crypto
[swift-forums-xcode14-trust]: https://forums.swift.org/t/telling-xcode-14-beta-4-to-trust-build-tool-plugins-programatically/59305
