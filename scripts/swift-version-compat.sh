#!/bin/bash
#
# Swift Version Compatibility Tester
# Uses binary search with swiftly to find minimum Swift version for each release
#

set -e

SWIFT_VERSIONS=("5.7" "5.8" "5.9" "5.10" "6.0")
RESULTS_FILE="swift-compat-results.csv"
REPO_URL="https://github.com/21-DOT-DEV/swift-secp256k1"

# Get stable releases (first of each minor version for efficiency)
get_test_releases() {
    git tag --sort=v:refname | grep -v -E '(prerelease|alpha|beta|rc)' | \
    awk -F. '{
        key = $1"."$2
        if (key != prev) {
            print
            prev = key
        }
    }'
}

# Test if a release builds with a specific Swift version
test_build() {
    local release="$1"
    local swift_version="$2"
    local temp_dir=$(mktemp -d)
    
    echo -n "  Testing $release with Swift $swift_version... "
    
    # Switch Swift version
    swiftly use "$swift_version" 2>/dev/null || {
        echo "SKIP (Swift $swift_version not installed)"
        rm -rf "$temp_dir"
        return 2
    }
    
    # Create a test package that depends on the release
    cat > "$temp_dir/Package.swift" << EOF
// swift-tools-version:${swift_version}
import PackageDescription

let package = Package(
    name: "CompatTest",
    dependencies: [
        .package(url: "$REPO_URL", exact: "$release")
    ],
    targets: [
        .target(name: "CompatTest", dependencies: [
            .product(name: "P256K", package: "swift-secp256k1")
        ])
    ]
)
EOF
    
    mkdir -p "$temp_dir/Sources/CompatTest"
    echo "import P256K" > "$temp_dir/Sources/CompatTest/main.swift"
    
    # Try to resolve and build
    if (cd "$temp_dir" && swift package resolve 2>/dev/null && swift build 2>/dev/null); then
        echo "PASS"
        rm -rf "$temp_dir"
        return 0
    else
        echo "FAIL"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Binary search to find minimum Swift version
find_min_swift_version() {
    local release="$1"
    local low=0
    local high=$((${#SWIFT_VERSIONS[@]} - 1))
    local min_version=""
    
    echo "Testing release: $release"
    
    while [ $low -le $high ]; do
        local mid=$(( (low + high) / 2 ))
        local version="${SWIFT_VERSIONS[$mid]}"
        
        if test_build "$release" "$version"; then
            min_version="$version"
            high=$((mid - 1))
        else
            low=$((mid + 1))
        fi
    done
    
    if [ -n "$min_version" ]; then
        echo "  → Minimum Swift version: $min_version"
        echo "$release,$min_version" >> "$RESULTS_FILE"
    else
        echo "  → No compatible Swift version found in range"
        echo "$release,NONE" >> "$RESULTS_FILE"
    fi
    echo ""
}

# Main
main() {
    echo "Swift Version Compatibility Tester for swift-secp256k1"
    echo "======================================================="
    echo ""
    echo "Swift versions to test: ${SWIFT_VERSIONS[*]}"
    echo ""
    
    # Check swiftly
    if ! command -v swiftly &> /dev/null; then
        echo "Error: swiftly not found. Install from https://github.com/swiftlang/swiftly"
        exit 1
    fi
    
    # Initialize results file
    echo "release,min_swift_version" > "$RESULTS_FILE"
    
    # Get releases to test
    releases=($(get_test_releases))
    echo "Testing ${#releases[@]} releases (first of each minor version):"
    printf '%s\n' "${releases[@]}"
    echo ""
    
    # Install required Swift versions
    echo "Ensuring Swift versions are installed..."
    for version in "${SWIFT_VERSIONS[@]}"; do
        if ! swiftly use "$version" 2>/dev/null; then
            echo "Installing Swift $version..."
            swiftly install "$version" || echo "Warning: Could not install Swift $version"
        fi
    done
    echo ""
    
    # Test each release
    for release in "${releases[@]}"; do
        find_min_swift_version "$release"
    done
    
    echo "Results saved to $RESULTS_FILE"
    echo ""
    echo "Generating grouped ranges..."
    
    # Generate grouped output
    awk -F, 'NR>1 {
        if ($2 != prev_ver && NR > 2) {
            printf "`%s ..< %s` | %s\n", start_rel, $1, prev_ver
        }
        if ($2 != prev_ver) {
            start_rel = $1
        }
        prev_ver = $2
        last_rel = $1
    }
    END {
        printf "`%s ...` | %s\n", start_rel, prev_ver
    }' "$RESULTS_FILE"
}

main "$@"
