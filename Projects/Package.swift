// swift-tools-version: 6.1
//
//  Package.swift
//  21-DOT-DEV/swift-secp256k1
//
//  Copyright (c) 2026 Timechain Software Initiative, Inc.
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//
//  Standalone benchmark package — not imported by library consumers.
//  Run with: swift package benchmark
//

import PackageDescription

let package = Package(
    name: "swift-secp256k1-benchmarks",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "..", traits: ["uint256"]),
        .package(
            url: "https://github.com/ordo-one/package-benchmark",
            from: "1.4.0",
            traits: []
        )
    ],
    targets: [
        .executableTarget(
            name: "UInt256Benchmarks",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "Benchmarks/UInt256",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
