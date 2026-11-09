# Signing Fixed-Size Messages with Schnorr

@Metadata {
    @TitleHeading("How-to Guide")
}

Produce and verify a BIP-340 Schnorr signature over an exactly-32-byte message — the flow Nostr event signing, Taproot sighashes, and most "sign the hash" protocols specify.

## Overview

The 32-byte discipline is a *protocol* requirement, not a BIP-340 one. BIP-340 itself permits messages of any length; what protocols built on it actually sign is almost always a 32-byte commitment — a Nostr event id, a Taproot sighash, a message hash. ``P256K/Schnorr/PrivateKey`` separates those intents by name so the wrong one cannot happen silently:

- `signature(message:)` — exactly 32 bytes, or it throws ``secp256k1Error/incorrectParameterSize`` before any key material is touched.
- `signature(for:)` — a pre-computed `Digest` (for example a ``SHA256Digest``), signed at its natural length.
- `signature(customMessage:)` — arbitrary-length input, for protocols whose spec genuinely signs unhashed bytes. Prefer the 32-byte discipline — with a BIP-340 tagged hash for domain separation — unless the signed protocol defines its own.

Every produced signature is verified against the signer's `xonly` identity before it is returned (BIP-340 footnote 14's verify-after-sign check), so a corrupt signature cannot escape through a signing call.

### Hash, sign, verify

The recipe a Nostr event signer performs: serialize the event, hash the serialization to the 32-byte event id, sign it, and publish the signature beside the x-only public key.

```swift
import Foundation
import P256K

let privateKey = try P256K.Schnorr.PrivateKey()

// The protocol's committed message is a 32-byte hash — or becomes one.
let messageData = "Vires in Numeris.".data(using: .utf8)!
let messageHash = SHA256.hash(data: messageData)  // exactly 32 bytes

// Sign — fresh auxiliary randomness is drawn internally.
let signature = try privateKey.signature(message: messageHash)

// Verify against the signer's x-only public identity — BIP-340's
// notion of "the public key", and what external verifiers consume.
let isValid = privateKey.xonly.isValid(signature, for: messageHash)  // true
```

A wrong-length input never reaches the signature step:

```swift
// A non-32-byte input through the 32-byte method throws — it does not
// silently truncate or pad.
let unhashed100 = Data(repeating: 0xAB, count: 100)
try privateKey.signature(message: unhashed100)
// ^ throws secp256k1Error.incorrectParameterSize
```

### Choosing the signing method

| Method | Input | Auxiliary randomness |
|---|---|---|
| `signature(for:)` | any `Digest` | fresh |
| `signature(for:auxiliaryRand:)` | any `Digest` | caller's, exactly 32 bytes |
| `signature(message:)` | exactly 32 bytes | fresh |
| `signature(message:auxiliaryRand:)` | exactly 32 bytes | caller's, exactly 32 bytes |
| `signature(customMessage:)` | any length, including empty | fresh |
| `signature(customMessage:auxiliaryRand:)` | any length, including empty | caller's, exactly 32 bytes |

Caller-supplied auxiliary randomness exists mainly to reproduce published test vectors — a zeroed 32-byte container reproduces BIP-340's all-zero-auxiliary case (vector index 0). For production signing, omit the parameter: the fresh randomness drawn internally is BIP-340's fault-injection hedge, and a fixed auxiliary value trades that protection away for determinism. There is no `nil` form — "deterministic, zero-randomness nonces" is only expressible deliberately, via an explicit zero container.

### Domain separation

When your own protocol signs hashes, give the hash a BIP-340 tag so a signature for one purpose can never verify as another:

```swift
let eventId = SHA256.taggedHash(
    tag: "my-protocol/event".data(using: .utf8)!,
    data: messageData
)
let signature = try privateKey.signature(message: eventId)
```

Protocols like Nostr that commit to an *untagged* SHA-256 of a canonical serialization need the plain `SHA256.hash` shown above instead — match the signed protocol's specification exactly. And a protocol that genuinely signs raw bytes (BIP-340's ["Messages of Arbitrary Size"][bip-340]) signs through `signature(customMessage:)`, which accepts any length including zero.

> Note: `SHA256` here is ``P256K``'s own hasher — `SHA256.hash` binds to it unambiguously even beside `import CryptoKit`, since expression position resolves by overload. The collision only surfaces in *type* position — a generic argument like `HKDF<SHA256>` or a `let x: SHA256` annotation — where both modules' hashers are candidates; qualify the CryptoKit side there (`CryptoKit.SHA256`, or `Crypto.SHA256` under `import Crypto`), or bind this side file-wide with `import enum P256K.SHA256` (`P256K.SHA256` is not a usable spelling — the `P256K` enum shares the module's name).

### What throws, and what cannot

Two reachable failures throw ``secp256k1Error/incorrectParameterSize``: a `message` that is not exactly 32 bytes, and an `auxiliaryRand` that is not exactly 32 bytes. An upstream signing failure after input validation is unreachable — it can only indicate output corruption or a library defect — so it reports through ``P256K/setInvariantViolationHandler(_:)`` and terminates rather than returning a bad signature.

## See Also

- <doc:GettingStarted>
- <doc:DerivingKeysFromSharedSecrets>
- <doc:MuSig2MultiSignatures>
- <doc:WorkingWithKeys>
- <doc:SecurityConsiderations>
- ``P256K/Schnorr/PrivateKey``
- ``P256K/Schnorr/XonlyKey``
- ``P256K/Schnorr/SchnorrSignature``
- ``SHA256``

[bip-340]: https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki
