// swift-tools-version:5.6

import PackageDescription

let dependencies: [Package.Dependency]

#if os(macOS)
    dependencies = [
        // Dependencies used for package development
        .package(url: "https://github.com/csjones/lefthook.git", branch: "swift"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.49.5"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.46.5"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ]
#else
    dependencies = []
#endif

let package = Package(
    name: "secp256k1",
    products: [
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(
            name: "secp256k1",
            targets: [
                "secp256k1"
            ]
        )
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "secp256k1",
            dependencies: [
                "secp256k1_bindings",
                "secp256k1_implementation"
            ],
            exclude: []
        ),
        // The `libsecp256k1` bindings to programmatically work with Swift.
        .target(
            name: "secp256k1_bindings",
            path: "Sources/bindings",
            exclude: [
                "secp256k1/autogen.sh",
                "secp256k1/build-aux",
                "secp256k1/ci",
                "secp256k1/configure.ac",
                "secp256k1/contrib",
                "secp256k1/COPYING",
                "secp256k1/doc",
                "secp256k1/examples",
                "secp256k1/libsecp256k1.pc.in",
                "secp256k1/Makefile.am",
                "secp256k1/README.md",
                "secp256k1/sage",
                "secp256k1/SECURITY.md",
                "secp256k1/src/asm",
                "secp256k1/src/bench_ecmult.c",
                "secp256k1/src/bench_internal.c",
                "secp256k1/src/bench.c",
                "secp256k1/src/modules",
                "secp256k1/src/precompute_ecmult_gen.c",
                "secp256k1/src/precompute_ecmult.c",
                "secp256k1/src/tests_exhaustive.c",
                "secp256k1/src/tests.c",
                "secp256k1/src/valgrind_ctime_test.c"
            ],
            sources: [
                "secp256k1/src/precomputed_ecmult_gen.c",
                "secp256k1/src/precomputed_ecmult.c",
                "secp256k1/src/secp256k1.c",
                "src/Utility.c"
            ],
            cSettings: [
                // Basic config values that are universal and require no dependencies.
                // https://github.com/bitcoin-core/secp256k1/blob/master/src/basic-config.h#L12-L13
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1 modules.
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG")
            ]
        ),
        // Only include select utility extensions because most of Swift Crypto is not required
        .target(
            name: "secp256k1_implementation",
            dependencies: [
                .target(name: "secp256k1_bindings")
            ],
            path: "Sources/implementation",
            exclude: [
                "swift-crypto/cmake",
                "swift-crypto/CMakeLists.txt",
                "swift-crypto/CODE_OF_CONDUCT.md",
                "swift-crypto/CONTRIBUTING.md",
                "swift-crypto/CONTRIBUTORS.md",
                "swift-crypto/dev/git.commit.template",
                "swift-crypto/docker",
                "swift-crypto/LICENSE.txt",
                "swift-crypto/NOTICE.txt",
                "swift-crypto/Package.swift",
                "swift-crypto/README.md",
                "swift-crypto/scripts",
                "swift-crypto/SECURITY.md",
                "swift-crypto/Sources/_CryptoExtras",
                "swift-crypto/Sources/CCryptoBoringSSL",
                "swift-crypto/Sources/CCryptoBoringSSLShims",
                "swift-crypto/Sources/CMakeLists.txt",
                "swift-crypto/Sources/crypto-shasum",
                "swift-crypto/Sources/Crypto/AEADs",
                "swift-crypto/Sources/Crypto/ASN1",
                "swift-crypto/Sources/Crypto/CMakeLists.txt",
                "swift-crypto/Sources/Crypto/CryptoKitErrors.swift",
                "swift-crypto/Sources/Crypto/Digests/BoringSSL/Digest_boring.swift",
                "swift-crypto/Sources/Crypto/Digests/Digests.swift",
                "swift-crypto/Sources/Crypto/Digests/Digests.swift.gyb",
                "swift-crypto/Sources/Crypto/Digests/HashFunctions_SHA2.swift",
                "swift-crypto/Sources/Crypto/Digests/HashFunctions.swift",
                "swift-crypto/Sources/Crypto/Insecure",
                "swift-crypto/Sources/Crypto/Key Agreement",
                "swift-crypto/Sources/Crypto/Key Derivation",
                "swift-crypto/Sources/Crypto/Key Wrapping",
                "swift-crypto/Sources/Crypto/Keys",
                "swift-crypto/Sources/Crypto/Message Authentication Codes",
                "swift-crypto/Sources/Crypto/PRF",
                "swift-crypto/Sources/Crypto/Signatures/BoringSSL",
                "swift-crypto/Sources/Crypto/Signatures/ECDSA.swift",
                "swift-crypto/Sources/Crypto/Signatures/ECDSA.swift.gyb",
                "swift-crypto/Sources/Crypto/Signatures/EdDSA.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/ArbitraryPrecisionInteger_boring.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/CryptoKitErrors_boring.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/FiniteFieldArithmeticContext_boring.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/SafeCompare_boring.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/Zeroization_boring.swift",
                "swift-crypto/Sources/Crypto/Util/PrettyBytes.swift",
                "swift-crypto/Sources/Crypto/Util/SafeCompare.swift",
                "swift-crypto/Sources/Crypto/Util/Zeroization.swift",
                "swift-crypto/Tests/_CryptoExtrasTests/TestRSASigning.swift",
                "swift-crypto/Tests/_CryptoExtrasTests/Utils/Wycheproof.swift",
                "swift-crypto/Tests/_CryptoExtrasVectors",
                "swift-crypto/Tests/CryptoTests",
                "swift-crypto/Tests/LinuxMain.swift",
                "swift-crypto/Tests/Test Vectors"
            ],
            sources: [
                "Asymmetric.swift",
                "DH.swift",
                "Digests.swift",
                "ECDH.swift",
                "ECDSA.swift",
                "EdDSA.swift",
                "Errors.swift",
                "PrettyBytes.swift",
                "SafeCompare.swift",
                "Schnorr.swift",
                "secp256k1.swift",
                "SHA256.swift",
                "swift-crypto/Sources/Crypto/Digests/Digest.swift",
                "swift-crypto/Sources/Crypto/Signatures/Signature.swift",
                "swift-crypto/Sources/Crypto/Util/BoringSSL/RNG_boring.swift",
                "swift-crypto/Sources/Crypto/Util/SecureBytes.swift",
                "swift-crypto/Tests/_CryptoExtrasTests/Utils/BytesUtil.swift",
                "Tweak.swift",
                "Utility.swift",
                "Zeroization.swift"
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
