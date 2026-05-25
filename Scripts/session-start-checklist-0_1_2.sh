#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# session-start-checklist-0_1_2.sh
#
# Run at the START of every 0.1.2 implementation session.
# Confirms the branch is in a clean state and ready to receive changes.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Session start checklist (0.1.2 patch)"

# 1. On the right branch
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "feat/0_1_2-refinement" ]; then
    echo "✗ Wrong branch: $BRANCH (expected feat/0_1_2-refinement)"
    exit 1
fi
echo "✓ Branch: $BRANCH"

# 2. Working tree state
DIRTY=$(git status --short)
if [ -n "$DIRTY" ]; then
    echo "⚠ Working tree has changes — review before starting new session work:"
    echo "$DIRTY" | head -10
fi

# 3. Last commit reference (for context)
LAST=$(git log -1 --format='%h %s')
echo "✓ Last commit: $LAST"

# 4. Baseline test count tracking
TESTS_NOW=$(grep -rn '@Test' Tests --include='*.swift' | wc -l | tr -d ' ')
echo "  Current @Test count: $TESTS_NOW"
echo "  Baseline (v0.1.1):  3575"

# 5. Forbidden patterns clean (delegated)
if [ -x "./Scripts/check-forbidden-patterns.sh" ]; then
    if ./Scripts/check-forbidden-patterns.sh > /dev/null 2>&1; then
        echo "✓ Forbidden patterns clean"
    else
        echo "✗ Forbidden patterns dirty before session — see ./Scripts/check-forbidden-patterns.sh"
        exit 1
    fi
else
    echo "⚠ WARN: Scripts/check-forbidden-patterns.sh not found"
fi

echo ""
echo "→ Ready to start session work."
