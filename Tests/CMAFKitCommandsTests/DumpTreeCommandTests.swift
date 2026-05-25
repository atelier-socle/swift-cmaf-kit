// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit
@testable import CMAFKitCommands

@Suite("DumpTreeCommand")
struct DumpTreeCommandTests {

    private func writeTempFile(_ bytes: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "dump-tree-\(UUID().uuidString).bin"
        )
        try bytes.write(to: url)
        return url
    }

    @Test
    func dumpsFTYPAndMOOVForAVCAACInit() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DumpTreeCommand.parse([url.path, "--output", "text"])
        try await command.run()
    }

    @Test
    func dumpsMOOVWithDepthLimit() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DumpTreeCommand.parse(
            [url.path, "--depth", "1", "--output", "text"]
        )
        try await command.run()
    }

    @Test
    func dumpsJSONFormat() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DumpTreeCommand.parse([url.path, "--output", "json"])
        try await command.run()
    }

    @Test
    func dumpsTableFormat() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DumpTreeCommand.parse([url.path, "--output", "table"])
        try await command.run()
    }

    @Test
    func malformedInputThrowsInvalidInput() async throws {
        let url = try writeTempFile(CLITestFixtures.malformedBytes)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await DumpTreeCommand.parse([url.path])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func missingFileThrowsInputFileUnreadable() async throws {
        let command = try await DumpTreeCommand.parse(["/var/empty/missing-tree-x.bin"])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func dumpTreeReportRendersNoOrphanNodes() {
        let node = DumpTreeReport.Node(type: "ftyp", size: 32, children: [])
        let report = DumpTreeReport(nodes: [node])
        let text = report.renderText()
        #expect(text.contains("ftyp"))
        #expect(text.contains("32 bytes"))
    }

    @Test
    func dumpTreeReportRendersTableWithChildrenColumn() {
        let report = DumpTreeReport(nodes: [
            DumpTreeReport.Node(
                type: "moov", size: 200,
                children: [
                    DumpTreeReport.Node(type: "mvhd", size: 100, children: [])
                ]
            )
        ])
        let table = report.renderTable()
        #expect(table.contains("box"))
        #expect(table.contains("moov"))
        #expect(table.contains("mvhd"))
    }
}
