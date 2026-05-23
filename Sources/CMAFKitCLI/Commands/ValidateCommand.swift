// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - ValidateCommand
//
// Reference: cmafkit-cli `validate` subcommand. Runs the CMAF,
// DASH, or LL-HLS conformance validator on a parsed file (init
// segment + media segments).

import ArgumentParser
import CMAFKit
import Foundation

/// Validator profile selector.
public enum ValidationProfile: String, ExpressibleByArgument, Sendable, CaseIterable {
    case cmaf
    case dash
    case llhls
}

/// `cmafkit-cli validate` — run a typed conformance validator.
public struct ValidateCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Run the CMAF / DASH / LL-HLS conformance validator on a file.",
        discussion: """
            Validates an init segment (and any media segments concatenated
            after it) against the chosen conformance profile. Reports each
            issue with its rule reference and severity.

            Examples:
              cmafkit-cli validate init.mp4 --profile cmaf
              cmafkit-cli validate init.mp4 --profile dash --output json
            """
    )

    @Argument(help: "Path to a CMAF init segment (or `-` for stdin).")
    public var input: String

    @Option(name: .long, help: "Conformance profile (cmaf/dash/llhls).")
    public var profile: ValidationProfile = .cmaf

    @Option(name: .long, help: "Output format (text/json/table).")
    public var output: OutputFormat = .defaultFormat

    public init() {}

    public func run() async throws {
        let bytes = try await CLIInput.read(path: input)
        let reader: CMAFInitSegmentReader
        do {
            reader = try await CMAFInitSegmentReader(bytes: bytes)
        } catch {
            throw CLIError.invalidInput(reason: "\(error)")
        }
        let parsedInit = reader.parsed
        let report: CMAFValidationReport
        switch profile {
        case .cmaf:
            report = CMAFConformanceValidator().validate(
                initSegment: parsedInit, mediaSegments: []
            )
        case .dash:
            report = DASHConformanceValidator().validate(
                initSegment: parsedInit, mediaSegments: []
            )
        case .llhls:
            report = LLHLSConformanceValidator().validate(
                initSegment: parsedInit, mediaSegments: []
            )
        }
        let cliReport = ValidationReport(
            profile: profile.rawValue,
            issues: report.issues.map(ValidationReport.Issue.init(from:))
        )
        try CLIWrite.render(report: cliReport, format: output)
        if report.hasErrors {
            throw CLIError.conformanceFailed(
                errorCount: report.issues.filter { $0.severity == .error }.count
            )
        }
    }
}

/// Typed report rendered by `validate`.
public struct ValidationReport: Sendable, Equatable, Codable {

    public struct Issue: Sendable, Equatable, Codable {
        public let severity: String
        public let ruleReference: String
        public let description: String
        public let trackID: UInt32?
        public let segmentIndex: Int?

        public init(
            severity: String,
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

        public init(from issue: CMAFValidationIssue) {
            self.severity = "\(issue.severity)"
            self.ruleReference = issue.ruleReference
            self.description = issue.description
            self.trackID = issue.trackID
            self.segmentIndex = issue.segmentIndex
        }
    }

    public let profile: String
    public let issues: [Issue]

    public init(profile: String, issues: [Issue]) {
        self.profile = profile
        self.issues = issues
    }
}

extension ValidationReport: TextRenderable {

    internal func renderText() -> String {
        var lines: [String] = []
        lines.append(TextFormatter.header("Conformance: \(profile)"))
        if issues.isEmpty {
            lines.append("✓ No issues reported.")
            return lines.joined(separator: "\n")
        }
        lines.append("\(issues.count) issue(s) reported:")
        for issue in issues {
            lines.append("")
            lines.append("[\(issue.severity)] \(issue.ruleReference)")
            lines.append("  \(issue.description)")
            if let track = issue.trackID {
                lines.append("  trackID: \(track)")
            }
            if let segment = issue.segmentIndex {
                lines.append("  segment: \(segment)")
            }
        }
        return lines.joined(separator: "\n")
    }

    internal func renderTable() -> String {
        if issues.isEmpty {
            return "No issues reported."
        }
        let headers = ["severity", "rule", "description", "track", "segment"]
        let rows: [[String]] = issues.map { i in
            [
                i.severity,
                i.ruleReference,
                i.description,
                i.trackID.map(String.init) ?? "-",
                i.segmentIndex.map(String.init) ?? "-"
            ]
        }
        return TableFormatter.render(headers: headers, rows: rows)
    }
}
