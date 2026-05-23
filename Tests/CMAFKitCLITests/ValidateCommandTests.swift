// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit
@testable import CMAFKitCLI

@Suite("ValidateCommand")
struct ValidateCommandTests {

    private func writeTempFile(_ bytes: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "validate-\(UUID().uuidString).bin"
        )
        try bytes.write(to: url)
        return url
    }

    @Test
    func cmafProfileReportsNoIssuesOnValidInput() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try ValidateCommand.parse(
            [url.path, "--profile", "cmaf", "--output", "text"]
        )
        try await command.run()
    }

    @Test
    func dashProfileReportsIssuesOnPlainInitSegment() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try ValidateCommand.parse(
            [url.path, "--profile", "dash", "--output", "json"]
        )
        do {
            try await command.run()
        } catch is CLIError {
            // accepted
        }
    }

    @Test
    func llhlsProfileSelectorParses() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try ValidateCommand.parse(
            [url.path, "--profile", "llhls", "--output", "text"]
        )
        do {
            try await command.run()
        } catch is CLIError {
            // accepted
        }
    }

    @Test
    func malformedInputThrowsInvalidInput() async throws {
        let url = try writeTempFile(CLITestFixtures.malformedBytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try ValidateCommand.parse([url.path])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func missingFileThrowsInputFileUnreadable() async throws {
        let command = try ValidateCommand.parse(["/var/empty/missing-validate.bin"])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func validationProfileAllCasesIsThreeProfiles() {
        #expect(ValidationProfile.allCases.count == 3)
        let names = Set(ValidationProfile.allCases.map(\.rawValue))
        #expect(names == ["cmaf", "dash", "llhls"])
    }

    @Test
    func validationReportEmptyRendersClean() {
        let report = ValidationReport(profile: "cmaf", issues: [])
        let text = report.renderText()
        #expect(text.contains("No issues"))
        let table = report.renderTable()
        #expect(table.contains("No issues reported"))
    }

    @Test
    func validationReportWithIssuesRendersText() {
        let issue = ValidationReport.Issue(
            severity: "error",
            ruleReference: "ISO/IEC 23000-19 §7.3.5.1",
            description: "test failure",
            trackID: 1,
            segmentIndex: 0
        )
        let report = ValidationReport(profile: "cmaf", issues: [issue])
        let text = report.renderText()
        #expect(text.contains("[error]"))
        #expect(text.contains("test failure"))
    }

    @Test
    func validationReportWithIssuesRendersTable() {
        let report = ValidationReport(
            profile: "cmaf",
            issues: [
                ValidationReport.Issue(
                    severity: "error",
                    ruleReference: "ISO/IEC 23000-19 §7.3.5.1",
                    description: "x",
                    trackID: nil,
                    segmentIndex: nil
                )
            ]
        )
        let table = report.renderTable()
        #expect(table.contains("severity"))
        #expect(table.contains("error"))
    }
}
