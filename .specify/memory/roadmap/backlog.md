# Backlog: Future Consideration

**Purpose**: Items deferred for future consideration, not currently scheduled  
**Last Updated**: 2025-12-03

---

## Data Structures

These general-purpose data structures support specific BIPs but are not secp256k1-specific. Scope decision deferred.

### Bloom Filters (BIP-37)

**Purpose**: SPV client transaction filtering  
**BIP Reference**: BIP-37  
**Notes**:
- Uses MurmurHash3 (Phase 6)
- BIP-37 largely deprecated due to privacy concerns
- Low priority

### Golomb-Coded Sets (BIP-158)

**Purpose**: Compact block filters for light clients  
**BIP Reference**: BIP-158  
**Notes**:
- Uses SipHash (Phase 6)
- More modern alternative to Bloom filters
- Medium priority if SipHash implemented

### Merkle Trees

**Purpose**: Transaction Merkle roots, Taproot script trees  
**BIP Reference**: BIP-341 (Taproot Merkle trees)  
**Notes**:
- Fundamental Bitcoin structure
- Taproot uses tagged hashes for Merkle branches
- Medium-high priority for Taproot completeness

---

## Applications

Deferred demo/utility applications.

### macOS CLI Tool (MuSig2)

**Purpose**: Command-line MuSig2 signing for scripting  
**Notes**:
- Complements Phase 5 SwiftUI app
- Enables automation and integration
- Medium priority

### ECDSA Signing CLI

**Purpose**: Command-line ECDSA signing utility  
**Notes**:
- Basic signing/verification tool
- Good for testing and scripting
- Low priority (ECDSA is legacy)

### Schnorr Verifier

**Purpose**: Standalone Schnorr signature verification  
**Notes**:
- Simple utility app
- Could be web-based (WASM) or CLI
- Low priority

### Address Generator

**Purpose**: Bitcoin/Nostr address generation utility  
**Notes**:
- Uses Phase 4 Bech32
- Visual tool for key→address conversion
- Medium priority after Phase 4

---

## Additional Primitives

Primitives from the long-term table not yet scheduled.

### Tagged Hashes

**Purpose**: Domain-separated SHA-256 per BIP-340/BIP-341  
**BIP Reference**: BIP-340, BIP-341  
**Notes**:
- `SHA256(SHA256(tag) || SHA256(tag) || x)`
- May already be partially implemented for Schnorr
- Review existing implementation

### Base58Check

**Purpose**: Legacy Bitcoin address encoding  
**BIP Reference**: BIP-13 and earlier  
**Notes**:
- Uses double SHA-256 for checksum
- Legacy format (Bech32 preferred)
- Low priority

### Strict DER Encoding

**Purpose**: BIP-66 signature encoding validation  
**BIP Reference**: BIP-66  
**Notes**:
- May already be handled by libsecp256k1
- Review existing implementation
- Validation only, not new functionality

---

## Platform Support

### Windows Build Support

**Purpose**: Enable Windows builds without symlink requirements  
**Related Feature**: 001-spm-shared-code-plugin  
**Status**: Deferred — placeholder `#if os(Windows)` in Plugin.swift  
**Priority**: Low (Windows is not a primary Swift platform)

**Notes**:
- Current implementation uses POSIX `find + cp` (not available on Windows)
- Windows alternative: `robocopy /E` or `xcopy /E /I`
- Requires Windows CI runner in GitHub Actions
- SharedSourcesPlugin needs Windows-specific implementation

**Acceptance Criteria**:
- `swift build` succeeds on Windows without symlink errors
- Windows CI job passes in GitHub Actions

---

## Scope Decisions Pending

Items where scope (in-repo vs separate package) is undecided:

| Item | Options | Decision Status |
|------|---------|-----------------|
| PBKDF2/scrypt | In-repo utility vs separate package | Deferred to Phase 7 |
| Bloom filters | In-repo vs recommend external | Deferred |
| Merkle trees | In-repo (Taproot need) vs separate | Deferred |

---

## Prioritization Criteria

When promoting items from backlog:

1. **User demand** — GitHub issues, community requests
2. **BIP coverage** — Fills gap in Bitcoin standard support
3. **Dependency chain** — Unblocks other features
4. **Maintenance burden** — Complexity vs value trade-off
5. **Scope alignment** — Fits zero-dependency philosophy

---

## Adding to Backlog

New items should include:
- **Purpose**: What problem it solves
- **BIP Reference**: If applicable
- **Dependencies**: What it requires
- **Priority signal**: High/Medium/Low with rationale
- **Notes**: Implementation considerations
