# Projects

Tuist-managed test targets for swift-secp256k1 library validation.

## Test Targets

| Target | Description | Framework |
|--------|-------------|-----------|
| **P256KTests** | Core library unit tests | swift-testing |
| **BindingsTests** | Low-level C binding tests | swift-testing |
| **SchnorrVectorTests** | BIP-340 Schnorr signature vectors | swift-testing |
| **WycheproofTests** | Google Wycheproof ECDH/ECDSA edge cases | swift-testing |
| **SecurityTests** | Security regression tests (vulnerability classes) | swift-testing |
| **MuSig2VectorTests** | BIP-0327 MuSig2 protocol vectors | swift-testing |
| **libsecp256k1Tests** | Native C test runner (macOS only) | Command line |

## Running Tests

### Generate Xcode Project
```bash
swift package --disable-sandbox tuist generate -p Projects/ --no-open
```

### Run All Tests (macOS)
```bash
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme P256KTests -destination 'platform=macOS'
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme SchnorrVectorTests -destination 'platform=macOS'
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme WycheproofTests -destination 'platform=macOS'
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme SecurityTests -destination 'platform=macOS'
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme MuSig2VectorTests -destination 'platform=macOS'
```

### Run Individual Test Target
```bash
xcodebuild test -workspace Projects/XCFramework.xcworkspace -scheme <TargetName> -destination 'platform=macOS'
```

## Test Vector Sources

- **BIP-340**: [bitcoin/bips/bip-0340](https://github.com/bitcoin/bips/blob/master/bip-0340/test-vectors.csv)
- **BIP-0327**: [bitcoin/bips/bip-0327/vectors](https://github.com/bitcoin/bips/tree/master/bip-0327/vectors)
- **Wycheproof**: [google/wycheproof](https://github.com/google/wycheproof)
- **Security**: Internal vectors derived from libsecp256k1/src/tests.c

## Test Coverage Details

### SecurityTests (57 tests)

| Category | ID | Description |
|----------|-----|-------------|
| **Point Validation** | PV-001 | Reject point at infinity |
| | PV-002 | Reject twist curve points |
| | PV-003 | Reject invalid x-coordinate |
| | PV-004 | Reject invalid y-coordinate |
| **Scalar Validation** | SV-001 | Reject zero private key |
| | SV-002 | Reject scalar ≥ curve order |
| | SV-003 | Accept maximum valid scalar |
| **Signature Malleability** | SM-001 | Reject high-s signatures |
| | SM-002 | Library generates low-s only |
| **Zero Signature** | ZS-001 | Reject r=0 signatures |
| | ZS-002 | Reject s=0 signatures |
| | ZS-003 | Reject psychic signature (CVE-2022-21449) |
| | ZS-004 | Reject Schnorr zero R point |
| **DER Encoding** | DE-001 | Reject BER padding |
| | DE-002 | Reject unnecessary 0x00 prefix |
| | DE-003 | Reject non-minimal length |
| | DE-004 | Accept strict DER |
| **Nonce Security** | NS-001 | Deterministic ECDSA nonces (RFC 6979) |
| | NS-002 | SecureNonce compile-time protection |
| | NS-003 | Constant session ID determinism |
| **Invalid Curve Attack** | IC-001 | Reject truncated keys |
| | IC-002 | Reject invalid header bytes |
| | IC-003 | Reject twist curve point (y²=x³+9) |
| | IC-004 | Reject x-overflow (x=p+1) |
| | IC-005 | Reject x=-1 mod p |
| | IC-006 | Reject x=0 with invalid y |

### WycheproofTests

| Suite | Vectors | Coverage |
|-------|---------|----------|
| **ECDH** | 517 | Key agreement, invalid points, ASN.1 edge cases |
| **ECDSA Bitcoin** | 463 | Signature verification, malleability rejection |

### SchnorrVectorTests (BIP-340)

| Category | Vectors | Description |
|----------|---------|-------------|
| Signing | 4 | Private key → signature generation |
| Verification | 15 | Public key + signature validation |
| Invalid | 6 | Malformed signatures rejected |

### MuSig2VectorTests (BIP-0327)

| Suite | Vectors | Description |
|-------|---------|-------------|
| Key Aggregation | 4 valid + 2 error | Multi-party key aggregation |
| Tweaking | 5 | Plain and x-only tweaks |
| Nonce Generation | 4 | Deterministic nonce derivation |
| Nonce Aggregation | 4 valid + 1 error | Multi-party nonce combining |
| Signing | 6 | Partial signature generation |
| Signature Aggregation | 4 valid + 4 error | Final signature assembly |

## Known Limitations

| Area | Limitation | Reason |
|------|------------|--------|
| **Wycheproof ECDH** | 7 vectors skipped (tcId: 496, 497, 502-505, 507) | Invalid curve OIDs that aren't secp256k1 |
| **Wycheproof ECDH** | `InvalidAsn` flag skipped | Our strict ASN.1 parser rejects these; Wycheproof marks some as "acceptable" |
| **Wycheproof ECDH** | `WrongCurve` flag skipped | Tests non-secp256k1 curves (P-256, P-384) — out of scope |
| **MuSig2 Secnonce** | BIP-0327 vectors are 97 bytes; library uses 132 bytes | Internal `secp256k1_musig_secnonce` format differs from spec |
| **MuSig2 Nonce Gen** | Cannot verify `expected_secnonce`/`expected_pubnonce` | API uses random sessionID internally; exact vector matching not possible |
| **MuSig2 Tweaking** | Cannot verify `expected` partial signatures | Library sorts keys internally; exact order differs from vectors |
| **MuSig2 Key Agg** | Cannot verify `expected` aggregated key | Library sorts keys internally; result differs from vector order |
| **NS-002** | Compile-time guarantee only | `SecureNonce` uses `~Copyable` to prevent reuse; no runtime test possible |
| **SM-003** | Skipped | Signature normalization API not exposed in Swift wrapper |

## Platforms

All test targets support: iOS, iPadOS, macOS, watchOS, tvOS, visionOS
