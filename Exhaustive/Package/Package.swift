// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "Package",
    dependencies: [
        .package(name: "secp256k1.swift", path: "../..")
    ],
    targets: [
        .testTarget(
            name: "secp256k1Tests",
            dependencies: [
                .product(name: "secp256k1", package: "secp256k1.swift")
            ]
        )
    ]
)
