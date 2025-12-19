# Data Model: Test Architecture under Projects/

**Date**: 2025-12-15  
**Branch**: `003-test-architecture`

## Overview

This document defines the JSON schemas for test vector files and corresponding Swift Codable models for parsing them.

---

## 1. BIP-340 Schnorr Test Vectors

### JSON Schema

**File**: `Projects/Resources/SchnorrVectorTests/bip340-vectors.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "BIP340TestVectors",
  "type": "object",
  "required": ["vectors"],
  "properties": {
    "vectors": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["index", "publicKey", "message", "signature", "verificationResult"],
        "properties": {
          "index": { "type": "integer" },
          "secretKey": { "type": ["string", "null"], "pattern": "^[0-9a-fA-F]*$" },
          "publicKey": { "type": "string", "pattern": "^[0-9a-fA-F]{64}$" },
          "auxRand": { "type": ["string", "null"], "pattern": "^[0-9a-fA-F]*$" },
          "message": { "type": "string", "pattern": "^[0-9a-fA-F]*$" },
          "signature": { "type": "string", "pattern": "^[0-9a-fA-F]{128}$" },
          "verificationResult": { "type": "boolean" },
          "comment": { "type": "string" }
        }
      }
    }
  }
}
```

### Swift Codable Model

```swift
/// BIP-340 Schnorr test vector container
struct BIP340TestVectors: Codable {
    let vectors: [BIP340Vector]
}

/// Individual BIP-340 test vector
struct BIP340Vector: Codable {
    /// Test vector index (0-based)
    let index: Int
    
    /// Private key (hex, 64 chars) - nil for verification-only vectors
    let secretKey: String?
    
    /// Public key x-coordinate (hex, 64 chars)
    let publicKey: String
    
    /// Auxiliary randomness for signing (hex, 64 chars) - nil for verification-only
    let auxRand: String?
    
    /// Message to sign/verify (hex, variable length)
    let message: String
    
    /// Schnorr signature (hex, 128 chars = 64 bytes)
    let signature: String
    
    /// Expected verification result
    let verificationResult: Bool
    
    /// Optional comment describing the test case
    let comment: String?
}
```

---

## 2. Wycheproof ECDH Test Vectors

### JSON Schema (Simplified)

**File**: `Projects/Resources/WycheproofTests/ecdh_secp256k1_test.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "WycheproofECDH",
  "type": "object",
  "required": ["algorithm", "numberOfTests", "testGroups"],
  "properties": {
    "algorithm": { "const": "ECDH" },
    "numberOfTests": { "type": "integer" },
    "notes": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "bugType": { "type": "string" },
          "description": { "type": "string" }
        }
      }
    },
    "testGroups": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "curve", "tests"],
        "properties": {
          "type": { "const": "EcdhTest" },
          "curve": { "const": "secp256k1" },
          "encoding": { "type": "string" },
          "tests": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["tcId", "result"],
              "properties": {
                "tcId": { "type": "integer" },
                "comment": { "type": "string" },
                "flags": { "type": "array", "items": { "type": "string" } },
                "public": { "type": "string" },
                "private": { "type": "string" },
                "shared": { "type": "string" },
                "result": { "enum": ["valid", "invalid", "acceptable"] }
              }
            }
          }
        }
      }
    }
  }
}
```

### Swift Codable Model

```swift
/// Wycheproof ECDH test file container
struct WycheproofECDH: Codable {
    let algorithm: String
    let numberOfTests: Int
    let notes: [String: WycheproofNote]?
    let testGroups: [ECDHTestGroup]
}

/// Note describing a flag/bug type
struct WycheproofNote: Codable {
    let bugType: String
    let description: String
    let effect: String?
    let cves: [String]?
}

/// ECDH test group
struct ECDHTestGroup: Codable {
    let type: String
    let curve: String
    let encoding: String?
    let tests: [ECDHTestVector]
}

/// Individual ECDH test vector
struct ECDHTestVector: Codable {
    /// Test case ID
    let tcId: Int
    
    /// Description of the test case
    let comment: String
    
    /// Flags indicating test characteristics (e.g., "Normal", "InvalidCurveAttack")
    let flags: [String]
    
    /// Public key (ASN.1 DER encoded, hex)
    let `public`: String
    
    /// Private key (hex)
    let `private`: String
    
    /// Expected shared secret (hex)
    let shared: String
    
    /// Expected result: "valid", "invalid", or "acceptable"
    let result: WycheproofResult
}

/// Wycheproof result type
enum WycheproofResult: String, Codable {
    case valid
    case invalid
    case acceptable
}
```

