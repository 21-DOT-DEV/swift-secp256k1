# AGENTS.md (Sources)

This directory contains the library implementation (Swift targets and C bindings).

## What lives here

- **Swift targets**: `P256K` (wraps libsecp256k1) and `ZKP` (wraps libsecp256k1_zkp)
- **C binding targets**: `libsecp256k1` and `libsecp256k1_zkp`
- **Shared sources**: `Sources/Shared/` — compiled into both P256K and ZKP via SharedSourcesPlugin. Changes here affect both targets.

## Extractions

Some paths under `Sources/` are generated via extraction from vendored upstream sources. Before making changes in these areas, check `subtree.yaml` to confirm the extraction mapping and avoid unintended divergence:

- `Sources/libsecp256k1/`
- `Sources/libsecp256k1_zkp/`
- `Sources/Shared/swift-crypto/`
