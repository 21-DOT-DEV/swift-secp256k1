// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Projects",
    dependencies: [
        .package(name: "swift-secp256k1", path: "..")
    ],
    targets: [
        .testTarget(
            name: "libsecp256k1zkpTests",
            dependencies: [
                .product(name: "ZKP", package: "swift-secp256k1"),
                .product(name: "libsecp256k1_zkp", package: "swift-secp256k1")
            ]
        )
    ]
)
