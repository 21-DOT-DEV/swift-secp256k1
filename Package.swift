// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "secp256k1",
    products: [
        // The `libsecp256k1` bindings to programatically work with Swift.
        //
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(
            name: "secp256k1",
            targets: ["secp256k1"]
        )
    ],
    targets: [
        .target(
            name: "secp256k1",
            path: "Sources/secp256k1",
            exclude: [
                "secp256k1/src/asm",
                "secp256k1/src/bench_ecdh.c",
                "secp256k1/src/bench_ecmult.c",
                "secp256k1/src/bench_internal.c",
                "secp256k1/src/bench_recover.c",
                "secp256k1/src/bench_sign.c",
                "secp256k1/src/bench_verify.c",
                "secp256k1/src/gen_context.c",
                "secp256k1/src/tests_exhaustive.c",
                "secp256k1/src/tests.c",
                "secp256k1/src/valgrind_ctime_test.c"
            ],
            cSettings: [
                .headerSearchPath("secp256k1"),
                // Basic config values that are universal and require no dependencies.
                //
                // https://github.com/bitcoin-core/secp256k1/blob/master/src/basic-config.h#L29-L34
                .define("USE_NUM_NONE"),
                .define("USE_FIELD_INV_BUILTIN"),
                .define("USE_SCALAR_INV_BUILTIN"),
                .define("USE_FIELD_10X26"),
                .define("USE_SCALAR_8X32"),
                .define("ECMULT_WINDOW_SIZE", to: "15", nil),
                .define("ECMULT_GEN_PREC_BITS", to: "4", nil)
            ]
        ),
        .testTarget(
            name: "secp256k1Tests",
            dependencies: ["secp256k1"]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c89
)
