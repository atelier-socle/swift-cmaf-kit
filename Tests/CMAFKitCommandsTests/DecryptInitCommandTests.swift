// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit
@testable import CMAFKitCommands
@testable import CMAFKitDRM

@Suite("DecryptInitCommand")
struct DecryptInitCommandTests {

    private func writeTempFile(_ bytes: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "decrypt-init-\(UUID().uuidString).bin"
        )
        try bytes.write(to: url)
        return url
    }

    @Test
    func decryptInitWidevineFixture() async throws {
        let bytes = try CLITestFixtures.avcWithWidevineInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DecryptInitCommand.parse([url.path, "--output", "text"])
        try await command.run()
    }

    @Test
    func decryptInitJSONFormat() async throws {
        let bytes = try CLITestFixtures.avcWithWidevineInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DecryptInitCommand.parse([url.path, "--output", "json"])
        try await command.run()
    }

    @Test
    func decryptInitTableFormat() async throws {
        let bytes = try CLITestFixtures.avcWithWidevineInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DecryptInitCommand.parse([url.path, "--output", "table"])
        try await command.run()
    }

    @Test
    func plainInitSegmentReportsZeroPSSH() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DecryptInitCommand.parse([url.path])
        try await command.run()
    }

    @Test
    func malformedInputThrowsInvalidInput() async throws {
        let url = try writeTempFile(CLITestFixtures.malformedBytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DecryptInitCommand.parse([url.path])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func missingFileThrowsInputFileUnreadable() async throws {
        let command = try await DecryptInitCommand.parse(["/var/empty/missing-pssh-y.bin"])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func decryptInitReportRendersWidevineEntry() {
        let entry = DecryptInitReport.Entry.widevineFixture()
        let report = DecryptInitReport(psshCount: 1, entries: [entry])
        let text = report.renderText()
        #expect(text.contains("Widevine"))
    }

    @Test
    func decryptInitReportRendersTable() {
        let entry = DecryptInitReport.Entry.widevineFixture()
        let report = DecryptInitReport(psshCount: 1, entries: [entry])
        let table = report.renderTable()
        #expect(table.contains("system"))
        #expect(table.contains("Widevine"))
    }
}

extension DecryptInitReport.Entry {
    fileprivate static func widevineFixture() -> DecryptInitReport.Entry {
        let kid = Data(repeating: 0x42, count: 16)
        let widevine = WidevineInitData(keyIDs: [kid])
        let typed = TypedDRMInitData.widevine(widevine)
        let pssh = ProtectionSystemSpecificHeaderBox(
            version: 1,
            systemID: KnownDRMSystemID.widevine.uuid,
            keyIdentifiers: [],
            data: Data()
        )
        return DecryptInitReport.Entry(from: pssh, typed: typed)
    }
}
