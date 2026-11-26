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
#   import, a hollow or missing slice, and a missing standard arch — then runs on an
#   iOS Simulator when that slice is archived, catching a slice that links but misbehaves.
# Exit: 0 pass · 1 detected defect or usage · tool failures keep their own code.
set -euo pipefail

XCFRAMEWORK=$(cd "${1:?usage: $0 <path-to-P256K.xcframework> <platform>...}" && pwd)
shift
ROOT=$(cd "$(dirname "$0")/.." && pwd)

WORKDIR=$(mktemp -d)
# Set only for a simulator that was Shutdown when picked; any other state may belong to someone else.
booted_sim=''
cleanup() {
    [[ -z "$booted_sim" ]] || xcrun simctl shutdown "$booted_sim" >/dev/null 2>&1 || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

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

# build-for-testing proves the simulator slice links, not that it runs; no eligible iPhone fails the gate.
# Newest iOS runtime whose major.minor ≤ the active SDK's (never one for a newer Xcode than the pin), compared
# numerically; single-device-type runtimes are skipped by type count because their IDs can look general (iOS-27-1).
if [[ " $* " == *" iOS Simulator "* ]]; then
    command -v jq >/dev/null || die "jq is required to select and judge the iOS Simulator run"
    sdk=$(xcrun --sdk iphonesimulator --show-sdk-version)
    sims=$(xcrun simctl list --json)
    pick=$(jq -r --arg sdk "$sdk" '
        def ver: split(".") | map(tonumber);
        def major_minor: (. + [0, 0])[:2];
        ($sdk | ver | major_minor) as $cap | .devices as $devices
        | [.runtimes[] as $r
           | select($r.platform == "iOS" and $r.isAvailable and ($r.supportedDeviceTypes | length) > 1)
           | ($r.version | ver) as $v | select(($v | major_minor) <= $cap)
           | ($devices[$r.identifier] // [])[] | select(.isAvailable and (.name | startswith("iPhone")))
           | {v: $v, version: $r.version, udid, state: (.state | gsub(" "; "_")), name}]
        | max_by(.v) // empty | "\(.udid) \(.state) \(.name), iOS \(.version)"' <<<"$sims") || pick=''
    if [[ -z "$pick" ]]; then
        echo "iOS runtimes and devices simctl reported:" >&2
        jq -r 'def err: if .availabilityError then " (\(.availabilityError))" else "" end;
            def rt: ltrimstr("com.apple.CoreSimulator.SimRuntime.");
            (.runtimes[]? | select(.platform == "iOS")
             | "  runtime \(.identifier | rt) \(.version) available=\(.isAvailable) device_types=\(.supportedDeviceTypes | length)\(err)"),
            (.devices // {} | to_entries[] | select(.key | contains("SimRuntime.iOS-")) | (.key | rt) as $rt
             | .value[] | "  device \($rt) \(.name) \(.state) available=\(.isAvailable)\(err)")' <<<"$sims" >&2 || true
        die "iOS Simulator slice archived but no available iPhone simulator on an iOS runtime ≤ the $sdk SDK"
    fi
    read -r sim state label <<<"$pick"
    if [[ "$state" == Shutdown ]]; then
        booted_sim=$sim
    fi
    echo "consumer test: iOS Simulator ($label)"

    # -collect-test-diagnostics never: skip the simulator sysdiagnose a failing test otherwise waits on.
    result="$WORKDIR/ios-simulator.xcresult"
    for attempt in 1 2; do
        rm -rf "$result"
        rc=0
        xcodebuild test-without-building -scheme "$scheme" -destination "platform=iOS Simulator,id=$sim" -derivedDataPath "$WORKDIR/dd" -resultBundlePath "$result" -collect-test-diagnostics never -quiet || rc=$?

        # The bundle is the only record of failure text: -quiet hides it and $WORKDIR is deleted on exit.
        summary=$(xcrun xcresulttool get test-results summary --path "$result" --compact) || {
            echo "warning: could not read the iOS Simulator result bundle summary" >&2
            summary='{}'
        }
        ((rc != 0)) || break
        jq -r '.testFailures[]? | "failure: \(.testName // "?"): \(.failureText // "" | gsub("\n"; "\n    "))"' <<<"$summary" >&2 || true
        # A runner that never connects is a simulator fault seen on fresh CI VMs, not a test verdict: retry it once,
        # but only when that is every recorded failure, so a real test failure can't be retried into a pass.
        if ((attempt == 1)) && jq -e '[.testFailures[]?.failureText // ""] | length > 0 and all(contains("hung before establishing connection"))' <<<"$summary" >/dev/null; then
            echo "warning: iOS Simulator test runner never connected; retrying once" >&2
        else
            echo "error: iOS Simulator consumer test failed (xcodebuild exit $rc)" >&2
            exit "$rc"
        fi
    done

    # xcodebuild exits 0 when no Swift Testing test ran, so require ≥1 passing test from the bundle.
    jq -e '.result == "Passed" and .passedTests > 0 and .failedTests == 0' <<<"$summary" >/dev/null ||
        die "iOS Simulator run reported no passing test: $(jq -c '{result, totalTestCount, passedTests, failedTests}' <<<"$summary")"
    echo "consumer test: iOS Simulator passed $(jq -r '.passedTests' <<<"$summary") test(s)"
fi

echo "verified: ${#bins[@]} binaries — exports allowlisted, consumer builds passed, consumer tests ran"
