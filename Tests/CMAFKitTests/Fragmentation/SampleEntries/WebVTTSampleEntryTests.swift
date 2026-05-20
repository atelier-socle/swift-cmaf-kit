// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("WebVTTSampleEntry (wvtt)")
struct WebVTTSampleEntryTests {

    private func roundTrip(_ box: WebVTTSampleEntry) async throws -> WebVTTSampleEntry {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? WebVTTSampleEntry)
    }

    @Test
    func basicHeaderRoundTrip() async throws {
        let entry = WebVTTSampleEntry(
            configuration: WebVTTConfigurationBox(headerText: "WEBVTT\n")
        )
        #expect(try await roundTrip(entry) == entry)
    }

    @Test
    func headerWithRegionRoundTrip() async throws {
        let header = """
            WEBVTT

            REGION
            id:fred
            width:40%

            """
        let entry = WebVTTSampleEntry(
            configuration: WebVTTConfigurationBox(headerText: header)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.configuration.headerText == header)
    }

    @Test
    func sourceLabelRoundTrip() async throws {
        let entry = WebVTTSampleEntry(
            configuration: WebVTTConfigurationBox(headerText: "WEBVTT\n"),
            sourceLabel: WebVTTSourceLabelBox(sourceLabel: "Director's Commentary")
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.sourceLabel?.sourceLabel == "Director's Commentary")
    }

    @Test
    func boxType() {
        #expect(WebVTTSampleEntry.boxType == "wvtt")
        #expect(WebVTTConfigurationBox.boxType == "vttC")
        #expect(WebVTTSourceLabelBox.boxType == "vlab")
    }

    @Test
    func registryParserIsRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "wvtt") != nil)
        #expect(await registry.parser(for: "vttC") != nil)
        #expect(await registry.parser(for: "vlab") != nil)
    }

    @Test
    func dataReferenceIndexExposed() {
        let entry = WebVTTSampleEntry(
            dataReferenceIndex: 7,
            configuration: WebVTTConfigurationBox(headerText: "WEBVTT\n")
        )
        #expect(entry.dataReferenceIndex == 7)
    }

    @Test
    func missingVTTCRejectsOnParse() async {
        var writer = BinaryWriter()
        writer.writeBox(type: "wvtt") { body in
            body.writeZeros(6)
            body.writeUInt16(1)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func unicodeHeaderPreserved() async throws {
        let entry = WebVTTSampleEntry(
            configuration: WebVTTConfigurationBox(
                headerText: "WEBVTT — éàü 漢字\n"
            )
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.configuration.headerText.contains("漢字"))
    }

    @Test
    func emptyHeaderTextAccepted() async throws {
        let entry = WebVTTSampleEntry(
            configuration: WebVTTConfigurationBox(headerText: "")
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.configuration.headerText.isEmpty)
    }
}
