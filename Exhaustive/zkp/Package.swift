// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "zkp",
    dependencies: [
        .package(name: "secp256k1", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "zkpTests",
            dependencies: [
                .product(name: "zkp", package: "secp256k1")
            ]
        )
    ]
)
