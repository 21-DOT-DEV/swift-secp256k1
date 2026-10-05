// swift-tools-version: 6.3
//
//  Package.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026-present Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information

import PackageDescription

/// A package of its own, separate from the root one, and deliberately so: SwiftPM
/// has no way to mark a target as development-only, so tooling declared in the root
/// manifest would drag the project's development dependencies (SourceKitten, Tuist,
/// SwiftLint, swift-syntax, and friends — the ones the root manifest already hides
/// behind its tagged-release check) into every run. This one takes two small
/// dependencies instead.
///
/// swift-yaml has no tagged release, so it is pinned to a commit. Its YAML product
/// needs C++ interoperability mode, which every target importing it must also use;
/// that is contained here, since this package is not a dependency of the root one.
let package = Package(
    name: "DevelopmentTools",
    dependencies: [
        .package(
            url: "https://github.com/21-DOT-DEV/swift-yaml",
            revision: "473252b018cbf2e5f8d0b51f19af0a23c21592a0"
        ),
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.6.2")
    ],
    targets: [
        .target(
            name: "PlanIndex",
            dependencies: [
                .product(name: "YAML", package: "swift-yaml"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "plans",
            dependencies: ["PlanIndex"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .testTarget(
            name: "PlanIndexTests",
            dependencies: ["PlanIndex"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        )
    ]
)
