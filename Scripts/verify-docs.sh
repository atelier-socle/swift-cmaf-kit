#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# Build DocC and fail on any warning.
set -euo pipefail

cd "$(dirname "$0")/.."

for target in CMAFKit CMAFKitCLI; do
    echo "→ Verifying DocC for $target"
    output=$(swift package generate-documentation --target "$target" 2>&1)
    if echo "$output" | grep -qE "warning|error"; then
        echo "❌ DocC issues for $target:"
        echo "$output" | grep -E "warning|error"
        exit 1
    fi
    echo "✓ $target — 0 warnings"
done
