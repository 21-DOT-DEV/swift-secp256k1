# Phase 5: Applications

**Goal**: Demonstrate library capabilities through practical applications  
**Status**: 🔜 Planned  
**Last Updated**: 2025-12-03  
**Depends On**: Phase 4 (Bitcoin Utility Primitives for address generation)

---

## Features

### MuSig2 Signing App (SwiftUI)

**Purpose & User Value**:  
Create a SwiftUI application demonstrating MuSig2 multi-party Schnorr signing for Bitcoin and Nostr. Serves as demo app, functional signing tool, and test harness for MuSig2 APIs.

**Success Metrics**:
- App runs on all Apple platforms (iOS, macOS, iPadOS, visionOS, tvOS)
- Demonstrates practical MuSig2 key creation workflows:
  - Bitcoin: aggregate keys for multi-sig wallets
  - Nostr: aggregate keys for shared accounts
- Complete signing ceremony: key aggregation → nonce exchange → partial signing → aggregation
- User can export generated keys/signatures
- Serves as integration test for MuSig2 APIs
- Code quality suitable for reference implementation

**Dependencies**:
- Phase 4 Bech32/Bech32m (for Bitcoin/Nostr address display)
- Phase 3 MuSig2 tutorial (documentation alignment)

**Notes**:
- Location: `Projects/` folder
- Extend existing `XCFrameworkApp` target or create new app target
- Consider: QR code display for key sharing, clipboard support

---

## App Feature Breakdown

### Core Features (MVP)

| Feature | Description |
|---------|-------------|
| **Key Generation** | Generate MuSig2-compatible Schnorr keys |
| **Key Aggregation** | Combine multiple public keys into aggregate |
| **Aggregate Key Display** | Show as Bitcoin address (Bech32m) and Nostr npub |
| **Nonce Generation** | Generate and display secure nonces |
| **Partial Signing** | Create partial signatures from private key + nonces |
| **Signature Aggregation** | Combine partial signatures into final Schnorr signature |
| **Verification** | Verify aggregated signatures |

### User Flows

**Bitcoin Multi-Sig Setup**:
1. User generates their key pair
2. User inputs co-signer public keys (paste or scan QR)
3. App computes aggregate public key
4. App displays Taproot address (`bc1p...`)
5. User can initiate signing ceremony

**Nostr Shared Account**:
1. User generates their key pair
2. User inputs collaborator public keys
3. App computes aggregate public key
4. App displays `npub` for the shared identity
5. User can sign Nostr events collaboratively

### Platform Considerations

| Platform | Notes |
|----------|-------|
| **iOS/iPadOS** | Primary focus; camera for QR scanning |
| **macOS** | Full feature parity; keyboard shortcuts |
| **visionOS** | Adapted UI; spatial considerations |
| **tvOS** | Limited input; focus on display/verification |

---

## Phase Dependencies & Sequencing

```
Phase 4 (Bech32) ──► MuSig2 App Development
                           │
                           ├──► Core UI/UX
                           ├──► Key Management
                           ├──► Signing Ceremony
                           └──► Platform Adaptation
```

**Recommended order**:
1. **Core data models** — key types, ceremony state
2. **macOS app** — fastest iteration for development
3. **iOS adaptation** — primary user platform
4. **Other platforms** — tvOS, visionOS, watchOS (if applicable)

---

## Phase-Specific Metrics

| Metric | Target |
|--------|--------|
| Platforms supported | 5 (iOS, macOS, iPadOS, visionOS, tvOS) |
| User flows complete | 2 (Bitcoin, Nostr) |
| MuSig2 API coverage | 100% of public API demonstrated |
| App Store ready | Not required (demo app) |

---

## Technical Notes

**SwiftUI Architecture**:
- MVVM pattern for testability
- Combine/async-await for ceremony coordination
- Shared code between platforms via SwiftUI
- Platform-specific features (camera, etc.) isolated

**Integration with Library**:
```swift
// Example usage in app
let myKey = try P256K.Schnorr.PrivateKey()
let aggregateKey = try P256K.MuSig.aggregate([myKey.publicKey, peerPublicKey])

// Display as Bitcoin address (Phase 4 Bech32m)
let address = P256K.Bitcoin.Address.taproot(xOnlyKey: aggregateKey.xonly, network: .mainnet)

// Display as Nostr npub (Phase 4 Nostr encoding)
let npub = P256K.Nostr.npub(publicKey: aggregateKey)
```

---

## Backlog (Future Apps)

These apps are deferred to backlog per user decision:

| App | Purpose | Status |
|-----|---------|--------|
| **ECDSA Signing CLI** | Command-line signing tool | Backlog |
| **Schnorr Verifier** | Signature verification utility | Backlog |
| **Address Generator** | Bitcoin/Nostr address creation | Backlog |
| **MuSig2 CLI** | Command-line MuSig2 ceremony | Backlog |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| SwiftUI cross-platform differences | Inconsistent UX | Isolate platform-specific code; test on all platforms early |
| MuSig2 ceremony complexity | User confusion | Strong UX guidance; step-by-step wizard |
| Key security in demo app | Users may misuse for real funds | Clear warnings; consider "demo mode" flag |
| tvOS input limitations | Feature gaps | Focus on verification/display; signing on other platforms |
