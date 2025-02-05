import ProjectDescription

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
            deploymentTargets:
                    .multiplatform(
                        iOS: "18.0",
                        macOS: "15.0",
                        watchOS: "11.0",
                        tvOS: "18.0",
                        visionOS: "2.0"
                    ),
            sources: ["Sources/P256K/**"],
            resources: [],
            dependencies: [
                .package(product: "libsecp256k1")
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/P256K/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/P256K/Release.xcconfig")
                ]
            )
        ),
        .target(
            name: "XCFrameworkApp",
            destinations: [.iPhone, .iPad, .mac, .appleWatch, .appleTv, .appleVision],
            product: .app,
            bundleId: "dev.21.XCFrameworkApp",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            sources: ["Sources/XCFrameworkApp/**"],
            resources: ["Resources/XCFrameworkApp/**"],
            dependencies: [
                .target(name: "P256K")
            ],
            settings: .settings(
                configurations: [
                    .debug(name: "Debug", xcconfig: "Resources/P256K/Debug.xcconfig"),
                    .release(name: "Release", xcconfig: "Resources/P256K/Release.xcconfig")
                ]
            )
        )
//        .target(
//            name: "XCFrameworkTests",
//            destinations: .iOS,
//            product: .unitTests,
//            bundleId: "dev.21.XCFrameworkTests",
//            infoPlist: nil,
//            sources: ["Sources/XCFrameworkTests/**"],
//            resources: ["Resources/XCFrameworkTests/**"],
//            dependencies: [.target(name: "secp256k1")],
//            settings: .settings(
//                base: [
//                    "SDKROOT": "auto"
//                ],
//                configurations: [
//                    .debug(name: "Debug", xcconfig: "Resources/XCFrameworkTests/Debug.xcconfig"),
//                    .release(name: "Release", xcconfig: "Resources/XCFrameworkTests/Release.xcconfig")
//                ]
//            )
//        ),
    ]
)
