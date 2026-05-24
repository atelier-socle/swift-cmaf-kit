// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ISOConformanceReport + ISOConformanceIssue + ISOConformanceRule
//
// References:
// - ISO/IEC 14496-12 §4-§8 — Box structure + mandatory boxes
//
// Generic ISO Base Media File Format conformance report types. These
// are independent of CMAF profile constraints — they apply to any ISO
// BMFF file (.mp4, .m4a, .mov, fragmented .m4s, HEIF, JPEG 2000, etc.).

import Foundation

/// Validation strictness for ``ISOConformanceValidator``.
///
/// `strict` reports every SHOULD violation as `.warning`; `permissive`
/// suppresses SHOULDs so the report focuses on real-world player
/// blockers.
public enum ISOConformanceLevel: Sendable, Hashable, Codable, CaseIterable {

    /// Strict per ISO/IEC 14496-12 — every MAY / SHOULD violation
    /// reported.
    case strict

    /// Permissive — only MUST violations reported. Matches what
    /// mainstream players (Apple AVFoundation, Shaka, dash.js) accept.
    case permissive
}

/// One of the eight ISO/IEC 14496-12 conformance rules evaluated by
/// ``ISOConformanceValidator``.
public enum ISOConformanceRule: String, Sendable, Hashable, Codable, CaseIterable {

    /// I1 — `ftyp` MUST appear and SHOULD be the first top-level box
    /// (or follow a leading `free`/`skip`/`mdat` per the streaming
    /// convention). Per ISO/IEC 14496-12 §4.3.
    case I1_FileTypePresent = "I1"

    /// I2 — `moov` MUST appear at most once. Per ISO/IEC 14496-12
    /// §8.2.
    case I2_MovieBoxUnique = "I2"

    /// I3 — track IDs within a `moov` MUST be unique. Per ISO/IEC
    /// 14496-12 §8.3.3.
    case I3_TrackIDsUnique = "I3"

    /// I4 — `mdhd.timescale` MUST be `> 0`. Per ISO/IEC 14496-12
    /// §8.4.2.
    case I4_MediaHeaderTimescalePositive = "I4"

    /// I5 — every `trak` MUST carry a `tkhd` with a non-zero
    /// `track_ID`. Per ISO/IEC 14496-12 §8.3.2.
    case I5_TrackHeaderIDCoherent = "I5"

    /// I6 — `mdat` declared size MUST NOT exceed file bounds. Per
    /// ISO/IEC 14496-12 §8.1.1. Only applicable to the
    /// ``ISOConformanceValidator/validate(data:)`` and
    /// ``ISOConformanceValidator/validate(fileURL:)`` overloads where
    /// raw bytes are available; the in-memory `[any ISOBox]` overload
    /// trusts that the parser already verified bounds.
    case I6_MediaDataSizeBounded = "I6"

    /// I7 — `dref` data references MUST be resolvable: every entry
    /// either carries the self-contained flag or names an external
    /// resource. Per ISO/IEC 14496-12 §8.7.2.
    case I7_DataReferenceResolvable = "I7"

    /// I8 — container box parent / child structural rules per ISO
    /// BMFF box-order tables. Per ISO/IEC 14496-12 §8.
    case I8_BoxStructureCoherent = "I8"

    /// Spec section anchor — included in every issue produced for
    /// this rule.
    public var specSection: String {
        switch self {
        case .I1_FileTypePresent: return "ISO/IEC 14496-12 §4.3"
        case .I2_MovieBoxUnique: return "ISO/IEC 14496-12 §8.2"
        case .I3_TrackIDsUnique: return "ISO/IEC 14496-12 §8.3.3"
        case .I4_MediaHeaderTimescalePositive: return "ISO/IEC 14496-12 §8.4.2"
        case .I5_TrackHeaderIDCoherent: return "ISO/IEC 14496-12 §8.3.2"
        case .I6_MediaDataSizeBounded: return "ISO/IEC 14496-12 §8.1.1"
        case .I7_DataReferenceResolvable: return "ISO/IEC 14496-12 §8.7.2"
        case .I8_BoxStructureCoherent: return "ISO/IEC 14496-12 §8"
        }
    }
}

/// One finding from ``ISOConformanceValidator``.
///
/// Each issue cites the rule identifier (I1..I8), the severity, the
/// human-readable message, optional context (track ID, box fourCC),
/// and the spec section reference.
public struct ISOConformanceIssue: Sendable, Equatable, Hashable, Codable {

    /// Severity classification.
    public enum Severity: String, Sendable, Hashable, Codable, CaseIterable {
        /// MUST violation — file is non-conformant.
        case error
        /// SHOULD violation — file works but may have interop issues.
        case warning
        /// MAY observation — informational only.
        case info
    }

    /// Rule identifier I1..I8.
    public let ruleID: ISOConformanceRule
    /// Severity.
    public let severity: Severity
    /// Human-readable description.
    public let message: String
    /// Optional context — track ID, box fourCC, etc.
    public let context: String?

    public init(
        ruleID: ISOConformanceRule,
        severity: Severity,
        message: String,
        context: String? = nil
    ) {
        self.ruleID = ruleID
        self.severity = severity
        self.message = message
        self.context = context
    }

    /// Spec section anchor for this issue's rule.
    public var specSection: String { ruleID.specSection }
}

/// Aggregate result of an ``ISOConformanceValidator/validate(rootBoxes:)``
/// call (and the `validate(data:)` / `validate(fileURL:)` overloads).
public struct ISOConformanceReport: Sendable, Equatable, Codable {

    /// All issues, in declaration order (I1 → I8).
    public let issues: [ISOConformanceIssue]

    /// Validation level used.
    public let level: ISOConformanceLevel

    public init(issues: [ISOConformanceIssue], level: ISOConformanceLevel) {
        self.issues = issues
        self.level = level
    }

    /// True when no `.error`-severity issue is present.
    public var isConformant: Bool {
        !issues.contains(where: { $0.severity == .error })
    }

    /// True when the report carries no issues at all.
    public var isClean: Bool { issues.isEmpty }

    /// Issues filtered by severity.
    public func issues(
        of severity: ISOConformanceIssue.Severity
    ) -> [ISOConformanceIssue] {
        issues.filter { $0.severity == severity }
    }

    /// Issues filtered by rule.
    public func issues(for rule: ISOConformanceRule) -> [ISOConformanceIssue] {
        issues.filter { $0.ruleID == rule }
    }
}
