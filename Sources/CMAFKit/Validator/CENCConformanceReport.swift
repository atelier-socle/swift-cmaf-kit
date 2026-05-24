// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CENCConformanceReport + CENCConformanceIssue + CENCConformanceRule
//
// References:
// - ISO/IEC 23001-7 §4 — Common Encryption File Format
// - ISO/IEC 23001-7 §4.5-§4.9 — sinf / frma / schm / schi / tenc /
//   pssh / senc / saiz / saio
//
// Generic Common Encryption conformance types. Independent of CMAF
// profile constraints — apply to any CENC-protected ISO BMFF file
// (DASH MPD-referenced fMP4, HLS init segments with EXT-X-KEY, MOV
// FairPlay containers, etc.).

import Foundation

/// Validation strictness for ``CENCConformanceValidator``.
public enum CENCConformanceLevel: Sendable, Hashable, Codable, CaseIterable {

    /// Strict per ISO/IEC 23001-7 — every MAY / SHOULD violation
    /// reported.
    case strict

    /// Permissive — only MUST violations reported.
    case permissive
}

/// One of the eight ISO/IEC 23001-7 conformance rules evaluated by
/// ``CENCConformanceValidator``.
public enum CENCConformanceRule: String, Sendable, Hashable, Codable, CaseIterable {

    /// C1 — `enca` / `encv` / `enct` encrypted sample entries MUST
    /// carry `sinf` (ProtectionSchemeInfoBox). ISO/IEC 23001-7 §4.5.1.
    case C1_EncryptedSampleEntryHasSinf = "C1"

    /// C2 — `sinf` MUST carry `frma` (OriginalFormatBox) with the
    /// original codec fourCC. ISO/IEC 23001-7 §4.5.2.
    case C2_SinfHasFrma = "C2"

    /// C3 — `sinf` MUST carry `schm` (SchemeTypeBox) with
    /// scheme_type ∈ {cenc, cbc1, cens, cbcs}. ISO/IEC 23001-7 §4.5.3.
    case C3_SinfHasValidSchm = "C3"

    /// C4 — `schi` (SchemeInformationBox) MUST carry well-formed
    /// `tenc`. ISO/IEC 23001-7 §4.5.4.
    case C4_SchiHasTenc = "C4"

    /// C5 — `tenc.default_KID` MUST be exactly 16 bytes (UUID
    /// shape). ISO/IEC 23001-7 §4.6.
    case C5_TencDefaultKIDSize = "C5"

    /// C6 — `pssh` boxes MUST be well-formed (valid System ID + KID
    /// list when version 1) AND SHOULD be referenced by at least one
    /// track. ISO/IEC 23001-7 §4.7.
    case C6_PSSHWellFormed = "C6"

    /// C7 — `senc` / `saiz` / `saio` MUST be coherent (when present,
    /// `saiz` entry count matches `senc.samples.count`). ISO/IEC
    /// 23001-7 §4.8 + §4.9.
    case C7_SencSaizSaioCoherent = "C7"

    /// C8 — per-sample IV lengths consistent with
    /// `tenc.default_Per_Sample_IV_Size`. ISO/IEC 23001-7 §4.6 + §4.8.
    case C8_PerSampleIVLengthConsistent = "C8"

    /// Spec section anchor.
    public var specSection: String {
        switch self {
        case .C1_EncryptedSampleEntryHasSinf: return "ISO/IEC 23001-7 §4.5.1"
        case .C2_SinfHasFrma: return "ISO/IEC 23001-7 §4.5.2"
        case .C3_SinfHasValidSchm: return "ISO/IEC 23001-7 §4.5.3"
        case .C4_SchiHasTenc: return "ISO/IEC 23001-7 §4.5.4"
        case .C5_TencDefaultKIDSize: return "ISO/IEC 23001-7 §4.6"
        case .C6_PSSHWellFormed: return "ISO/IEC 23001-7 §4.7"
        case .C7_SencSaizSaioCoherent: return "ISO/IEC 23001-7 §4.8 + §4.9"
        case .C8_PerSampleIVLengthConsistent: return "ISO/IEC 23001-7 §4.6 + §4.8"
        }
    }
}

/// One finding from ``CENCConformanceValidator``.
public struct CENCConformanceIssue: Sendable, Equatable, Hashable, Codable {

    public enum Severity: String, Sendable, Hashable, Codable, CaseIterable {
        /// MUST violation — file is non-conformant.
        case error
        /// SHOULD violation — file works but may have interop issues.
        case warning
        /// MAY observation.
        case info
    }

    public let ruleID: CENCConformanceRule
    public let severity: Severity
    public let message: String
    public let context: String?

    public init(
        ruleID: CENCConformanceRule,
        severity: Severity,
        message: String,
        context: String? = nil
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.context = context
    }

    public var specSection: String { ruleID.specSection }
}

/// Aggregate result of a ``CENCConformanceValidator/validate(rootBoxes:)``
/// call (and the `validate(data:)` / `validate(fileURL:)` overloads).
public struct CENCConformanceReport: Sendable, Equatable, Codable {

    public let issues: [CENCConformanceIssue]
    public let level: CENCConformanceLevel

    public init(issues: [CENCConformanceIssue], level: CENCConformanceLevel) {
        self.issues = issues
        self.level = level
    }

    public var isConformant: Bool {
        !issues.contains(where: { $0.severity == .error })
    }

    public var isClean: Bool { issues.isEmpty }

    public func issues(
        of severity: CENCConformanceIssue.Severity
    ) -> [CENCConformanceIssue] {
        issues.filter { $0.severity == severity }
    }

    public func issues(for rule: CENCConformanceRule) -> [CENCConformanceIssue] {
        issues.filter { $0.ruleID == rule }
    }
}
