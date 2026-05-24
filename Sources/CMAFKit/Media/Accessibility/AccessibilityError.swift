// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - AccessibilityError
//
// Typed errors for ``AccessibilityMetadata`` construction and
// cross-format mapping. Most accessibility primitive parsing in 0.1.1
// is permissive (unknown URIs / schemes fall back to `.custom`); these
// errors are exposed for stricter-validation paths added by the
// validators surface or by HLSKit / DASHKit consumers that require
// strict conformance to a published spec snapshot.

import Foundation

/// Typed errors for accessibility primitive construction and mapping.
///
/// Most accessibility primitive parsing is permissive — unknown URIs
/// or scheme values are preserved verbatim via `.custom` cases. These
/// errors surface only in strict-validation paths (the conformance
/// validators, HLSKit / DASHKit emitters that refuse to ship
/// non-conformant metadata).
///
/// References:
/// - ISO/IEC 23009-1 §5.8.4.2-§5.8.4.3 — DASH descriptors
/// - Apple HLS Authoring §4.6 — `EXT-X-MEDIA` attributes
/// - EU Directive 2019/882 — European Accessibility Act
public enum AccessibilityError: Error, Equatable {

    /// `customRoleValue` is required when ``MediaSelectionRole/custom``
    /// is selected, but was missing or malformed.
    case invalidCustomRoleValue(_ value: String, reason: String)

    /// DASH `Accessibility` descriptor `schemeIdUri` is not one of the
    /// recognised schemes (ISO/IEC 23009-1 §5.8.4.3 + DVB-DASH §5.2).
    case unknownDASHAccessibilityScheme(_ schemeIdUri: String)

    /// HLS attribute combination is internally inconsistent (e.g.,
    /// `FORCED=YES` paired with a non-subtitle track).
    case conflictingFlags(reason: String)

    /// An accessibility feature that requires a language association
    /// is missing one (e.g., ``AccessibilityFeature/signLanguageInterpretation``
    /// without a `signLanguage` BCP 47 tag).
    case missingRequiredLanguage(forFeature: AccessibilityFeature)
}
