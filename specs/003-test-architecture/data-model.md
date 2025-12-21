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

## 4. BIP-0327 MuSig2 Test Vectors

### JSON Schemas

**Files**: `Projects/Resources/MuSig2VectorTests/*.json`

BIP-0327 defines 8 vector files for MuSig2 testing. Key schemas below:

#### Key Aggregation Vectors (`key_agg_vectors.json`)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "KeyAggVectors",
  "type": "object",
  "required": ["pubkeys", "valid_test_cases", "error_test_cases"],
  "properties": {
    "pubkeys": { "type": "array", "items": { "type": "string" } },
    "tweaks": { "type": "array", "items": { "type": "string" } },
    "valid_test_cases": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["key_indices", "expected"],
        "properties": {
          "key_indices": { "type": "array", "items": { "type": "integer" } },
          "expected": { "type": "string" }
        }
      }
    },
    "error_test_cases": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["key_indices", "error"],
        "properties": {
          "key_indices": { "type": "array", "items": { "type": "integer" } },
          "tweak_indices": { "type": "array", "items": { "type": "integer" } },
          "is_xonly": { "type": "array", "items": { "type": "boolean" } },
          "error": { "type": "object" },
          "comment": { "type": "string" }
        }
      }
    }
  }
}
```

#### Sign/Verify Vectors (`sign_verify_vectors.json`)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "SignVerifyVectors",
  "type": "object",
  "required": ["sk", "pubkeys", "secnonces", "pnonces", "aggnonces", "msgs", "valid_test_cases", "sign_error_test_cases", "verify_fail_test_cases", "verify_error_test_cases"],
  "properties": {
    "sk": { "type": "string" },
    "pubkeys": { "type": "array", "items": { "type": "string" } },
    "secnonces": { "type": "array", "items": { "type": "string" } },
    "pnonces": { "type": "array", "items": { "type": "string" } },
    "aggnonces": { "type": "array", "items": { "type": "string" } },
    "msgs": { "type": "array", "items": { "type": "string" } }
  }
}
```

### Swift Codable Models

