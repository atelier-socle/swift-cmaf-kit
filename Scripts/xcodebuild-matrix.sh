#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# xcodebuild-matrix.sh
#
# Builds CMAFKit on the 7 Apple targets matrix for 0.1.1 per spec
# amendment §3, then runs xcodebuild test on 3 specific Simulator devices.
#
# 7 build targets (generic destinations — avoids Xcode-point-release brittleness):
#   1. macOS native
#   2. Mac Catalyst
#   3. iOS Simulator
#   4. iPadOS Simulator (iPadOS uses iOS destination)
#   5. tvOS Simulator
#   6. watchOS Simulator
#   7. visionOS Simulator
#
# 3 test targets (Xcode 26.4 default Simulator devices):
#   - iPhone 17 Pro
#   - iPad Pro 13-inch (M4)
#   - Apple Vision Pro
#
# The ffprobe-based MV-HEVC E2E test runs as part of the macOS-native
# `swift test` (not via xcodebuild) because ffprobe is only available in
# the macOS runner image.

set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="CMAFKit"
DERIVED_DATA=".build/xcodebuild-matrix-derived-data"

build_target() {
    local label="$1"
    local destination="$2"
    echo ""
    echo "=== Building $label ==="
    if xcodebuild build \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -derivedDataPath "$DERIVED_DATA" \
        -skipPackagePluginValidation \
        -quiet \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee "/tmp/xcodebuild-build-${label// /_}.log" | grep -E 'warning|error' | head -5; then
        :
    fi
    if grep -qE 'error:' "/tmp/xcodebuild-build-${label// /_}.log"; then
        echo "✗ $label: build failed"
        return 1
    fi
    echo "✓ $label: build clean"
}

test_target() {
    local label="$1"
    local destination="$2"
    echo ""
    echo "=== Testing $label ==="
    if xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -derivedDataPath "$DERIVED_DATA" \
        -skipPackagePluginValidation \
        -quiet \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tee "/tmp/xcodebuild-test-${label// /_}.log" | tail -10; then
        :
    fi
    if grep -qE 'error:|FAILED' "/tmp/xcodebuild-test-${label// /_}.log"; then
        echo "✗ $label: tests failed"
        return 1
    fi
    echo "✓ $label: tests pass"
}

# 7 build targets (generic destinations)
build_target "macOS_native"        "generic/platform=macOS"
build_target "Mac_Catalyst"        "generic/platform=macOS,variant=Mac Catalyst"
build_target "iOS_Simulator"       "generic/platform=iOS Simulator"
build_target "iPadOS_Simulator"    "generic/platform=iOS Simulator"
build_target "tvOS_Simulator"      "generic/platform=tvOS Simulator"
build_target "watchOS_Simulator"   "generic/platform=watchOS Simulator"
build_target "visionOS_Simulator"  "generic/platform=visionOS Simulator"

# 3 test targets (Xcode 26.4 default Simulator devices)
test_target "iPhone_17_Pro"             "platform=iOS Simulator,name=iPhone 17 Pro"
test_target "iPad_Pro_13-inch_M4"       "platform=iOS Simulator,name=iPad Pro 13-inch (M4)"
test_target "Apple_Vision_Pro"          "platform=visionOS Simulator,name=Apple Vision Pro"

echo ""
echo "✓✓ xcodebuild matrix complete (7 builds + 3 test runs)"
