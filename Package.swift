// swift-tools-version: 6.1

import PackageDescription

let moduleDefines: [(trait: String, define: String)] = [
    ("ecdh", "ENABLE_MODULE_ECDH"),
    ("ellswift", "ENABLE_MODULE_ELLSWIFT"),
    ("musig", "ENABLE_MODULE_MUSIG"),
    ("recovery", "ENABLE_MODULE_RECOVERY"),
    ("schnorrsig", "ENABLE_MODULE_SCHNORRSIG"),
    ("uint256", "ENABLE_UINT256")
]

let package = Package(
    name: "swift-secp256k1",
    products: [
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(name: "libsecp256k1", targets: ["libsecp256k1"]),
        .library(name: "P256K", targets: ["P256K"])
    ],
    traits: [
        .default(enabledTraits: ["ecdh", "musig", "recovery", "schnorrsig"]),
        .trait(name: "ecdh"),
        .trait(name: "ellswift"),
        .trait(name: "recovery"),
        .trait(name: "schnorrsig"),
        .trait(name: "musig", enabledTraits: ["schnorrsig"]),
        .trait(name: "uint256")
    ],
    dependencies: Package.Dependency.developmentDependencies,
    targets: [
        .target(
            name: "P256K",
            dependencies: ["libsecp256k1"],
            // The vendored license files must ship in the tree (Apache-2.0
            // §4(a) license text, §4(d) notice) but stay uncompiled —
            // keep both excluded.
            exclude: ["swift-crypto/LICENSE.txt", "swift-crypto/NOTICE.txt"],
            swiftSettings: PackageDescription.SwiftSetting.upcomingFeatures
                + PackageDescription.SwiftSetting.moduleSettings
        ),
        .target(
            name: "libsecp256k1",
            exclude: ["COPYING"],
            cSettings: PackageDescription.CSetting.baseSettings
                + PackageDescription.CSetting.moduleSettings
        ),
        .testTarget(
            name: "libsecp256k1BindingsTests",
            dependencies: ["P256K", "libsecp256k1"],
            swiftSettings: PackageDescription.SwiftSetting.upcomingFeatures
                + PackageDescription.SwiftSetting.moduleSettings
        ),
        .testTarget(
            name: "P256KTests",
            dependencies: ["P256K"],
            swiftSettings: PackageDescription.SwiftSetting.upcomingFeatures
                + PackageDescription.SwiftSetting.moduleSettings
        )
    ],
    swiftLanguageModes: [.v6],
    cLanguageStandard: .c89
)

extension Package.Dependency {
    /// Development-only dependencies, excluded at tagged releases.
    ///
    /// When resolved at a tagged release, development tools (formatters, linters, etc.)
    /// are excluded so consumers aren't forced to download them.
    static var developmentDependencies: [Package.Dependency] {
        guard Context.gitInformation?.currentTag == nil else { return [] }
        return [
            .package(url: "https://github.com/csjones/lefthook-plugin.git", exact: "2.2.2"),
            .package(url: "https://github.com/21-DOT-DEV/swift-plugin-tuist.git", exact: "4.211.1"),
            .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: "0.64.0"),
            .package(url: "https://github.com/realm/SwiftLint.git", exact: "0.65.1"),
            .package(url: "https://github.com/swiftlang/swift-docc-plugin", exact: "1.5.0")
        ]
    }
}

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
}

extension PackageDescription.SwiftSetting {
    /// Upcoming feature flags opted into ahead of the next language version.
    static let upcomingFeatures: [Self] = [
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault")
    ]

    /// Trait-conditional settings for secp256k1 modules.
    ///
    /// - Note: Xcode does not resolve `.when(traits:)` conditions for Swift settings,
    ///   so Swift source files use `#if Xcode || ENABLE_MODULE_*` guards as a workaround.
    ///   Xcode automatically defines `Xcode` in all Swift compilations.
    static let moduleSettings: [Self] = moduleDefines.map {
        .define($0.define, .when(traits: [$0.trait]))
    }
}
