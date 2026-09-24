// swift-tools-version: 6.1

// Dedicated manifest for the Bitrise "TEST XCFRAMEWORK" step. The step copies
// this file over the repo-root Package.swift so `swift test` compiles
// Tests/XCFrameworkTests against the just-built P256K.xcframework binary
// instead of the package sources.
//
// A checked-in manifest keeps the swap self-verifying — `cp` fails loudly if
// this file is missing — and reviewable, unlike sed surgery on Package.swift
// that silently no-ops when the main manifest's formatting drifts (as happened
// when target declarations went multi-line). Traits are intentionally omitted:
// this manifest exists only to exercise the prebuilt binary, so `swift test`
// runs without --traits.
//
// The libsecp256k1 C target stays declared for two reasons: the binary's
// swiftinterface still `import`s it (without the clang module, test compile
// fails with "unable to resolve module dependency"), and P256K.framework is
// static — it references the C module's symbols without containing them, so
// linking the test bundle fails unless they are built here. Every optional
// module is defined unconditionally because the Xcode-built framework was
// compiled with all of them (Xcode ignores `.when(traits:)`), matching what
// the old `swift test --traits …` invocation produced.

import PackageDescription

let package = Package(
    name: "swift-secp256k1",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    targets: [
        .binaryTarget(
            name: "P256K",
            path: "./P256K.xcframework"
        ),
        .target(
            name: "libsecp256k1",
            cSettings: [
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_ELLSWIFT"),
                .define("ENABLE_MODULE_MUSIG"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG"),
                .define("ENABLE_UINT256")
            ]
        ),
        .testTarget(
            name: "XCFrameworkTests",
            dependencies: ["P256K", "libsecp256k1"]
        )
    ],
    swiftLanguageModes: [.v6]
)
