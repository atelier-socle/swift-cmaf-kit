// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleToChunkBox (stsc) — ISO/IEC 14496-12 §8.7.4.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleToChunkBox")
struct SampleToChunkBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let table = SampleToChunkTable(entries: [
            SampleToChunkEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1)
        ])
        let original = SampleToChunkBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleToChunkBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripMultiEntry() async throws {
        let table = SampleToChunkTable(entries: [
            SampleToChunkEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1),
            SampleToChunkEntry(firstChunk: 5, samplesPerChunk: 8, sampleDescriptionIndex: 1),
            SampleToChunkEntry(firstChunk: 11, samplesPerChunk: 12, sampleDescriptionIndex: 2)
        ])
        let original = SampleToChunkBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleToChunkBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[2].sampleDescriptionIndex == 2)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let table = SampleToChunkTable(entries: [
            SampleToChunkEntry(firstChunk: 1, samplesPerChunk: 10, sampleDescriptionIndex: 1)
        ])
        let box = SampleToChunkBox(table: table)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + count(4) + 12 bytes entry = 28
        let expected = Data(
            hex: """
                00 00 00 1C 73 74 73 63
                00 00 00 00
                00 00 00 01
                00 00 00 01 00 00 00 0A 00 00 00 01
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 1C 73 74 73 63
                00 00 00 00
                00 00 00 01
                00 00 00 02 00 00 00 05 00 00 00 03
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleToChunkBox)
        #expect(parsed.table[0].firstChunk == 2)
        #expect(parsed.table[0].samplesPerChunk == 5)
        #expect(parsed.table[0].sampleDescriptionIndex == 3)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 1C 73 74 73 63 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func declaredCountExceedingPayloadThrows() async throws {
        let bytes = Data(
            hex: """
                00 00 00 24 73 74 73 63
                00 00 00 00
                00 0F 42 40
                00 00 00 01 00 00 00 0A 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = SampleToChunkTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map {
            SampleToChunkEntry(firstChunk: UInt32($0), samplesPerChunk: 1, sampleDescriptionIndex: 1)
        }
        let table = SampleToChunkTable(entries: entries)
        #expect(table.rawEntries.count == 120_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map {
            SampleToChunkEntry(firstChunk: UInt32($0 + 1), samplesPerChunk: 1, sampleDescriptionIndex: 1)
        }
        let table = SampleToChunkTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[500_000].firstChunk == 500_001)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 1C 73 74 73 63
                00 00 00 00
                00 00 00 01
                00 00 00 01 00 00 00 0A 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? SampleToChunkBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
