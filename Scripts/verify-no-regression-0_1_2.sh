#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS
#
# verify-no-regression-0_1_2.sh
#
# Session-end discipline check for the 0.1.2 patch.
# Verifies zero regression on the v0.1.1 baseline:
#   - test count ≥ 3575 (the 0.1.1 baseline on macOS)
#   - no public symbol from v0.1.0 + v0.1.1 has been removed
#   - 9 forbidden patterns clean
#   - coverage ≥ 92 % global
#   - v0.1.1 public surface spot-check: every shipped type still present
#
# Strategy: delegate to Scripts/verify-no-regression-0_1_1.sh for the
# v0.1.0 baseline checks (test count + public-symbol diff vs the 0.1.0
# tag + forbidden patterns + coverage), then run an extra spot-check
# on the v0.1.1-shipped types (MV-HEVC + RFC 6381 + BCP 47 +
# accessibility + audio codecs + validators).

set -euo pipefail

BASELINE_TAG="${BASELINE_TAG:-0.1.1}"
BASELINE_TESTS="${BASELINE_TESTS:-3575}"
MIN_COVERAGE_GLOBAL="${MIN_COVERAGE_GLOBAL:-92}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "→ Verifying 0.1.2 no-regression discipline against tag $BASELINE_TAG"
echo ""

# 1. Inherit v0.1.0 baseline protection from the 0.1.1 script.
if [ -x "./Scripts/verify-no-regression-0_1_1.sh" ]; then
    echo "→ Delegating to verify-no-regression-0_1_1.sh for v0.1.0 baseline checks..."
    if ! ./Scripts/verify-no-regression-0_1_1.sh; then
        echo "✗ FAIL: v0.1.0 baseline checks regressed — see above"
        exit 1
    fi
    echo ""
else
    echo "✗ FAIL: Scripts/verify-no-regression-0_1_1.sh missing — cannot delegate baseline checks"
    exit 1
fi

# 2. Test count vs v0.1.1 baseline.
TESTS_NOW=$(grep -rn '@Test' Tests --include='*.swift' | wc -l | tr -d ' ')
if [ "$TESTS_NOW" -lt "$BASELINE_TESTS" ]; then
    echo "✗ FAIL: test count regressed vs $BASELINE_TAG ($TESTS_NOW < $BASELINE_TESTS)"
    exit 1
fi
echo "✓ Test count: $TESTS_NOW (≥ $BASELINE_TESTS v0.1.1 baseline)"

# 3. No public symbol removed since the v0.1.1 baseline tag.
#
# Known intentional rename (Session 1 — Foundation, 0.1.2):
#   `public struct CMAFKitCLI: AsyncParsableCommand` (in CMAFKitCLI executable target)
#   → renamed to `public struct CMAFKitCommand: AsyncParsableCommand` (in CMAFKitCommands library target).
# The `CMAFKitCLI` name survives as the executable's `internal @main` wrapper.
# This rename is binary-safe: the `CMAFKitCLI` executable target is not
# importable by third-party packages (Swift forbids importing an
# executable target). The rename is documented in CHANGELOG [Unreleased]
# under Changed/Removed. We allow-list the exact removed signature here.
if git rev-parse --verify "$BASELINE_TAG" >/dev/null 2>&1; then
    REMOVED=$(git diff "$BASELINE_TAG"..HEAD -- 'Sources/CMAFKit/' 'Sources/CMAFKitDRM/' 'Sources/CMAFKitCLI/' 'Sources/CMAFKitCommands/' 2>/dev/null \
        | grep -E '^-public ' \
        | grep -v '^---' \
        | grep -v '^-public struct CMAFKitCLI: AsyncParsableCommand' \
        || true)
    if [ -n "$REMOVED" ]; then
        echo "✗ FAIL: public symbol(s) removed since $BASELINE_TAG:"
        echo "$REMOVED" | head -20
        exit 1
    fi
    echo "✓ No public symbol removed since $BASELINE_TAG"
else
    echo "⚠ WARN: tag $BASELINE_TAG not visible locally — skipping diff-based public-symbol check"
fi

# 4. v0.1.1 public surface spot-check — every shipped type must still
#    be declared `public` somewhere in Sources/. Each entry has been
#    verified present at the time this script was created.
REQUIRED_PUBLIC_TYPES=(
    # MV-HEVC and Apple Vision Pro spatial video
    "HEVCParameterSets"
    "HEVCVPSExtension"
    "HEVCMultiLayerSPS"
    "MultiLayerHEVCConfiguration"
    "MVHEVCSampleEntry"
    "MVHEVCPackager"
    "ViewExtendedUsageBox"
    "StereoInformationBox"
    "HeroEyeInformationBox"
    # RFC 6381 codec strings
    "RFC6381CodecDescriptor"
    "RFC6381CodecStringBuilder"
    # BCP 47 language tags
    "BCP47LanguageTag"
    "PrimarySubtag"
    "ISO15924Script"
    "Region"
    "BCP47Extension"
    "IANALanguageSubtagRegistry"
    # Accessibility primitives
    "AccessibilityMetadata"
    "MediaSelectionRole"
    "AccessibilityFeature"
    "AccessibilityCharacteristic"
    "AudioPurpose"
    # Audio codecs (EC-3 JOC, ALAC, PCM)
    "EC3JOCExtension"
    "ALACSampleEntry"
    "ALACSpecificBox"
    "IntegerPCMSampleEntry"
    "FloatingPointPCMSampleEntry"
    "LegacyPCMSampleEntry"
    "PCMConfigurationBox"
    # Validators
    "ISOConformanceValidator"
    "CENCConformanceValidator"
)

MISSING=0
for type in "${REQUIRED_PUBLIC_TYPES[@]}"; do
    if grep -rq "^public [a-z]\+ ${type}\b" Sources/ 2>/dev/null; then
        :
    else
        echo "  ✗ ${type} MISSING from public surface — v0.1.1 regression!"
        MISSING=$((MISSING + 1))
    fi
done
if [ "$MISSING" -gt 0 ]; then
    echo "✗ FAIL: $MISSING v0.1.1 public type(s) removed from the surface"
    exit 1
fi
echo "✓ v0.1.1 public surface spot-check: ${#REQUIRED_PUBLIC_TYPES[@]}/${#REQUIRED_PUBLIC_TYPES[@]} types present"

echo ""
echo "✓✓ ALL 0.1.2 regression checks PASSED"
exit 0
