// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("ID3SampleEntry (id3 )")
struct ID3SampleEntryTests {

    private func roundTrip(_ box: ID3SampleEntry) async throws -> ID3SampleEntry {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? ID3SampleEntry)
    }

    @Test
    func defaultsRoundTrip() async throws {
        let entry = ID3SampleEntry()
        let parsed = try await roundTrip(entry)
        #expect(parsed.mimeFormat == "application/x-id3")
        #expect(parsed.contentEncoding.isEmpty)
    }

    @Test
    func customMimeRoundTrip() async throws {
        let entry = ID3SampleEntry(mimeFormat: "application/id3v2.4")
        let parsed = try await roundTrip(entry)
        #expect(parsed.mimeFormat == "application/id3v2.4")
    }

    @Test
    func bitRateChildRoundTrip() async throws {
        let entry = ID3SampleEntry(
            bitRate: BitRateBox(bufferSizeDB: 64, maxBitrate: 1_000, avgBitrate: 500)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.bitRate?.avgBitrate == 500)
    }

    @Test
    func fourCCHasTrailingSpace() {
        #expect(ID3SampleEntry.boxType == "id3 ")
        let raw = ID3SampleEntry.boxType.rawValue
        // ASCII 'i'=0x69 'd'=0x64 '3'=0x33 ' '=0x20.
        #expect(raw == 0x6964_3320)
    }

    @Test
    func registryParserRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "id3 ") != nil)
    }

    @Test
    func dataReferenceIndexPreserved() async throws {
        let entry = ID3SampleEntry(dataReferenceIndex: 5)
        let parsed = try await roundTrip(entry)
        #expect(parsed.dataReferenceIndex == 5)
    }
}
