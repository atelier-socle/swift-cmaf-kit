// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - CMAFValidationReport + CMAFValidationIssue
//
// Reference: ISO/IEC 23000-19 §7 (CMAF conformance), ISO/IEC
// 23009-1 §6.3 (DASH ISO BMFF profile), IETF RFC 8216bis-15 §B
// (LL-HLS partial chunks).
//
// The conformance validators take parsed values (init segment,
// media segments) and produce a non-throwing report. Issues are
// categorised by severity; consumers decide whether to escalate.

import Foundation

/// Non-throwing report produced by a conformance validator.
public struct CMAFValidationReport: Sendable, Equatable, Hashable {
    /// Every issue surfaced by the validator, in declaration order.
    public let issues: [CMAFValidationIssue]

    public init(issues: [CMAFValidationIssue] = []) {
        self.issues = issues
    }

    /// True when at least one issue is severity `.error`.
    public var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    /// True when at least one issue is severity `.warning`.
    public var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }

    /// True when the report carries no issues at all.
    public var isClean: Bool { issues.isEmpty }

    /// Filter helper.
    public func issues(at severity: CMAFValidationIssue.Severity) -> [CMAFValidationIssue] {
        issues.filter { $0.severity == severity }
    }

    /// Convenience union — merges this report with another.
    public func merged(with other: CMAFValidationReport) -> CMAFValidationReport {
        CMAFValidationReport(issues: issues + other.issues)
    }
}

/// One conformance issue surfaced by a validator.
public struct CMAFValidationIssue: Sendable, Equatable, Hashable, Codable {

    /// Issue severity.
    public enum Severity: Sendable, Hashable, Equatable, Codable {
        /// Strict spec violation — `hasErrors` becomes true.
        case error
        /// Tolerated but not conformant (e.g., a SHOULD violation).
        case warning
        /// Notable but not a conformance problem.
        case info
    }

    public let severity: Severity
    /// Specification reference, e.g. `"ISO/IEC 23000-19 \u{00A7}7.3.5.1"`.
    public let ruleReference: String
    /// Human-readable description in US English technical register.
    public let description: String
    /// Set when the issue is track-specific.
    public let trackID: UInt32?
    /// Set when the issue is segment-specific.
    public let segmentIndex: Int?

    public init(
        severity: Severity,
        ruleReference: String,
        description: String,
        trackID: UInt32? = nil,
        segmentIndex: Int? = nil
    ) {
        self.severity = severity
        self.ruleReference = ruleReference
        self.description = description
        self.trackID = trackID
        self.segmentIndex = segmentIndex
    }
}
