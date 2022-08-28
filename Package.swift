// swift-tools-version:5.6

import PackageDescription

let dependencies: [Package.Dependency]

#if os(macOS)
    dependencies = [
        // Dependencies used for package development
        .package(url: "https://github.com/csjones/lefthook.git", branch: "swift"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.49.5"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.46.5"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ]
#else
    dependencies = []
#endif

let package = Package(
    name: "secp256k1",
    products: [
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(
            name: "secp256k1",
            targets: [
                "secp256k1"
            ]
        ),
        .library(
            name: "zkp",
            targets: [
                "zkp"
            ]
        )
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "secp256k1",
            dependencies: [
                "secp256k1_bindings"
            ]
        ),
        .target(
            name: "zkp",
            dependencies: [
                "secp256k1_zkp_bindings"
            ]
        ),
        .target(
            name: "secp256k1_bindings",
            cSettings: [
                // Basic config values that are universal and require no dependencies.
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1 modules.
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG"),
                // Disables SPM warnings
                .unsafeFlags(["-Wno-shorten-64-to-32"])
            ]
        ),
        .target(
            name: "secp256k1_zkp_bindings",
            cSettings: [
                // Basic config values that are universal and require no dependencies.
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1-zkp modules.
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_ECDSA_ADAPTOR"),
                .define("ENABLE_MODULE_ECDSA_S2C"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_GENERATOR"),
                .define("ENABLE_MODULE_MUSIG"),
                .define("ENABLE_MODULE_RANGEPROOF"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG"),
                .define("ENABLE_MODULE_SURJECTIONPROOF"),
                .define("ENABLE_MODULE_WHITELIST"),
                // Some modules need additional header search paths
                .headerSearchPath("../../Submodules/secp256k1-zkp"),
                .headerSearchPath("../../Submodules/secp256k1-zkp/src"),
                // Disables SPM warnings
                .unsafeFlags(["-Wno-shorten-64-to-32"])
            ]
        ),
        .testTarget(
            name: "secp256k1Tests",
            dependencies: [
                "secp256k1"
            ]
        )
        // Breaks CI
//        .testTarget(
//            name: "zkpTests",
//            dependencies: [
//                "zkp"
//            ]
//        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c89
)
