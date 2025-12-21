# Research: Test Architecture under Projects/

**Date**: 2025-12-15  
**Branch**: `003-test-architecture`  
**Status**: Complete

## Research Tasks

### 1. Native C Test Integration (Minimal Spike Required)

**Decision**: Tuist commandLineTool (primary) → Package.swift under Projects/ (fallback)

**Rationale**: 
- Tuist supports `.commandLineTool` product type for building executables
- Native `tests.c` requires specific C settings (VERIFY flag, header paths)
- Minimal spike needed to validate Tuist can handle C source compilation for executables

**Alternatives Considered**:
- **Package.swift in root**: Mixes test infrastructure with main package; rejected
- **Package.swift under Projects/**: Viable fallback if Tuist approach fails

**Spike Requirements**:
1. Create skeleton Tuist commandLineTool target pointing to `Vendor/secp256k1/src/tests.c`
2. Configure C settings: `VERIFY` define, header search paths
3. Verify binary builds and runs on macOS
4. Document any blockers for Tuist approach

**Finding**: Spike deferred to implementation phase per clarification.

---

### 2. BIP-340 CSV→JSON Conversion

**Decision**: Convert CSV to JSON using simple script; store in `Projects/Resources/SchnorrVectorTests/`

**Rationale**:
- BIP-340 test vectors published as CSV at `github.com/bitcoin/bips/blob/master/bip-0340/test-vectors.csv`
- CSV format: `index,secret key,public key,aux_rand,message,signature,verification result,comment`
- JSON format preferred for Swift `Codable` parsing

**CSV Schema** (from upstream):
```csv
index,secret key,public key,aux_rand,message,signature,verification result,comment
0,0000...0003,F9308A01...,0000...0000,0000...0000,E907831F...,TRUE,
4,,D69C3509...,,...,...,TRUE,
5,,EEFDEA4C...,,...,...,FALSE,public key not on the curve
```

**JSON Target Schema**:
```json
{
  "vectors": [
    {
      "index": 0,
      "secretKey": "0000...0003",
      "publicKey": "F9308A01...",
      "auxRand": "0000...0000",
      "message": "0000...0000",
      "signature": "E907831F...",
      "verificationResult": true,
      "comment": ""
    }
  ]
}
```

**Conversion Tool**: Simple Python/Swift script to convert CSV→JSON (one-time task)

**Alternatives Considered**:
- Parse CSV directly in Swift: More complex, CSV parsing libraries add dependency
- Hardcode vectors: Rejected per spec requirements

---

### 3. Wycheproof JSON Schema Structure

**Decision**: Create Swift Codable models matching Wycheproof schema

**Rationale**:
- Wycheproof JSON files already vendored at `Vendor/secp256k1/src/wycheproof/`
- Two relevant files: `ecdh_secp256k1_test.json` (752 tests), `ecdsa_secp256k1_sha256_bitcoin_test.json` (463 tests)
- Well-structured JSON with metadata, notes, and testGroups

**ECDH Schema** (observed):
```json
{
  "algorithm": "ECDH",
  "numberOfTests": 752,
  "notes": { "<FlagName>": { "bugType": "...", "description": "..." } },
  "testGroups": [
    {
      "type": "EcdhTest",
      "curve": "secp256k1",
      "encoding": "asn",
      "tests": [
        {
          "tcId": 1,
          "comment": "normal case",
          "flags": ["Normal"],
          "public": "<hex>",
          "private": "<hex>",
          "shared": "<hex>",
          "result": "valid|invalid|acceptable"
        }
      ]
    }
  ]
}
```

**ECDSA Bitcoin Schema** (observed):
```json
{
  "algorithm": "ECDSA",
  "numberOfTests": 463,
  "notes": { "<FlagName>": { "bugType": "...", "description": "...", "cves": [...] } },
  "testGroups": [
    {
      "type": "EcdsaBitcoinVerify",
      "publicKey": {
        "type": "EcPublicKey",
        "curve": "secp256k1",
        "uncompressed": "<hex>",
        "wx": "<hex>",
        "wy": "<hex>"
      },
      "sha": "SHA-256",
      "tests": [
        {
          "tcId": 1,
          "comment": "...",
          "flags": ["SignatureMalleabilityBitcoin"],
          "msg": "<hex>",
          "sig": "<hex>",
          "result": "valid|invalid"
        }
      ]
    }
  ]
}
```

**Vector Filtering**: Filter by `result` field and `flags` array per FR-011

---

### 4. secp256k1 CVE Enumeration

**Decision**: Document known CVEs from Wycheproof data + libsecp256k1 security history

**CVEs Found in Wycheproof Test Vectors**:

| CVE | Category | Description |
|-----|----------|-------------|
| CVE-2017-18146 | Arithmetic | ECDSA arithmetic errors with extreme intermediate values |
| CVE-2020-14966 | BER Encoding | Alternative BER encoding acceptance |
| CVE-2020-13822 | BER Encoding | Alternative BER encoding acceptance |
| CVE-2019-14859 | BER Encoding | Alternative BER encoding acceptance |
| CVE-2016-1000342 | BER Encoding | Alternative BER encoding acceptance |
| CVE-2022-21449 | Invalid Signature | Accepting r=0, s=0 signatures (Java "Psychic Signatures") |
| CVE-2021-43572 | Invalid Signature | Zero-value signature acceptance |
| CVE-2022-24884 | Invalid Signature | Zero-value signature acceptance |
| CVE-2019-0865 | Modular Inverse | Edge case in modular inverse computation |
| CVE-2015-2730 | Point Duplication | Point at infinity handling errors |

**Additional CVEs to Research** (libsecp256k1-specific):
- Twisted curve attack on ECDH (invalid curve points) — mentioned in spec
- Check libsecp256k1 CHANGELOG.md for security fixes

**CVE Test Categories**:
1. **Invalid Curve Attack**: ECDH with point not on curve
2. **Signature Malleability**: Bitcoin-specific s > n/2 rejection
3. **Zero Signatures**: r=0 or s=0 acceptance
4. **BER vs DER**: Strict DER encoding enforcement
5. **Arithmetic Edge Cases**: Extreme intermediate values

---

## Summary

| Research Item | Status | Decision |
|--------------|--------|----------|
| Native C Tests | Spike Deferred | Tuist commandLineTool → Package.swift fallback |
| BIP-340 Conversion | Complete | CSV→JSON script, store in Resources |
| Wycheproof Schema | Complete | Swift Codable models for ECDH + ECDSA |
| CVE Enumeration | Complete | 10+ CVEs identified from Wycheproof |

**All NEEDS CLARIFICATION items resolved.** Ready for Phase 1: Design & Contracts.
