# Deriving Keys from a Shared Secret

@Metadata {
    @TitleHeading("How-to Guide")
}

Turn the ``SharedSecret`` produced by ECDH key agreement into symmetric key material with HKDF — the composition protocols like Nostr's [NIP-44 v2][nip-44] specify.

## Overview

``P256K/KeyAgreement/PrivateKey/sharedSecretFromKeyAgreement(with:format:)`` returns the **raw serialized EC point**, not a usable key. In the default `.compressed` format that is 33 bytes — a `0x02`/`0x03` parity prefix followed by the 32-byte x coordinate — and a KDF is what turns that point into key material. Which KDF, which inputs, and which salt are decisions the *protocol* you implement makes, not the library.

The recipe's two moving parts:

1. **Slice the prefix byte** to recover the bare 32-byte shared x coordinate.
2. **Feed the x coordinate — unhashed — to HKDF**, letting the protocol's domain separation live in the `salt` parameter.

A ``SharedSecret``'s bytes are never exposed implicitly — printing one reports only its byte count — so byte access is the explicit opt-in `withUnsafeBytes(_:)` or the `byteArray` convenience used below.

### The recipe

```swift
import CryptoKit  // on Linux: `import Crypto` — from apple/swift-crypto,
                  // which your package must add as its own dependency
                  // (P256K vendors it internally; it exports no `Crypto` module)
import Foundation
import P256K

let privateKey = try P256K.KeyAgreement.PrivateKey()
let peerPrivateKey = try P256K.KeyAgreement.PrivateKey()

// Both parties derive the identical 33-byte compressed point.
let sharedSecret = privateKey.sharedSecretFromKeyAgreement(with: peerPrivateKey.publicKey)

// 1. Borrow the shared secret's bytes in scope; slice off the
//    compressed-point prefix byte → the bare 32-byte shared x,
//    fed *unhashed* into HKDF as the input key material.
let inputKeyMaterial = sharedSecret.withUnsafeBytes { bytes in
    SymmetricKey(data: bytes.dropFirst())
}

// 2. Derive with the protocol's domain-separation salt. NIP-44 v2's
// conversation key is exactly
// HKDF-extract(sha256, ikm = shared_x, salt = utf8("nip44-v2")).
// (CryptoKit. qualification is required: P256K also exports a SHA256 —
// under `import Crypto` the same type is spelled Crypto.SHA256.)
let conversationKey = HKDF<CryptoKit.SHA256>.extract(
    inputKeyMaterial: inputKeyMaterial,
    salt: Data("nip44-v2".utf8)
)
```

`conversationKey` is a 32-byte pseudorandom key — in NIP-44's terms, the *conversation key* that per-message keys expand from.

The scoped borrow is the recipe's shape because nothing intermediate is copied: `SymmetricKey` pulls the input into its own storage inside the borrow, so the secret's bytes never sit in an un-zeroed array. `byteArray` is the convenience form for when you need the raw bytes themselves — comparing both peers' x coordinate, say — accepting a plain `[UInt8]` copy that is never zeroed:

```swift
let sharedX = Data(sharedSecret.byteArray.dropFirst())  // 32 bytes
```

### `extract` versus `deriveKey`

HKDF is two stages: `extract` condenses input keying material and a salt into a pseudorandom key (PRK); `expand` stretches a PRK into output keying material of any length, keyed by an `info` string.

- `HKDF.extract` alone is what NIP-44 names its conversation key — the protocol then runs its own `expand` calls with per-message `info` values.
- `HKDF.deriveKey` is the extract+expand convenience for the common case of deriving one symmetric key directly:

```swift
let sessionKey = HKDF<CryptoKit.SHA256>.deriveKey(
    inputKeyMaterial: inputKeyMaterial,
    salt: Data("my-protocol-v1".utf8),   // the protocol's domain separator
    info: Data("session".utf8),          // the application context
    outputByteCount: 32
)
```

Deriving several keys from one shared secret calls `extract` once and `expand` per key with a distinct `info` — see [RFC 5869][rfc-5869] for the construction CryptoKit and swift-crypto implement.

> Important: This recipe is an **example composition** of the library's ECDH output with a standard KDF — not a Nostr implementation. NIP-44 v2 layers its own padding, nonce, and message-authentication scheme on top of the conversation key; work from [nips/44.md][nip-44] if you are implementing it.

### Choosing the slice by format

The `.compressed` default yields `0x02/0x03 ‖ x` — `dropFirst()` leaves the x coordinate. If a protocol forces `.uncompressed` (65 bytes, `0x04 ‖ x ‖ y`), the x coordinate is the 32 bytes following the `0x04` prefix — 0-indexed bytes 1–32 — so take `dropFirst().prefix(32)`. Never take the *last* 32 bytes: on the uncompressed layout that yields the **y** coordinate, a different and incompatible input to the KDF.

```swift
let uncompressedInputKeyMaterial = privateKey.sharedSecretFromKeyAgreement(
    with: peerPrivateKey.publicKey,
    format: .uncompressed
).withUnsafeBytes { bytes in
    SymmetricKey(data: bytes.dropFirst().prefix(32))
}
// == inputKeyMaterial — same point, wider encoding
```

### Production considerations

**Authenticate the peer's public key.** ECDH alone binds two keys to a shared value but says nothing about *whose* key you used — a man-in-the-middle substituting their own public key silently derives a different secret with each side. Pair the derivation with a signature or out-of-band fingerprint check; see <doc:EllipticCurveDiffieHellman> for the full discussion.

**Do not pre-hash the shared point** unless the protocol says so. Feeding `SHA256.hash(sharedX)` into HKDF is a different input than the spec's `ikm = shared_x` and produces keys no interoperable implementation can reproduce — the KDF's own extraction step is where hashing belongs.

**`SharedSecret` prints safely — its derived key does not.** `SharedSecret` renders as `SharedSecret representation contains N bytes.` and never its bytes, so instrumenting the agreement half is safe by construction. The recipe's *output* carries no such guarantee: CryptoKit's `HashedAuthenticationCode` — the `extract` result above — prints its full key bytes in hex, so never log `conversationKey`. (`deriveKey`'s `SymmetricKey` result is opaque, in contrast.)

## See Also

- <doc:EllipticCurveDiffieHellman>
- <doc:SilentPayments>
- <doc:SigningFixedSizeMessages>
- <doc:SecurityConsiderations>
- ``SharedSecret``
- ``P256K/KeyAgreement/PrivateKey``
- ``SHA256``

[nip-44]: https://github.com/nostr-protocol/nips/blob/master/44.md
[rfc-5869]: https://datatracker.ietf.org/doc/html/rfc5869
