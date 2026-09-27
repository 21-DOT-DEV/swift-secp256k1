// swift-tools-version: 6.1

import PackageDescription

/// Consumer-side manifest used by the Bitrise `TEST XCFRAMEWORK` step: it
/// compiles Tests/XCFrameworkTests against the prebuilt P256K.xcframework —
/// the shipped .swiftinterface and static binary — instead of rebuilding the
/// library from source. This is the consumer-build safety net for interface
/// residue that Scripts/fix-p256k-module-interfaces.sh cannot see (a new
/// public top-level type missing from its TOPLEVEL list).
///
/// Deliberately minimal: no C target, no extra modules. If the framework's
/// binary is missing C objects or an `import libsecp256k1` survived in a
/// shipped interface, the test must fail the same way a real consumer would.
///
/// The CI step copies this file over the repository root Package.swift, so
/// all paths are repo-root-relative. Keep moduleDefines and the traits list
/// in sync with the root manifest — `--traits` errors loudly on undeclared
/// trait names, but a renamed define would drift silently.
let moduleDefines: [(trait: String, define: String)] = [
    ("ecdh", "ENABLE_MODULE_ECDH"),
    ("ellswift", "ENABLE_MODULE_ELLSWIFT"),
    ("musig", "ENABLE_MODULE_MUSIG"),
    ("recovery", "ENABLE_MODULE_RECOVERY"),
    ("schnorrsig", "ENABLE_MODULE_SCHNORRSIG"),
    ("uint256", "ENABLE_UINT256")
]

let package = Package(
    name: "swift-secp256k1-xcframework-consumer",
    traits: [
        .default(enabledTraits: ["ecdh", "musig", "recovery", "schnorrsig"]),
        .trait(name: "ecdh"),
        .trait(name: "ellswift"),
        .trait(name: "recovery"),
        .trait(name: "schnorrsig"),
        .trait(name: "musig", enabledTraits: ["schnorrsig"]),
        .trait(name: "uint256")
    ],
    targets: [
        // The artifact under test, exactly as a downstream package consumes
        // it — binary only, no fallback dependencies that could mask a
        // broken artifact.
        .binaryTarget(
            name: "P256K",
            path: "./P256K.xcframework"
        ),
        .testTarget(
            name: "XCFrameworkTests",
            dependencies: ["P256K"],
            swiftSettings: PackageDescription.SwiftSetting.upcomingFeatures
                + PackageDescription.SwiftSetting.moduleSettings
        )
    ],
    swiftLanguageModes: [.v6]
)

extension PackageDescription.SwiftSetting {
    /// Upcoming feature flags opted into ahead of the next language version.
    static let upcomingFeatures: [Self] = [
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault")
    ]

    /// Trait-conditional settings for secp256k1 modules.
    static let moduleSettings: [Self] = moduleDefines.map {
        .define($0.define, .when(traits: [$0.trait]))
    }
}
