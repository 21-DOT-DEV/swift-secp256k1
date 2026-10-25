# Getting Started with secp256k1 in Swift

@Metadata {
    @TitleHeading("How-to Guide")
}

Install P256K via Swift Package Manager and produce your first verified secp256k1 signature — the entry point for Swift developers building Bitcoin, Nostr, or Lightning Network functionality.

## Overview

P256K wraps [Bitcoin Core's `libsecp256k1`][libsecp256k1] — the production secp256k1 implementation used by every full Bitcoin node — behind a type-safe Swift API styled after [`swift-crypto`][swift-crypto]. This article walks from an empty Swift project to a verified ECDSA signature against the package's defaults.

The supported toolchain since version 0.22.0 is **Swift 6.1 / Xcode 16.3** or newer. Swift Package Manager is the primary installation path; CocoaPods is supported but may be deprecated in a future release, and [Arena][arena] lets you evaluate the package in a throwaway playground without adding it to a project.

### Add P256K with Swift Package Manager

Add `swift-secp256k1` as a dependency in your `Package.swift`:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", .upToNextMinor(from: "0.24.0")),
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

The requirement uses `.upToNextMinor` because the package is pre-1.0: under [SemVer §4][semver-4], any release below `1.0.0` may break the public API, and SwiftPM's `from:` requirement resolves forward through every `0.x` release — so the minor version is the stability boundary, and `.upToNextMinor` still picks up patch releases within the minor. This example moves to `0.25.0` when that tag is cut.

In Xcode, the equivalent flow is **File → Add Package Dependencies…**, pasting the repository URL `https://github.com/21-DOT-DEV/swift-secp256k1`, and picking the version. Both routes resolve to the same `Package.resolved` — Xcode and `swift build` share the dependency graph.

Then import the module:

```swift
import P256K
```

> Note: Releases after the 0.23.x series ship no build plugins, so Xcode, headless CI, and Xcode Cloud build P256K without a trust prompt or `-skipPackagePluginValidation`. Through 0.23.x, the SharedSourcesPlugin still needs trust in Xcode and the flag for headless `xcodebuild`. After you upgrade past 0.23.x, you can remove the flag and any plugin-trust `ci_post_clone.sh` workaround.

### Your first signing operation

With the dependency added, the smallest end-to-end check is an ECDSA sign-and-verify:

```swift
import Foundation
import P256K

let privateKey = try P256K.Signing.PrivateKey()
let message = "Hello, secp256k1!".data(using: .utf8)!

// Sign — SHA-256 is applied internally.
let signature = privateKey.signature(for: message)

// Verify against the matching public key.
let isValid = privateKey.publicKey.isValidSignature(signature, for: message)
print(isValid)  // true
```

If `isValid` prints `true`, P256K is installed and operational. The returned ``P256K/Signing/ECDSASignature`` is automatically normalized to lower-S form per [BIP-146][bip-146] — the only form `secp256k1_ecdsa_verify` accepts. For persistence or transmission, use `signature.compactRepresentation` (exactly 64 bytes — Nostr events, Lightning) or `signature.derRepresentation` (variable-length DER — Bitcoin transaction scripts). The in-memory layout is opaque and not a stable wire format.

For deeper signing material — DER encoding for Bitcoin transactions, BIP-340 Schnorr, ECDH key agreement, key recovery — see the cross-references at the end of this article.

### Choosing modules with package traits

P256K uses [SE-0450 Package Traits][se-0450] (Swift 6.1+) to let consumers select which secp256k1 modules compile in. By default, four traits are enabled: `ecdh`, `musig`, `recovery`, `schnorrsig`. Most use cases need nothing else.

To opt into additional modules, pass `traits:` in your dependency declaration:

```swift
.package(
    url: "https://github.com/21-DOT-DEV/swift-secp256k1",
    .upToNextMinor(from: "0.24.0"),
    traits: ["ellswift", "uint256"]
),
```

Two modules remain opt-in: the `ellswift` trait compiles upstream's ElligatorSwift C module (`secp256k1_ellswift_*`, reachable through `import libsecp256k1` — P256K has no Swift overlay for it), and the `uint256` trait exposes the `UInt256` and `Int256` fixed-width integer types, which require macOS 15, iOS 18, macCatalyst 18, watchOS 11, tvOS 18, or visionOS 2 or later. The authoritative list of available traits lives in `Package.swift` itself.

> Warning: A `zkp` bundle trait enabling zero-knowledge-proof modules shipped through the 0.23.x series and was removed with the `ZKP` and `libsecp256k1_zkp` products. `0.23.x` receives no security fixes — pin it only until a dedicated zkp package ships ([SECURITY.md][security]). If resolution fails on `traits: ["zkp"]` in an existing manifest, remove the trait — or, if you use the zkp-only modules, pin `exact: "0.23.2"` and keep `traits: ["zkp"]` (the trait still exists there and compiles those modules under `swift build`).

> Note: Xcode does not currently resolve trait conditions for Swift settings; all optional modules compile when building in Xcode. Trait selection is enforced when building with `swift build` from the command line.

### Alternative installation methods

#### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'swift-secp256k1', '0.24.0'
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
[security]: https://github.com/21-DOT-DEV/swift-secp256k1/blob/main/SECURITY.md
[semver-4]: https://semver.org/#spec-item-4
[swift-crypto]: https://github.com/apple/swift-crypto
