// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit
@testable import CMAFKitCommands

@Suite("ProbeCommand")
struct ProbeCommandTests {

    @Test
    func probesAVCAACInitSegment() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let tracks = reader.tracks()
        let report = ProbeReport(
            majorBrand: reader.majorBrand().description,
            compatibleBrands: reader.compatibleBrands().map(\.description),
            movieTimescale: reader.movieTimescale(),
            trackCount: tracks.count,
            tracks: tracks.map(ProbeReport.TrackSummary.init(from:))
        )
        #expect(report.trackCount == 2)
        #expect(report.majorBrand == "cmfc")
    }

    @Test
    func probeReportRendersTextFormat() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let tracks = reader.tracks()
        let report = ProbeReport(
            majorBrand: reader.majorBrand().description,
            compatibleBrands: reader.compatibleBrands().map(\.description),
            movieTimescale: reader.movieTimescale(),
            trackCount: tracks.count,
            tracks: tracks.map(ProbeReport.TrackSummary.init(from:))
        )
        let text = report.renderText()
        #expect(text.contains("CMAF init segment"))
        #expect(text.contains("track 1"))
        #expect(text.contains("track 2"))
    }

    @Test
    func probeReportRendersJSONFormat() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let report = ProbeReport(
            majorBrand: reader.majorBrand().description,
            compatibleBrands: reader.compatibleBrands().map(\.description),
            movieTimescale: reader.movieTimescale(),
            trackCount: reader.tracks().count,
            tracks: reader.tracks().map(ProbeReport.TrackSummary.init(from:))
        )
        let json = try JSONFormatter.string(report)
        #expect(json.contains("\"majorBrand\""))
        #expect(json.contains("\"trackCount\" : 2"))
    }

    @Test
    func probeReportRendersTableFormat() async throws {
        let bytes = try CLITestFixtures.avcPlusAACInitSegment()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let report = ProbeReport(
            majorBrand: reader.majorBrand().description,
            compatibleBrands: reader.compatibleBrands().map(\.description),
            movieTimescale: reader.movieTimescale(),
            trackCount: reader.tracks().count,
            tracks: reader.tracks().map(ProbeReport.TrackSummary.init(from:))
        )
        let table = report.renderTable()
        #expect(table.contains("trackID"))
        #expect(table.contains("avc1"))
        #expect(table.contains("mp4a"))
    }

    @Test
    func probeCommandRejectsMalformedInput() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "probe-malformed-\(UUID().uuidString).bin"
        )
        try CLITestFixtures.malformedBytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let command = try await ProbeCommand.parse([url.path])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func probeCommandRejectsMissingFile() async throws {
        let command = try await ProbeCommand.parse(["/var/empty/missing-probe-test.mp4"])
        await #expect(throws: CLIError.self) {
            try await command.run()
        }
    }

    @Test
    func trackSummaryReportsEncryptionScheme() async throws {
        let bytes = try CLITestFixtures.avcWithWidevineInitSegment()
        let reader = try await CMAFInitSegmentReader(bytes: bytes)
        let track = try #require(reader.tracks().first)
        let summary = ProbeReport.TrackSummary(from: track)
        #expect(summary.encryption == "cenc")
    }

    @Test
    func cliErrorExitCodesAreStable() {
        #expect(CLIError.inputFileUnreadable(path: "x").exitCode == 2)
        #expect(CLIError.invalidInput(reason: "y").exitCode == 3)
        #expect(CLIError.conformanceFailed(errorCount: 1).exitCode == 4)
        #expect(CLIError.unknownDRMSystem(uuid: "u").exitCode == 5)
        #expect(CLIError.drmParseFailed(systemID: "s", reason: "r").exitCode == 6)
        #expect(CLIError.outputExists(path: "o").exitCode == 7)
    }
}
