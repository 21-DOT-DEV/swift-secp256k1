#!/usr/bin/env bash
# verify-p256k-xcframework.sh <P256K.xcframework> <platform>...
# Gates the artifact that ships; <platform>... is the pipeline's archive
# list (generic/platform= names) and the slice count must match it.
# Why each check exists: AGENTS.md, "XCFramework toolchain pins".
#   unsigned: no slice may carry _CodeSignature — an archive-time signature is
#   invalidated by -create-xcframework (CODE_SIGNING_ALLOWED=NO, Release.xcconfig).
#   exports: only _$s* and _P256KVersion* may be global, tripwiring exported-symbols.txt.
#   consumers: Tests/XCFrameworkTests runs on macOS and builds+links for each platform
#   against only the shipped interfaces (no libsecp256k1 module) — catches a leaked C
#   import, a hollow or missing slice, and a missing standard arch.
# Exit: 0 pass · 1 detected defect or usage · tool failures keep their own code.
set -euo pipefail

XCFRAMEWORK=$(cd "${1:?usage: $0 <path-to-P256K.xcframework> <platform>...}" && pwd)
shift
ROOT=$(cd "$(dirname "$0")/.." && pwd)

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

die() {
    echo "error: $*" >&2
    exit 1
}

bins=("$XCFRAMEWORK"/*/P256K.framework/P256K)
((${#bins[@]} == $#)) || die "platform list names $# platform(s) but the artifact ships ${#bins[@]} slice(s) — argument drifted from what was archived"

# Signatures live at _CodeSignature (iOS-style) or Versions/A/_CodeSignature (macOS-style);
# compgen prints the offending paths as evidence before die.
if compgen -G "$XCFRAMEWORK/*/P256K.framework/_CodeSignature" ||
    compgen -G "$XCFRAMEWORK/*/P256K.framework/Versions/A/_CodeSignature"; then
    die "slice carries a code signature — the artifact should ship unsigned"
fi

# nm -A prefixes each symbol with its file and arch, naming the slice it leaked from.
syms=$(nm -gUjA -arch all "${bins[@]}")

if grep -Ev '^$|: (_\$s|_P256KVersion(Number|String)$)' <<<"$syms"; then
    die "non-allowlisted exports (listed above)"
fi

# Stage the CI-only consumer package: manifest, the real test suite, and the artifact at the path the manifest expects.
CONSUMER="$WORKDIR/consumer"
mkdir -p "$CONSUMER/Tests"
cp "$ROOT/Scripts/XCFrameworkTest/Package.swift" "$CONSUMER/Package.swift"
cp -R "$ROOT/Tests/XCFrameworkTests" "$CONSUMER/Tests/XCFrameworkTests"
ln -s "$XCFRAMEWORK" "$CONSUMER/P256K.xcframework"
cd "$CONSUMER"
export SWIFT_FORCE_MODULE_LOADING=only-interface

# SwiftPM's scheme for Scripts/XCFrameworkTest/Package.swift (name: + "-Package").
scheme=swift-secp256k1-xcframework-consumer-Package

echo "consumer test: macOS (swift test)"
swift test

for dest in "$@"; do
    echo "consumer build: $dest"
    xcodebuild build-for-testing -scheme "$scheme" -destination "generic/platform=$dest" -derivedDataPath "$WORKDIR/dd" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO -quiet
done

echo "verified: ${#bins[@]} binaries — exports allowlisted, consumer builds passed"
