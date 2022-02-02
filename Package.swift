// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "secp256k1",
    products: [
        // The `libsecp256k1` bindings to programmatically work with Swift.
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(
            name: "secp256k1",
            targets: [
                "secp256k1"
            ]
        )
    ],
    targets: [
        .target(
            name: "secp256k1",
            dependencies: [
                "secp256k1_bindings",
                "secp256k1_implementation"
            ],
            exclude: []
        ),
        .target(
            name: "secp256k1_bindings",
            path: "Sources/bindings",
            exclude: [
                "secp256k1/src/asm",
                "secp256k1/src/bench.c",
                "secp256k1/src/bench_ecmult.c",
                "secp256k1/src/bench_internal.c",
                "secp256k1/src/modules/extrakeys/tests_impl.h",
                "secp256k1/src/modules/schnorrsig/tests_impl.h",
                "secp256k1/src/precompute_ecmult.c",
                "secp256k1/src/precompute_ecmult_gen.c",
                "secp256k1/src/tests_exhaustive.c",
                "secp256k1/src/tests.c",
                "secp256k1/src/valgrind_ctime_test.c"
            ],
            cSettings: [
                .headerSearchPath("secp256k1"),
                // Basic config values that are universal and require no dependencies.
                // https://github.com/bitcoin-core/secp256k1/blob/master/src/basic-config.h#L12-L13
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1 modules.
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG"),
            ]
        ),
        // Only include select utility extensions because most of Swift Crypto is not required
        .target(
            name: "secp256k1_implementation",
            dependencies: [
                .target(name: "secp256k1_bindings")
            ],
            path: "Sources/implementation",
            sources: [
                "swift-crypto/Tests/CryptoTests/Utils/BytesUtil.swift",
                "swift-crypto/Sources/Crypto/Util/SecureBytes.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/RNG_boring.swift",
                "swift-crypto/Sources/Crypto/Signatures/Signature.swift",
                "swift-crypto/Sources/Crypto/Digests/Digest.swift",
                "Zeroization.swift",
                "Data.swift",
                "Errors.swift",
                "SHA256.swift",
                "String.swift",
                "secp256k1.swift",
                "ECDSA.swift",
                "SafeCompare.swift",
                "NISTCurvesKeys.swift",
                "PrettyBytes.swift",
                "EdDSA.swift",
                "Digests.swift"
            ]
        ),
        .testTarget(
            name: "secp256k1Tests",
            dependencies: [
                "secp256k1"
            ]
        )
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c89
)