---

## 3. Wycheproof ECDSA Bitcoin Test Vectors

### JSON Schema (Simplified)

**File**: `Projects/Resources/WycheproofTests/ecdsa_secp256k1_sha256_bitcoin_test.json`

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "WycheproofECDSABitcoin",
  "type": "object",
  "required": ["algorithm", "numberOfTests", "testGroups"],
  "properties": {
    "algorithm": { "const": "ECDSA" },
    "numberOfTests": { "type": "integer" },
    "notes": { "type": "object" },
    "testGroups": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "publicKey", "tests"],
        "properties": {
          "type": { "const": "EcdsaBitcoinVerify" },
          "publicKey": {
            "type": "object",
            "properties": {
              "type": { "const": "EcPublicKey" },
              "curve": { "const": "secp256k1" },
              "keySize": { "const": 256 },
              "uncompressed": { "type": "string" },
              "wx": { "type": "string" },
              "wy": { "type": "string" }
            }
          },
          "sha": { "const": "SHA-256" },
          "tests": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["tcId", "msg", "sig", "result"],
              "properties": {
                "tcId": { "type": "integer" },
                "comment": { "type": "string" },
                "flags": { "type": "array", "items": { "type": "string" } },
                "msg": { "type": "string" },
                "sig": { "type": "string" },
                "result": { "enum": ["valid", "invalid"] }
              }
            }
          }
        }
      }
    }
  }
}
```

### Swift Codable Model

```swift
/// Wycheproof ECDSA Bitcoin test file container
struct WycheproofECDSABitcoin: Codable {
    let algorithm: String
    let numberOfTests: Int
    let notes: [String: WycheproofNote]?
    let testGroups: [ECDSABitcoinTestGroup]
}

/// ECDSA Bitcoin public key
struct ECDSAPublicKey: Codable {
    let type: String
    let curve: String
    let keySize: Int
    let uncompressed: String
    let wx: String
    let wy: String
}

/// ECDSA Bitcoin test group
struct ECDSABitcoinTestGroup: Codable {
    let type: String
    let publicKey: ECDSAPublicKey
    let publicKeyDer: String?
    let publicKeyPem: String?
    let sha: String
    let tests: [ECDSABitcoinTestVector]
}

/// Individual ECDSA Bitcoin test vector
struct ECDSABitcoinTestVector: Codable {
    /// Test case ID
    let tcId: Int
    
    /// Description of the test case
    let comment: String
    
    /// Flags indicating test characteristics
    let flags: [String]
    
    /// Message to verify (hex)
    let msg: String
    
    /// DER-encoded signature (hex)
    let sig: String
    
    /// Expected result: "valid" or "invalid"
    let result: WycheproofResult
}
```

---

## 4. Entity Relationships

```
BIP340TestVectors
└── vectors: [BIP340Vector]
        └── Fields: index, secretKey?, publicKey, auxRand?, message, signature, verificationResult, comment?

WycheproofECDH
├── notes: [String: WycheproofNote]
└── testGroups: [ECDHTestGroup]
        └── tests: [ECDHTestVector]
                └── Fields: tcId, comment, flags, public, private, shared, result

WycheproofECDSABitcoin
├── notes: [String: WycheproofNote]
└── testGroups: [ECDSABitcoinTestGroup]
        ├── publicKey: ECDSAPublicKey
        └── tests: [ECDSABitcoinTestVector]
                └── Fields: tcId, comment, flags, msg, sig, result
```

---

## 5. Validation Rules

| Entity | Rule |
|--------|------|
| `BIP340Vector.publicKey` | Must be 64 hex characters (32 bytes x-coordinate) |
| `BIP340Vector.signature` | Must be 128 hex characters (64 bytes) |
| `ECDHTestVector.result` | Filter "acceptable" results based on flags per FR-011 |
| `ECDSABitcoinTestVector.result` | "valid" must pass, "invalid" must fail |
| All hex strings | Case-insensitive parsing; normalize to lowercase |

---

## 6. State Transitions

Test vectors are **immutable** after loading. No state transitions apply.

**Loading State**:
1. **Unloaded** → Load JSON from bundle
2. **Parsing** → Decode JSON to Codable models
3. **Filtering** → Apply flag-based filters (FR-011)
4. **Ready** → Vectors available for test execution

**Error States**:
- **MissingFile** → Fail fast (per clarification)
- **MalformedJSON** → Fail fast with diagnostic
- **UnsupportedFlags** → Skip with documented reason
