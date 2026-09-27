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
# Exit codes (scheme patterned on Scripts/rewrite-docc-shared-paths.swift):
#   1 usage error   2 no .swiftinterface files found
#   3 residual libsecp256k1 import or invalid P256K.-qualified spelling
#   4 residue scan itself failed (grep error, not a clean pass)
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

# Rewrite invalid P256K.P256K spellings the older emitters produce, e.g.
#   extension P256K.P256K   ->  extension P256K
#   ... P256K.P256K.Foo     ->  ... P256K.Foo
#   P256K.Digest            ->  Digest
# and drop the now-unloadable 'import libsecp256k1'.
#
# TOPLEVEL is every public type living at module scope — the emitter spells
# references to them as P256K.<Name>, which is unreadable. The word
# boundaries ([[:<:]]/[[:>:]]) keep the rule off unrelated spellings such as
# MyP256K.Digest or P256K.Digestible, and members nested inside the enum
# keep their qualifier legitimately — P256K.Signing.PublicKey is already the
# correct spelling. The same list feeds the residue assert below, which must
# stay bounded to it for exactly that reason: a bare P256K. match would flag
# the script's own correct output. Entries cover Embedded-conditional
# declarations too (CryptoKitMetaError, RSAPSSSPKIError) — harmless when
# never emitted.
TOPLEVEL='secp256k1Error|Digest|CryptoKitError|CryptoKitASN1Error|CryptoKitMetaError|RSAPSSSPKIError|SHA256Digest|SHA256|XonlyKeyImplementation|HashDigest|SharedSecret|PublicKeyImplementation|PrivateKeyImplementation|UInt256|Int256|UInt128|Int128|_UInt256Words|_Int256Words'

find "$XCFRAMEWORK" -name '*.swiftinterface' -print0 \
  | xargs -0 sed -E -i '' \
      -e 's/extension P256K\.P256K/extension P256K/g' \
      -e 's/P256K\.P256K\./P256K\./g' \
      -e "s/[[:<:]]P256K\\.($TOPLEVEL)[[:>:]]/\\1/g" \
      -e '/import libsecp256k1/d'

# Assert the artifact no longer carries either known-unconsumable construct:
# an import consumers cannot resolve, or a module-qualified spelling for a
# top-level type — the doubled P256K.P256K qualifier or P256K.<TOPLEVEL name>.
# P256K::P256K selectors are the valid Xcode 27+ spelling (hence the [^:]
# guard), and a text check cannot tell a new top-level type apart from a
# nested enum member — that case is only caught by a real consumer build.
# grep exits 0 = match (residue), 1 = clean, >1 = grep itself failed; the
# last case must fail the release rather than read as "clean".
assert_no_residue() {
    local pattern="$1" label="$2" status=0
    grep -rlE --include='*.swiftinterface' "$pattern" "$XCFRAMEWORK" || status=$?
    case "$status" in
        0) echo "error: $label remains after rewrite (files listed above)" >&2; exit 3 ;;
        1) ;;
        *) echo "error: grep failed scanning $XCFRAMEWORK (status $status)" >&2; exit 4 ;;
    esac
}

assert_no_residue 'libsecp256k1' 'libsecp256k1 reference'
assert_no_residue '(^|[^:])P256K\.P256K([^A-Za-z0-9_]|$)' 'doubled P256K.P256K qualifier'
assert_no_residue "(^|[^:])P256K\\.($TOPLEVEL)([^A-Za-z0-9_]|\$)" 'P256K.-qualified top-level type'
