#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# coverage-check.sh
#
# Verifies line coverage on macOS via `xcrun llvm-cov` on the SPM-built
# test binary. Honors codecov.yml exemptions implicitly (codecov.yml is
# applied by codecov.io itself; this script reports the raw global
# coverage number for gating).
#
# Usage:
#   ./Scripts/coverage-check.sh                        # default min 92 % global
#   ./Scripts/coverage-check.sh --min-global 92        # explicit threshold
#   ./Scripts/coverage-check.sh --report-only          # print, never fail

set -euo pipefail
cd "$(dirname "$0")/.."

MIN_GLOBAL=92
REPORT_ONLY=0

while [ $# -gt 0 ]; do
    case "$1" in
        --min-global) MIN_GLOBAL="$2"; shift 2 ;;
        --report-only) REPORT_ONLY=1; shift ;;
        -h|--help)
            sed -n '4,16p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $1"; exit 2 ;;
    esac
done

# Run tests with coverage instrumentation
echo "→ Running swift test --enable-code-coverage (this rebuilds if necessary)..."
swift test --enable-code-coverage 2>&1 | tail -3

# Locate profdata and test binary produced by SPM
PROF=$(find .build -name 'default.profdata' -type f | head -1)
XCTEST=$(find .build -name '*PackageTests.xctest' -type d -print -quit 2>/dev/null || true)

if [ -z "$PROF" ]; then
    echo "✗ Could not locate default.profdata under .build/"
    exit 1
fi

# On macOS, the xctest bundle path is .build/.../Foo.xctest/Contents/MacOS/Foo
if [ -n "$XCTEST" ] && [ -d "$XCTEST/Contents/MacOS" ]; then
    BIN_NAME=$(basename "$XCTEST" .xctest)
    BIN="$XCTEST/Contents/MacOS/$BIN_NAME"
else
    # Fallback: Linux-style binary path
    BIN=$(find .build -name '*PackageTests' -type f ! -name '*.o' -not -path '*.dSYM*' | head -1)
fi

if [ -z "$BIN" ] || [ ! -e "$BIN" ]; then
    echo "✗ Could not locate test binary (looked for .xctest bundle and Linux fallback)"
    exit 1
fi

# Aggregate report — last line of llvm-cov report is the TOTAL row.
# Default llvm-cov columns: Regions / Functions / Lines / Branches, each as
# (count, missed, percent). We want the *line* coverage %, which is the
# 3rd percentage value from the left (after region% and function%).
REPORT=$(xcrun llvm-cov report "$BIN" \
    -instr-profile="$PROF" \
    -ignore-filename-regex='(\.build|Tests|CMAFKitCLI/Commands)' \
    2>/dev/null | tail -1)
TOTAL=$(echo "$REPORT" | grep -oE '[0-9]+\.[0-9]+%' | sed -n '3p' | tr -d '%')

echo "Global line coverage: $TOTAL %"

if [ "$REPORT_ONLY" -eq 1 ]; then
    echo "$TOTAL"
    exit 0
fi

# Float comparison via awk (Bash lacks native float compare)
if awk -v t="$TOTAL" -v m="$MIN_GLOBAL" 'BEGIN { exit (t >= m) ? 0 : 1 }'; then
    echo "✓ Coverage ≥ $MIN_GLOBAL %"
    exit 0
else
    echo "✗ Coverage $TOTAL % < $MIN_GLOBAL %"
    exit 1
fi
