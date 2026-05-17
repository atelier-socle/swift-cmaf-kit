#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# Generate per-target DocC archives for CMAFKit and CMAFKitCLI, then merge
# them into a single ./docs/swift-cmaf-kit.doccarchive suitable for GitHub Pages.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p docs

echo "→ Generating CMAFKit.doccarchive"
swift package --allow-writing-to-directory ./docs \
    generate-documentation \
    --target CMAFKit \
    --output-path ./docs/CMAFKit.doccarchive

echo "→ Generating CMAFKitCLI.doccarchive"
swift package --allow-writing-to-directory ./docs \
    generate-documentation \
    --target CMAFKitCLI \
    --output-path ./docs/CMAFKitCLI.doccarchive

if command -v xcrun >/dev/null 2>&1; then
    echo "→ Merging archives via xcrun docc merge"
    rm -rf ./docs/swift-cmaf-kit.doccarchive
    xcrun docc merge \
        ./docs/CMAFKit.doccarchive \
        ./docs/CMAFKitCLI.doccarchive \
        --output-path ./docs/swift-cmaf-kit.doccarchive
    echo "✓ Merged archive at ./docs/swift-cmaf-kit.doccarchive"
else
    echo "⚠️ xcrun not available (Linux?). Per-target archives generated; merge step skipped."
    echo "   The merge step requires macOS; CI macOS jobs perform it for deployment."
fi