```swift
// MARK: - Key Aggregation

/// BIP-0327 Key Aggregation test vectors
struct KeyAggVectors: Codable {
    let pubkeys: [String]
    let tweaks: [String]?
    let valid_test_cases: [KeyAggValidCase]
    let error_test_cases: [KeyAggErrorCase]
}

struct KeyAggValidCase: Codable {
    let key_indices: [Int]
    let expected: String
}

struct KeyAggErrorCase: Codable {
    let key_indices: [Int]
    let tweak_indices: [Int]?
    let is_xonly: [Bool]?
    let error: KeyAggError
    let comment: String?
}

struct KeyAggError: Codable {
    let type: String
    let signer: Int?
    let contrib: String?
    let message: String?
}

// MARK: - Nonce Aggregation

/// BIP-0327 Nonce Aggregation test vectors
struct NonceAggVectors: Codable {
    let pnonces: [String]
    let valid_test_cases: [NonceAggValidCase]
    let error_test_cases: [NonceAggErrorCase]
}

struct NonceAggValidCase: Codable {
    let pnonce_indices: [Int]
    let expected: String
}

struct NonceAggErrorCase: Codable {
    let pnonce_indices: [Int]
    let error: NonceAggError
    let comment: String?
}

struct NonceAggError: Codable {
    let type: String
    let signer: Int?
    let contrib: String?
}

// MARK: - Signature Aggregation

/// BIP-0327 Signature Aggregation test vectors
struct SigAggVectors: Codable {
    let pubkeys: [String]
    let pnonces: [String]
    let tweaks: [String]
    let psigs: [String]
    let msg: String
    let valid_test_cases: [SigAggValidCase]
    let error_test_cases: [SigAggErrorCase]?
}

struct SigAggValidCase: Codable {
    let aggnonce: String
    let nonce_indices: [Int]
    let key_indices: [Int]
    let tweak_indices: [Int]
    let is_xonly: [Bool]
    let psig_indices: [Int]
    let expected: String
}

struct SigAggErrorCase: Codable {
    let aggnonce: String
    let nonce_indices: [Int]
    let key_indices: [Int]
    let tweak_indices: [Int]
    let is_xonly: [Bool]
    let psig_indices: [Int]
    let error: SigAggError
    let comment: String?
}

struct SigAggError: Codable {
    let type: String
    let signer: Int?
    let contrib: String?
}

// MARK: - Sign/Verify

/// BIP-0327 Sign/Verify test vectors
struct SignVerifyVectors: Codable {
    let sk: String
    let pubkeys: [String]
    let secnonces: [String]
    let pnonces: [String]
    let aggnonces: [String]
    let msgs: [String]
    let valid_test_cases: [SignVerifyValidCase]
    let sign_error_test_cases: [SignErrorCase]
    let verify_fail_test_cases: [VerifyFailCase]
    let verify_error_test_cases: [VerifyErrorCase]
}

struct SignVerifyValidCase: Codable {
    let key_indices: [Int]
    let nonce_indices: [Int]
    let aggnonce_index: Int
    let msg_index: Int
    let signer_index: Int
    let expected: String
}

struct SignErrorCase: Codable {
    let key_indices: [Int]
    let aggnonce_index: Int
    let msg_index: Int
    let secnonce_index: Int
    let error: SignError
    let comment: String?
}

struct SignError: Codable {
    let type: String
    let message: String?
}

struct VerifyFailCase: Codable {
    let sig: String
    let key_indices: [Int]
    let nonce_indices: [Int]
    let msg_index: Int
    let signer_index: Int
    let comment: String?
}

struct VerifyErrorCase: Codable {
    let sig: String
    let key_indices: [Int]
    let nonce_indices: [Int]
    let msg_index: Int
    let signer_index: Int
    let error: VerifyError
    let comment: String?
}

struct VerifyError: Codable {
    let type: String
    let signer: Int?
    let contrib: String?
}

// MARK: - Tweak

/// BIP-0327 Tweak test vectors
struct TweakVectors: Codable {
    let sk: String
    let pubkeys: [String]
    let secnonce: String
    let pnonces: [String]
    let aggnonce: String
    let tweaks: [String]
    let msg: String
    let valid_test_cases: [TweakValidCase]
    let error_test_cases: [TweakErrorCase]?
}

struct TweakValidCase: Codable {
    let key_indices: [Int]
    let nonce_indices: [Int]
    let tweak_indices: [Int]
    let is_xonly: [Bool]
    let signer_index: Int
    let expected: String
    let comment: String?
}

struct TweakErrorCase: Codable {
    let key_indices: [Int]
    let nonce_indices: [Int]
    let tweak_indices: [Int]
    let is_xonly: [Bool]
    let signer_index: Int
    let error: TweakError
    let comment: String?
}

struct TweakError: Codable {
    let type: String
    let message: String?
}
```

---

## 5. Entity Relationships

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

BIP327MuSig2 (8 vector files)
├── KeyAggVectors: pubkeys, tweaks, valid_test_cases, error_test_cases
├── NonceAggVectors: pnonces, valid_test_cases, error_test_cases
├── SigAggVectors: pubkeys, pnonces, tweaks, psigs, msg, valid_test_cases
├── SignVerifyVectors: sk, pubkeys, secnonces, pnonces, aggnonces, msgs, test_cases
└── TweakVectors: sk, pubkeys, secnonce, pnonces, aggnonce, tweaks, msg, test_cases
```

---

## 6. Validation Rules

| Entity | Rule |
|--------|------|
| `BIP340Vector.publicKey` | Must be 64 hex characters (32 bytes x-coordinate) |
| `BIP340Vector.signature` | Must be 128 hex characters (64 bytes) |
| `ECDHTestVector.result` | Filter "acceptable" results based on flags per FR-011 |
| `ECDSABitcoinTestVector.result` | "valid" must pass, "invalid" must fail |
| All hex strings | Case-insensitive parsing; normalize to lowercase |

---

## 7. State Transitions

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
