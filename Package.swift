// swift-tools-version: 6.1

import PackageDescription

let moduleDefines: [(trait: String, define: String)] = [
    ("ecdh", "ENABLE_MODULE_ECDH"),
    ("ellswift", "ENABLE_MODULE_ELLSWIFT"),
    ("musig", "ENABLE_MODULE_MUSIG"),
    ("recovery", "ENABLE_MODULE_RECOVERY"),
    ("schnorrsig", "ENABLE_MODULE_SCHNORRSIG")
]

let zkpModuleDefines: [(trait: String, define: String)] = [
    ("bppp", "ENABLE_MODULE_BPPP"),
    ("ecdsaAdaptor", "ENABLE_MODULE_ECDSA_ADAPTOR"),
    ("ecdsaS2C", "ENABLE_MODULE_ECDSA_S2C"),
    ("generator", "ENABLE_MODULE_GENERATOR"),
    ("rangeproof", "ENABLE_MODULE_RANGEPROOF"),
    ("schnorrsigHalfagg", "ENABLE_MODULE_SCHNORRSIG_HALFAGG"),
    ("surjectionproof", "ENABLE_MODULE_SURJECTIONPROOF"),
    ("whitelist", "ENABLE_MODULE_WHITELIST")
]

let package = Package(
    name: "swift-secp256k1",
    products: [
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(name: "libsecp256k1", targets: ["libsecp256k1"]),
        .library(name: "libsecp256k1_zkp", targets: ["libsecp256k1_zkp"]),
        .library(name: "P256K", targets: ["P256K"]),
        .library(name: "ZKP", targets: ["ZKP"])
    ],
    traits: [
        .default(enabledTraits: ["ecdh", "musig", "recovery", "schnorrsig"]),
        .trait(name: "ecdh"),
        .trait(name: "ellswift"),
        .trait(name: "recovery"),
        .trait(name: "schnorrsig"),
        .trait(name: "musig", enabledTraits: ["schnorrsig"]),
        .trait(name: "bppp"),
        .trait(name: "ecdsaAdaptor"),
        .trait(name: "ecdsaS2C"),
        .trait(name: "generator"),
        .trait(name: "rangeproof"),
        .trait(name: "schnorrsigHalfagg"),
        .trait(name: "surjectionproof"),
        .trait(name: "whitelist"),
        .trait(name: "zkp", enabledTraits: [
            "bppp", "ecdsaAdaptor", "ecdsaS2C", "ellswift", "generator",
            "rangeproof", "schnorrsigHalfagg", "surjectionproof", "whitelist"
        ])
    ],
    dependencies: [
        // Dependencies used for package development
        .package(url: "https://github.com/csjones/lefthook-plugin.git", exact: "2.1.4"),
        .package(url: "https://github.com/21-DOT-DEV/swift-plugin-tuist.git", exact: "4.162.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: "0.60.1"),
        .package(url: "https://github.com/realm/SwiftLint.git", exact: "0.63.2"),
        .package(url: "https://github.com/21-DOT-DEV/swift-plugin-subtree.git", exact: "0.0.13")
    ],
    targets: [
        // MARK: - Build Plugins

        .plugin(
            name: "SharedSourcesPlugin",
            capability: .buildTool()
        ),

        // MARK: - Main Targets

        .target(
            name: "P256K",
            dependencies: ["libsecp256k1"],
            swiftSettings: PackageDescription.SwiftSetting.moduleSettings,
            plugins: ["SharedSourcesPlugin"]
        ),
        .target(
            name: "ZKP",
            dependencies: ["libsecp256k1_zkp"],
            swiftSettings: PackageDescription.SwiftSetting.moduleSettings
                + PackageDescription.SwiftSetting.zkpModuleSettings,
            plugins: ["SharedSourcesPlugin"]
        ),
        .target(
            name: "libsecp256k1",
            cSettings: PackageDescription.CSetting.baseSettings
                + PackageDescription.CSetting.moduleSettings
        ),
        .target(
            name: "libsecp256k1_zkp",
            cSettings: PackageDescription.CSetting.baseSettings
                + PackageDescription.CSetting.moduleSettings
                + PackageDescription.CSetting.zkpModuleSettings
        ),
        .testTarget(
            name: "libsecp256k1zkpTests",
            dependencies: ["ZKP", "libsecp256k1_zkp"],
            swiftSettings: PackageDescription.SwiftSetting.moduleSettings
                + PackageDescription.SwiftSetting.zkpModuleSettings
        ),
        .testTarget(
            name: "ZKPTests",
            dependencies: ["ZKP"],
            swiftSettings: PackageDescription.SwiftSetting.moduleSettings
                + PackageDescription.SwiftSetting.zkpModuleSettings
        )
    ],
    swiftLanguageModes: [.v6],
    cLanguageStandard: .c89
)

extension PackageDescription.CSetting {
    /// Basic config values that are universal and require no dependencies.
    static let baseSettings: [Self] = [
        .define("ECMULT_GEN_PREC_BITS", to: "4"),
        .define("ECMULT_WINDOW_SIZE", to: "15"),
        .define("ENABLE_MODULE_EXTRAKEYS")
    ]

    /// Trait-conditional settings for secp256k1 modules.
    static let moduleSettings: [Self] = moduleDefines.map {
        .define($0.define, .when(traits: [$0.trait]))
    }

    /// Trait-conditional settings for ZKP-only modules.
    static let zkpModuleSettings: [Self] = zkpModuleDefines.map {
        .define($0.define, .when(traits: [$0.trait]))
    }
}

extension PackageDescription.SwiftSetting {
    /// Trait-conditional settings for secp256k1 modules.
    ///
    /// - Note: Xcode does not resolve `.when(traits:)` conditions for Swift settings,
    ///   so Swift source files use `#if Xcode || ENABLE_MODULE_*` guards as a workaround.
    ///   Xcode automatically defines `Xcode` in all Swift compilations.
    static let moduleSettings: [Self] = moduleDefines.map {
        .define($0.define, .when(traits: [$0.trait]))
    }

    /// Trait-conditional settings for ZKP-only modules.
    static let zkpModuleSettings: [Self] = zkpModuleDefines.map {
        .define($0.define, .when(traits: [$0.trait]))
    }
}
