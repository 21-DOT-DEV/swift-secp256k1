#!/usr/bin/env bash
# Workaround for Swift issue SR-14195 / github.com/swiftlang/swift/issues/56573:
# when a module has the same name as a type it contains (enum P256K in module
# P256K), the emitted .swiftinterface module-qualifies references in a way the
# compiler cannot read back ("'P256K' is not a member type of enum
# 'P256K.P256K'"). Xcode 27's emitter uses the unambiguous module-selector
# spelling (P256K::P256K); older emitters need the rewrites below.
#
# Also strips `import libsecp256k1`: no interface declaration references the C
# module's types, and consumers of the XCFramework have no module map for it —
# leaving the import in place breaks `import P256K` for them.
#
# Usage: fix-p256k-module-interfaces.sh <path-to-P256K.xcframework>
#
# Exit codes (mirroring Scripts/rewrite-docc-shared-paths.swift):
#   1 usage error   2 no .swiftinterface files found
#   3 residual libsecp256k1 import or P256K.P256K qualifier after rewrite
set -euo pipefail

XCFRAMEWORK="${1:-}"
if [[ -z "$XCFRAMEWORK" || ! -d "$XCFRAMEWORK" ]]; then
    echo "usage: $0 <path-to-P256K.xcframework>" >&2
    exit 1
fi

if ! find "$XCFRAMEWORK" -name '*.swiftinterface' -print -quit | grep -q .; then
    echo "error: no .swiftinterface files under $XCFRAMEWORK" >&2
    exit 2
fi

find "$XCFRAMEWORK" -name '*.swiftinterface' -print0 \
  | xargs -0 sed -i '' \
      -e 's/extension P256K\.P256K/extension P256K/g' \
      -e 's/P256K\.P256K\./P256K\./g' \
      -e 's/[[:<:]]P256K\.secp256k1Error[[:>:]]/secp256k1Error/g' \
      -e 's/[[:<:]]P256K\.Digest[[:>:]]/Digest/g' \
      -e 's/[[:<:]]P256K\.CryptoKitError[[:>:]]/CryptoKitError/g' \
      -e 's/[[:<:]]P256K\.CryptoKitASN1Error[[:>:]]/CryptoKitASN1Error/g' \
      -e 's/[[:<:]]P256K\.SHA256Digest[[:>:]]/SHA256Digest/g' \
      -e 's/[[:<:]]P256K\.XonlyKeyImplementation[[:>:]]/XonlyKeyImplementation/g' \
      -e 's/[[:<:]]P256K\.HashDigest[[:>:]]/HashDigest/g' \
      -e 's/[[:<:]]P256K\.SharedSecret[[:>:]]/SharedSecret/g' \
      -e 's/[[:<:]]P256K\.PublicKeyImplementation[[:>:]]/PublicKeyImplementation/g' \
      -e 's/[[:<:]]P256K\.PrivateKeyImplementation[[:>:]]/PrivateKeyImplementation/g' \
      -e 's/[[:<:]]P256K\.UInt256[[:>:]]/UInt256/g' \
      -e 's/[[:<:]]P256K\.Int256[[:>:]]/Int256/g' \
      -e 's/[[:<:]]P256K\.UInt128[[:>:]]/UInt128/g' \
      -e 's/[[:<:]]P256K\.Int128[[:>:]]/Int128/g' \
      -e 's/[[:<:]]P256K\.SIMDWordsInteger[[:>:]]/SIMDWordsInteger/g' \
      -e 's/[[:<:]]P256K\.SIMDWrapper[[:>:]]/SIMDWrapper/g' \
      -e 's/[[:<:]]P256K\.Vector[[:>:]]/Vector/g' \
      -e 's/[[:<:]]P256K\._UInt256Words[[:>:]]/_UInt256Words/g' \
      -e 's/[[:<:]]P256K\._Int256Words[[:>:]]/_Int256Words/g' \
      -e '/import libsecp256k1/d'

# Assert the artifact no longer carries either known-unconsumable construct:
# an import consumers cannot resolve, or the ambiguous dot-form qualifier.
# P256K::P256K module selectors are the valid Xcode 27+ spelling and are
# intentionally left alone — hence the [^:] guard on the residue check.
if find "$XCFRAMEWORK" -name '*.swiftinterface' -print0 \
     | xargs -0 grep -l 'libsecp256k1' > /dev/null 2>&1; then
    echo "error: libsecp256k1 reference remains after rewrite" >&2
    exit 3
fi
if find "$XCFRAMEWORK" -name '*.swiftinterface' -print0 \
     | xargs -0 grep -lE '(^|[^:])P256K\.P256K' > /dev/null 2>&1; then
    echo "error: P256K.P256K qualifier remains after rewrite" >&2
    exit 3
fi
