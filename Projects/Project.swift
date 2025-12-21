import ProjectDescription

let deploymentTargets = ProjectDescription.DeploymentTargets.multiplatform(
    iOS: "18.0",
    macOS: "15.0",
    watchOS: "11.0",
    tvOS: "18.0",
    visionOS: "2.0"
)

let project = Project(
    name: "XCFramework",
    packages: [
        .package(path: "..")
    ],
    settings: .settings(
        configurations: [
            .debug(name: "Debug", xcconfig: "Resources/Project/Debug.xcconfig"),
            .debug(name: "Release", xcconfig: "Resources/Project/Release.xcconfig")
        ]
    ),
    targets: [
        .target(
            name: "P256K",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .staticFramework,
            bundleId: "dev.21.P256K",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/P256K/**"],
            resources: [],
            dependencies: [
                .package(product: "libsecp256k1")
            ],
            settings: .settings(
                base: [
                    "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES",
                    "MACOSX_DEPLOYMENT_TARGET": "13.0"
                ],
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/P256K/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/P256K/Release.xcconfig")
                ],
                defaultSettings: .recommended(
                    excluding: ["SKIP_INSTALL"]
                )
            )
        ),
        .target(
            name: "P256KTests",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .unitTests,
            bundleId: "dev.21.P256KTests",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/P256KTests/**"],
            dependencies: [.target(name: "P256K")],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/P256KTests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/P256KTests/Release.xcconfig")
                ]
            )
        ),
        .target(
            name: "BindingsTests",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .unitTests,
            bundleId: "dev.21.BindingsTests",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/BindingsTests/**"],
            dependencies: [.package(product: "libsecp256k1")],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/BindingsTests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/BindingsTests/Release.xcconfig")
                ]
            )
        ),
        .target(
            name: "XCFrameworkApp",
            destinations: [.iPhone, .iPad, .mac, .appleTv, .appleVision],
            product: .app,
            bundleId: "dev.21.XCFrameworkApp",
            sources: ["Sources/XCFrameworkApp/**"],
            resources: [
                "Resources/XCFrameworkApp/Assets.xcassets/**",
                "Resources/XCFrameworkApp/Preview Content/**"
            ],
            entitlements: "Resources/XCFrameworkApp/XCFrameworkApp.entitlements",
            dependencies: [
                .target(name: "P256K")
            ],
            settings: .settings(
                base: ["ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME": ""],
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/XCFrameworkApp/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/XCFrameworkApp/Release.xcconfig")
                ]
            )
        ),
        // Native secp256k1 C test runner
        // Sources symlinked from Vendor/secp256k1/src/
        .target(
            name: "libsecp256k1Tests",
            destinations: [.mac],
            product: .commandLineTool,
            bundleId: "dev.21.libsecp256k1Tests",
            sources: ["Sources/libsecp256k1Tests/**"],
            dependencies: [],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/libsecp256k1Tests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/libsecp256k1Tests/Release.xcconfig")
                ]
            )
        ),
        // BIP-340 Schnorr signature test vectors
        .target(
            name: "SchnorrVectorTests",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .unitTests,
            bundleId: "dev.21.SchnorrVectorTests",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/TestShared/**", "Sources/SchnorrVectorTests/**"],
            resources: ["Resources/SchnorrVectorTests/**"],
            dependencies: [.target(name: "P256K")],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/SchnorrVectorTests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/SchnorrVectorTests/Release.xcconfig")
                ]
            )
        ),
        // Wycheproof ECDH/ECDSA test vectors
        .target(
            name: "WycheproofTests",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .unitTests,
            bundleId: "dev.21.WycheproofTests",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/TestShared/**", "Sources/WycheproofTests/**"],
            resources: ["Resources/WycheproofTests/**"],
            dependencies: [.target(name: "P256K")],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/WycheproofTests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/WycheproofTests/Release.xcconfig")
                ]
            )
        ),
        // Security regression tests (vulnerability class coverage)
        .target(
            name: "SecurityTests",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .unitTests,
            bundleId: "dev.21.SecurityTests",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/TestShared/**", "Sources/SecurityTests/**"],
            resources: ["Resources/SecurityTests/**"],
            dependencies: [.target(name: "P256K")],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/SecurityTests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/SecurityTests/Release.xcconfig")
                ]
            )
        ),
        // BIP-0327 MuSig2 test vectors
        .target(
            name: "MuSig2VectorTests",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .unitTests,
            bundleId: "dev.21.MuSig2VectorTests",
            deploymentTargets: deploymentTargets,
            sources: ["Sources/TestShared/**", "Sources/MuSig2VectorTests/**"],
            resources: ["Resources/MuSig2VectorTests/**"],
            dependencies: [.target(name: "P256K")],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/MuSig2VectorTests/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/MuSig2VectorTests/Release.xcconfig")
                ]
            )
        )
    ]
)
