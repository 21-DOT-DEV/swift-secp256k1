// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "secp256k1",
    products: [
        // The `libsecp256k1` bindings to programatically work with Swift.
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(
            name: "secp256k1",
            targets: [
                "secp256k1",
                "secp256k1_utils"
            ]
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
                "secp256k1/src/bench_schnorrsig.c",
                "secp256k1/src/bench_sign.c",
                "secp256k1/src/bench_verify.c",
                "secp256k1/src/gen_context.c",
                "secp256k1/src/modules/extrakeys/tests_impl.h",
                "secp256k1/src/modules/schnorrsig/tests_impl.h",
                "secp256k1/src/tests_exhaustive.c",
                "secp256k1/src/tests.c",
                "secp256k1/src/valgrind_ctime_test.c"
            ],
            cSettings: [
                .headerSearchPath("secp256k1"),
                // Basic config values that are universal and require no dependencies.
                // https://github.com/bitcoin-core/secp256k1/blob/master/src/basic-config.h#L27-L31
                .define("ECMULT_WINDOW_SIZE", to: "15", nil),
                .define("ECMULT_GEN_PREC_BITS", to: "4", nil),
                .define("SECP256K1_EXTRAKEYS_H"),
                .define("SECP256K1_SCHNORRSIG_H"),
                .define("_SECP256K1_MODULE_EXTRAKEYS_MAIN_"),
                .define("_SECP256K1_MODULE_SCHNORRSIG_MAIN_"),
                .define("USE_NUM_NONE"),
                .define("USE_FIELD_INV_BUILTIN"),
                .define("USE_SCALAR_INV_BUILTIN"),
                .define("USE_WIDEMUL_64")
            ]
        ),
        // Only include select utility extensions because most of Swift Crypto is not required
        .target(
            name: "secp256k1_utils",
            path: "Sources/swift-crypto",
            exclude: [
                "swift-crypto/Sources",
            ],
            sources: [
                "swift-crypto/Tests/CryptoTests/Utils/BytesUtil.swift",
                "extensions/String.swift"
            ]
        ),
        .testTarget(
            name: "secp256k1Tests",
            dependencies: [
                "secp256k1",
                "secp256k1_utils"
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c89
)
