// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import CMAFKit

@Suite("TextMetadataSampleEntry (mett)")
struct TextMetadataSampleEntryTests {

    private func roundTrip(
        _ box: TextMetadataSampleEntry
    ) async throws -> TextMetadataSampleEntry {
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        return try #require(boxes.first as? TextMetadataSampleEntry)
    }

    @Test
    func textPlainRoundTrip() async throws {
        let entry = TextMetadataSampleEntry(
            contentEncoding: "",
            mimeFormat: "text/plain;charset=UTF-8"
        )
        #expect(try await roundTrip(entry) == entry)
    }

    @Test
    func klvRoundTrip() async throws {
        let entry = TextMetadataSampleEntry(
            contentEncoding: "",
            mimeFormat: "application/smpte-336-klv"
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.mimeFormat == "application/smpte-336-klv")
    }

    @Test
    func gzipEncodingPreserved() async throws {
        let entry = TextMetadataSampleEntry(
            contentEncoding: "gzip",
            mimeFormat: "application/json"
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.contentEncoding == "gzip")
    }

    @Test
    func bitRateChildRoundTrip() async throws {
        let entry = TextMetadataSampleEntry(
            mimeFormat: "text/plain",
            bitRate: BitRateBox(bufferSizeDB: 512, maxBitrate: 16_000, avgBitrate: 8_000)
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.bitRate?.maxBitrate == 16_000)
    }

    @Test
    func boxType() {
        #expect(TextMetadataSampleEntry.boxType == "mett")
    }

    @Test
    func registryParserRegistered() async {
        let registry = await BoxRegistry.defaultRegistry()
        #expect(await registry.parser(for: "mett") != nil)
    }

    @Test
    func emptyEncodingAndMimeAccepted() async throws {
        let entry = TextMetadataSampleEntry(
            contentEncoding: "",
            mimeFormat: ""
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.contentEncoding.isEmpty)
        #expect(parsed.mimeFormat.isEmpty)
    }

    @Test
    func dataReferenceIndexPreserved() async throws {
        let entry = TextMetadataSampleEntry(
            dataReferenceIndex: 2,
            mimeFormat: "text/plain"
        )
        let parsed = try await roundTrip(entry)
        #expect(parsed.dataReferenceIndex == 2)
    }
}
