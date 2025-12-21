# Quick Start: Test Architecture under Projects/

**Branch**: `003-test-architecture`  
**Date**: 2025-12-15

## Prerequisites

- Tuist installed (`brew install tuist`)
- Xcode 16+ with Swift 6.0
- Repository cloned with submodules (`git submodule update --init`)

## Directory Structure

After implementation, the test infrastructure will be organized as:

```
Projects/
├── Project.swift                    # Updated with new test targets
├── Sources/
│   ├── TestShared/                  # Shared test utilities
│   │   ├── TestVectorAssertions.swift
│   │   ├── TestVectorLoader.swift
│   │   └── HexDump.swift
│   ├── SchnorrVectorTests/          # BIP-340 test sources
│   ├── WycheproofTests/             # Wycheproof test sources
│   ├── CVETests/                    # CVE regression test sources
│   └── NativeSecp256k1Tests/        # Native C test wrapper
└── Resources/
    ├── SchnorrVectorTests/          # BIP-340 JSON vectors
    ├── WycheproofTests/             # Wycheproof JSON vectors
    └── CVETests/                    # xcconfig files
```

## Running Tests

### Generate Xcode Project

```bash
cd Projects
tuist generate
```

### Run All Test Targets

```bash
tuist test
```

### Run Specific Test Target

```bash
# BIP-340 Schnorr vectors
tuist test SchnorrVectorTests

# Wycheproof edge cases
tuist test WycheproofTests

# CVE regression tests
tuist test CVETests

# Native secp256k1 tests (if Tuist approach works)
tuist test NativeSecp256k1Tests
```

### Run on Specific Platform

```bash
# iOS Simulator
tuist test --device "iPhone 16 Pro"

# macOS
tuist test --device "My Mac"
```

## Test Vector Files

### BIP-340 Vectors

**Location**: `Projects/Resources/SchnorrVectorTests/bip340-vectors.json`

Converted from upstream CSV at `github.com/bitcoin/bips/blob/master/bip-0340/test-vectors.csv`

### Wycheproof Vectors

**Location**: `Projects/Resources/WycheproofTests/`

Extracted from vendor via `subtree.yaml`:
- `ecdh_secp256k1_test.json` (752 tests)
- `ecdsa_secp256k1_sha256_bitcoin_test.json` (463 tests)

## Adding New Test Vectors

### 1. Add JSON File

Place the JSON file in the appropriate `Resources/[TargetName]/` directory.

### 2. Create Codable Model

Add Swift `Codable` structs matching the JSON schema to `Projects/Sources/[TargetName]/`.

### 3. Write Test Cases

```swift
import XCTest
@testable import P256K

final class MyVectorTests: XCTestCase {
    func testVectors() throws {
        let loader = TestVectorLoader<MyVectorContainer>()
        let vectors = try loader.load(from: "my-vectors")
        
        for vector in vectors.items {
            // Use TestVectorAssertions for verbose diagnostics
            assertSignatureEquals(
                expected: vector.expectedSig,
                actual: computedSig,
                vectorId: "tcId=\(vector.tcId)"
            )
        }
    }
}
```

## Debugging Test Failures

### Verbose Output

Test failures include hex dumps and field breakdowns:

```
SchnorrVectorTests.testBIP340Vectors() failed:
  Vector #7 verification mismatch
  Expected: TRUE (valid signature)
  Actual: FALSE (verification failed)
  
  Public Key: F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9
  Message: 0000000000000000000000000000000000000000000000000000000000000000
  Signature:
    R: E907831F80848D1069A5371B402410364BDF1C5F8307B0084C55F1CE2DCA8215
    S: 25F66A4A85EA8B71E482A74F382D2CE5EBEEE8FDB2172F477DF4900D310536C0
```

### Filtered Vectors

Vectors skipped due to unsupported flags are logged:

```
Skipped 3 vectors:
  tcId=42: Unsupported flag "CompressedPublic"
  tcId=156: Unsupported flag "InvalidAsn"
  tcId=289: Unsupported flag "UnnamedCurve"
```

## CI Integration

Test targets are designed for CI with:

- **60-second timeout** per target
- **Fail-fast** on missing/malformed vectors
- **Deterministic** output across platforms

Example GitHub Actions step:

```yaml
- name: Run Test Vectors
  run: |
    cd Projects
    tuist generate
    tuist test SchnorrVectorTests
    tuist test WycheproofTests
    tuist test CVETests
```

## Troubleshooting

### "Test vector file not found"

Ensure resources are correctly configured in `Project.swift`:

```swift
.target(
    name: "SchnorrVectorTests",
    ...
    resources: [
        "Resources/SchnorrVectorTests/**"
    ],
    ...
)
```

### "Unsupported vector" errors

Check that `TestVectorLoader` is filtering unsupported flags. Add new flags to the skip list if needed.

### Native tests fail to build

If Tuist commandLineTool approach fails, fall back to Package.swift under Projects/:

```bash
cd Projects
swift build --target secp256k1-tests
swift run secp256k1-tests
```
