#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# verify-no-regression-0_1_1.sh
#
# Session-end discipline check for the 0.1.1 patch.
# Verifies zero regression on the v0.1.0 baseline:
#   - test count ≥ 2896 (the 0.1.0 baseline)
#   - no public symbol from v0.1.0 has been removed
#   - 9 forbidden patterns clean
#   - coverage ≥ 92 % global (when Scripts/coverage-check.sh available)

set -euo pipefail

BASELINE_TAG="${BASELINE_TAG:-0.1.0}"
BASELINE_TESTS="${BASELINE_TESTS:-2896}"
MIN_COVERAGE_GLOBAL="${MIN_COVERAGE_GLOBAL:-92}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "→ Verifying 0.1.1 no-regression discipline against tag $BASELINE_TAG"
echo ""

# 1. Test count
TESTS_NOW=$(grep -rn '@Test' Tests --include='*.swift' | wc -l | tr -d ' ')
if [ "$TESTS_NOW" -lt "$BASELINE_TESTS" ]; then
    echo "✗ FAIL: test count regressed ($TESTS_NOW < $BASELINE_TESTS)"
    exit 1
fi
echo "✓ Test count: $TESTS_NOW (≥ $BASELINE_TESTS baseline)"

# 2. No public symbol removed since the baseline tag
REMOVED=$(git diff "$BASELINE_TAG"..HEAD -- 'Sources/CMAFKit/' 'Sources/CMAFKitDRM/' 2>/dev/null \
    | grep -E '^-public ' \
    | grep -v '^---' \
    || true)
if [ -n "$REMOVED" ]; then
    echo "✗ FAIL: public symbol(s) removed since $BASELINE_TAG:"
    echo "$REMOVED" | head -20
    exit 1
fi
echo "✓ No public symbol removed since $BASELINE_TAG"

# 3. Forbidden patterns — delegate to standalone script for single source of truth
if [ -x "./Scripts/check-forbidden-patterns.sh" ]; then
    if ! ./Scripts/check-forbidden-patterns.sh > /dev/null 2>&1; then
        echo "✗ FAIL: forbidden patterns dirty:"
        ./Scripts/check-forbidden-patterns.sh || true
        exit 1
    fi
    echo "✓ Forbidden patterns: 0 violations"
else
    echo "⚠ WARN: Scripts/check-forbidden-patterns.sh not found — skipping forbidden-pattern gate"
fi

# 4. Coverage gate — delegate to coverage-check.sh
if [ -x "./Scripts/coverage-check.sh" ]; then
    if ! ./Scripts/coverage-check.sh --min-global "$MIN_COVERAGE_GLOBAL"; then
        echo "✗ FAIL: coverage below $MIN_COVERAGE_GLOBAL %"
        exit 1
    fi
    echo "✓ Coverage: ≥ $MIN_COVERAGE_GLOBAL %"
else
    echo "⚠ WARN: Scripts/coverage-check.sh not found — skipping coverage gate"
fi

echo ""
echo "✓✓ ALL 0.1.1 regression checks PASSED"
exit 0
