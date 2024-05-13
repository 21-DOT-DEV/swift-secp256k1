// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "secp256k1.swift",
    products: [
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(name: "secp256k1", targets: ["secp256k1"]),
        .library(name: "zkp", targets: ["zkp"])
    ],
    dependencies: [
        // Dependencies used for package development
        .package(url: "https://github.com/csjones/lefthook-plugin.git", exact: "1.6.10"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: "0.53.8"),
        .package(url: "https://github.com/realm/SwiftLint.git", exact: "0.52.4")
    ],
    targets: [
        .target(name: "secp256k1", dependencies: ["secp256k1_bindings"]),
        .target(name: "zkp", dependencies: ["zkp_bindings"]),
        .target(
            name: "secp256k1_bindings",
            cSettings: [
                // Basic config values that are universal and require no dependencies.
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1 modules.
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_ELLSWIFT"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG")
            ]
        ),
        .target(
            name: "zkp_bindings",
            cSettings: [
                // Basic config values that are universal and require no dependencies.
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1-zkp modules.
                .define("ENABLE_MODULE_BPPP"),
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_ECDSA_ADAPTOR"),
                .define("ENABLE_MODULE_ECDSA_S2C"),
                .define("ENABLE_MODULE_ELLSWIFT"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_GENERATOR"),
                .define("ENABLE_MODULE_MUSIG"),
                .define("ENABLE_MODULE_RANGEPROOF"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG"),
                .define("ENABLE_MODULE_SCHNORRSIG_HALFAGG"),
                .define("ENABLE_MODULE_SURJECTIONPROOF"),
                .define("ENABLE_MODULE_WHITELIST"),
                // Some modules need additional header search paths
                .headerSearchPath("../../Submodules/secp256k1-zkp"),
                .headerSearchPath("../../Submodules/secp256k1-zkp/src")
            ]
        ),
        .testTarget(name: "zkpTests", dependencies: ["zkp"])
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c89
)
