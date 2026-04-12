# ``ZKP``

@Metadata {
    @TitleHeading("Framework")
}

ZKP provides zero-knowledge proof primitives for the secp256k1 curve, built on the `libsecp256k1-zkp` library.

## Overview

The ZKP module wraps `libsecp256k1-zkp` with a Swift API for range proofs, surjection proofs, adaptor signatures, and other advanced cryptographic protocols used in confidential transactions and privacy-preserving systems.

ZKP shares the same core cryptographic types as ``P256K`` (ECDSA, Schnorr, MuSig2, ECDH, key recovery) and extends them with additional zero-knowledge proof capabilities from the Elements/Liquid sidechain project.

> Note: This module is under active development. Public API will be added in future releases.
