# Research: swift-crypto 4.2.0 Update

**Feature**: 004-swift-crypto-update  
**Date**: 2025-12-26  
**Focus**: Breaking changes between swift-crypto 3.11.1 and 4.2.0

---

## Executive Summary

Swift Crypto 4.0.0 was released in September 2025 with several breaking changes. The most significant for swift-secp256k1 is the **WWDC25 availability update** which changes `@available` annotations. Other changes (Swift 6 mode, FoundationEssentials, CryptoExtras rename) have minimal impact on extracted files.

---

## Breaking Changes Analysis

### 1. Availability Attribute Changes (HIGH IMPACT)

**Decision**: Apply new availability to extracted files case-by-case based on SDK dependencies

**Rationale**: Swift Crypto 4.0.0 updated availability annotations to align with WWDC25 requirements. The new baseline is:
- `@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)`

However, files in `Sources/Shared/` that use `StaticBigInt` (e.g., `UInt256.swift`) must retain higher minimums:
- `@available(macOS 13.3, iOS 16.4, watchOS 9.4, tvOS 16.4, macCatalyst 16.4, visionOS 1.0, *)`

**Alternatives Considered**:
- Apply uniform availability to all files → Rejected: Would break `StaticBigInt` usage
- Keep all files at higher availability → Rejected: Unnecessarily restricts platform support

### 2. Swift 6 Mode Adoption (LOW IMPACT)

**Decision**: No action required for extracted files

**Rationale**: Swift 6 mode primarily affects concurrency checking. The extracted files (CryptoKitErrors, Digest, Signature, utility files, ASN1) don't use concurrency features directly. The swift-secp256k1 package already uses Swift 6.0+ per constitution.

**Alternatives Considered**:
- Full Swift 6 audit of all shared code → Deferred: Out of scope for this update

### 3. FoundationEssentials Import (MEDIUM IMPACT)

**Decision**: Monitor for compile errors; update imports if needed

**Rationale**: Swift Crypto 4.0.0 replaced `Foundation` imports with `FoundationEssentials` where possible. This may affect extracted files. Discovery-based approach will surface any issues.

**Alternatives Considered**:
- Pre-emptively update all Foundation imports → Rejected: Unnecessary if not causing errors

### 4. CryptoExtras Rename (NO IMPACT)

**Decision**: No action required

**Rationale**: `_CryptoExtras` renamed to `CryptoExtras` in 4.0.0. The swift-secp256k1 extraction doesn't include CryptoExtras files (per `subtree.yaml` extraction patterns).

### 5. New CryptoError Cases (LOW IMPACT)

**Decision**: No action required unless consuming error cases

**Rationale**: New enumeration cases in `CryptoError` could affect exhaustive switch statements. The extracted `CryptoKitErrors.swift` will automatically include new cases.

---

## Files Affected

Based on `subtree.yaml` extraction patterns:

| Source File | Extracted To | Expected Impact |
|-------------|--------------|-----------------|
| `CryptoKitErrors.swift` | `Sources/Shared/swift-crypto/` | New error cases |
| `Digest.swift` | `Sources/Shared/swift-crypto/` | Availability annotations |
| `Signature.swift` | `Sources/Shared/swift-crypto/` | Availability annotations |
| `PrettyBytes.swift` | `Sources/Shared/swift-crypto/` | Minimal |
| `SecureBytes.swift` | `Sources/Shared/swift-crypto/` | Availability annotations |
| `RNG_boring.swift` | `Sources/Shared/swift-crypto/` | Minimal |
| `ASN1/**/*.swift` | `Sources/Shared/swift-crypto/` | Availability annotations |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Availability conflicts with StaticBigInt | Medium | High | Case-by-case handling documented in spec |
| FoundationEssentials import errors | Low | Medium | Discovery-based approach |
| Linux build breaks | Low | High | Blocker condition triggers rollback |
| Public API changes required | Very Low | Critical | Blocker condition triggers rollback |

---

## Verification Plan

1. **After subtree update**: Run `swift build` to surface compile errors
2. **After availability fixes**: Run full test suite (`swift test`)
3. **Cross-platform**: Verify Linux build (CI or Docker)
4. **Tuist targets**: Build and test `Projects/` targets

---

## References

- [Swift Crypto 4.0.0 Release Notes](https://github.com/apple/swift-crypto/releases/tag/4.0.0)
- [Swift Crypto README - Compatibility](https://github.com/apple/swift-crypto#compatibility)
- [PR #359: WWDC25 Availability Update](https://github.com/apple/swift-crypto/pull/359)
