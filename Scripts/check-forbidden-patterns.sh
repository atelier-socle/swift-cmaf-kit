#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# check-forbidden-patterns.sh
#
# Verifies that the 9 forbidden Swift patterns of the Atelier Socle ecosystem
# are absent from the codebase. Called at session start and session end.
#
# The 9 patterns enforced (per CLAUDE.md):
#   1. @unchecked Sendable     (except LockedState)
#   2. nonisolated(unsafe)
#   3. @preconcurrency
#   4. Task.detached
#   5. try!                    (excluding comments)
#   6. fatalError(
#   7. swiftlint:disable
#   8. import XCTest           (in Tests/ only — Swift Testing only)
#   9. import os               (must be canImport-guarded)

set -euo pipefail
cd "$(dirname "$0")/.."

EXIT=0

check() {
    local pattern="$1"
    local exclude="$2"
    local label="$3"
    local matches
    if [ -n "$exclude" ]; then
        matches=$(grep -rEn "$pattern" Sources/ 2>/dev/null | grep -v "$exclude" || true)
    else
        matches=$(grep -rEn "$pattern" Sources/ 2>/dev/null || true)
    fi
    if [ -n "$matches" ]; then
        echo "✗ $label"
        echo "$matches" | head -3
        EXIT=1
    else
        echo "✓ $label"
    fi
}

echo "→ Forbidden patterns check"

check '@unchecked Sendable' 'LockedState' '@unchecked Sendable (LockedState exempt)'
check 'nonisolated\(unsafe\)' '' 'nonisolated(unsafe)'
check '@preconcurrency' '' '@preconcurrency'
check 'Task\.detached' '' 'Task.detached'
check 'fatalError\(' '' 'fatalError('
check 'swiftlint:disable' '' 'swiftlint:disable'

# try! (excluding line- and block-style comments)
TRY_BANG=$(grep -rEn 'try!' Sources/ 2>/dev/null | grep -vE '//|/\*' || true)
if [ -n "$TRY_BANG" ]; then
    echo "✗ try!"
    echo "$TRY_BANG" | head -3
    EXIT=1
else
    echo "✓ try!"
fi

# import XCTest in Tests
if grep -rn 'import XCTest' Tests/ 2>/dev/null | grep -v '^$' >/dev/null; then
    echo "✗ import XCTest in Tests/"
    EXIT=1
else
    echo "✓ import XCTest absent from Tests/"
fi

# bare import os (must be canImport-guarded)
if grep -rEn '^import os' Sources/ 2>/dev/null | grep -v 'canImport' >/dev/null; then
    echo "✗ bare 'import os' (must be guarded by canImport)"
    EXIT=1
else
    echo "✓ import os (all canImport-guarded)"
fi

if [ "$EXIT" -ne 0 ]; then
    echo ""
    echo "✗✗ Forbidden pattern violations detected"
    exit 1
fi

echo ""
echo "✓✓ All 9 forbidden patterns clean"
exit 0
