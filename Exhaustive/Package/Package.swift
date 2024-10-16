// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Package",
    dependencies: [
        .package(name: "swift-secp256k1", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "secp256k1Tests",
            dependencies: [
                .product(name: "secp256k1", package: "swift-secp256k1")
            ]
        )
    ]
)
