// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TrackRunBox (trun) — ISO/IEC 14496-12 §8.8.8.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackRunBox")
struct TrackRunBoxTests {

    @Test
    func roundTripEmptyTable() async throws {
        let table = TrackRunTable(entries: [], perSampleFlags: 0, version: 1)
        let original = TrackRunBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed == original)
        #expect(parsed.table.count == 0)
    }

    @Test
    func roundTripDurationOnly() async throws {
        let entries = [
            TrackRunEntry(sampleDuration: 1024),
            TrackRunEntry(sampleDuration: 1023),
            TrackRunEntry(sampleDuration: 1024)
        ]
        let table = TrackRunTable(
            entries: entries,
            perSampleFlags: TrackRunTable.flagSampleDuration,
            version: 1
        )
        let original = TrackRunBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0].sampleDuration == 1024)
        #expect(parsed.table[1].sampleDuration == 1023)
        #expect(parsed.table.entryStride == 4)
    }

    @Test
    func roundTripAllFourPerSampleFields() async throws {
        let entries = [
            TrackRunEntry(
                sampleDuration: 1024,
                sampleSize: 100,
                sampleFlags: 0x0100_0000,
                sampleCompositionTimeOffset: 256
            ),
            TrackRunEntry(
                sampleDuration: 1024,
                sampleSize: 110,
                sampleFlags: 0x0101_0000,
                sampleCompositionTimeOffset: -512
            )
        ]
        let perSampleFlags =
            TrackRunTable.flagSampleDuration
            | TrackRunTable.flagSampleSize
            | TrackRunTable.flagSampleFlags
            | TrackRunTable.flagSampleCompositionTimeOffsets
        let table = TrackRunTable(entries: entries, perSampleFlags: perSampleFlags, version: 1)
        let original = TrackRunBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.table.count == 2)
        #expect(parsed.table[0].sampleCompositionTimeOffset == 256)
        #expect(parsed.table[1].sampleCompositionTimeOffset == -512)
        #expect(parsed.table.entryStride == 16)
    }

    @Test
    func headerOptionalDataOffsetReconciled() async throws {
        let table = TrackRunTable(
            entries: [TrackRunEntry(sampleDuration: 100)],
            perSampleFlags: TrackRunTable.flagSampleDuration,
            version: 1
        )
        let box = TrackRunBox(dataOffset: -16, table: table)
        #expect((box.flags & TrackRunBox.flagDataOffset) != 0)
        #expect(box.dataOffset == -16)
    }

    @Test
    func headerOptionalFirstSampleFlagsReconciled() async throws {
        let table = TrackRunTable(
            entries: [TrackRunEntry(sampleDuration: 100)],
            perSampleFlags: TrackRunTable.flagSampleDuration,
            version: 1
        )
        let box = TrackRunBox(firstSampleFlags: 0x0200_0000, table: table)
        #expect((box.flags & TrackRunBox.flagFirstSampleFlags) != 0)
        #expect(box.firstSampleFlags == 0x0200_0000)
    }

    @Test
    func compositionTimeOffsetSignedInV1() async throws {
        let entries = [
            TrackRunEntry(sampleCompositionTimeOffset: -1),
            TrackRunEntry(sampleCompositionTimeOffset: Int64(Int32.max)),
            TrackRunEntry(sampleCompositionTimeOffset: Int64(Int32.min))
        ]
        let table = TrackRunTable(
            entries: entries,
            perSampleFlags: TrackRunTable.flagSampleCompositionTimeOffsets,
            version: 1
        )
        let original = TrackRunBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.table[0].sampleCompositionTimeOffset == -1)
        #expect(parsed.table[1].sampleCompositionTimeOffset == Int64(Int32.max))
        #expect(parsed.table[2].sampleCompositionTimeOffset == Int64(Int32.min))
    }

    @Test
    func compositionTimeOffsetUnsignedInV0() async throws {
        let entries = [
            TrackRunEntry(sampleCompositionTimeOffset: 0),
            TrackRunEntry(sampleCompositionTimeOffset: Int64(UInt32.max))
        ]
        let table = TrackRunTable(
            entries: entries,
            perSampleFlags: TrackRunTable.flagSampleCompositionTimeOffsets,
            version: 0
        )
        let original = TrackRunBox(version: 0, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.version == 0)
        #expect(parsed.table[1].sampleCompositionTimeOffset == Int64(UInt32.max))
    }

    @Test
    func tableStrideZeroWhenAllFlagsClear() {
        let table = TrackRunTable(entries: [], perSampleFlags: 0, version: 1)
        #expect(table.entryStride == 0)
    }

    @Test
    func tableStrideMatchesPerSampleFlags() {
        let table = TrackRunTable(
            entries: [],
            perSampleFlags: TrackRunTable.flagSampleDuration | TrackRunTable.flagSampleSize,
            version: 1
        )
        #expect(table.entryStride == 8)
    }

    @Test
    func emptyTableRangeContract() {
        let table = TrackRunTable(entries: [], perSampleFlags: 0, version: 1)
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let perSampleFlags = TrackRunTable.flagSampleSize
        let entries = (0..<10_000).map { _ in TrackRunEntry(sampleSize: 1024) }
        let table = TrackRunTable(entries: entries, perSampleFlags: perSampleFlags, version: 1)
        // 10_000 entries × 4 bytes (just sampleSize) = 40_000.
        #expect(table.rawEntries.count == 40_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let perSampleFlags = TrackRunTable.flagSampleSize
        let entries = (0..<1_000_000).map { i in
            TrackRunEntry(sampleSize: UInt32(i))
        }
        let table = TrackRunTable(entries: entries, perSampleFlags: perSampleFlags, version: 1)
        #expect(table.count == 1_000_000)
        #expect(table[0].sampleSize == 0)
        #expect(table[500_000].sampleSize == 500_000)
        #expect(table[999_999].sampleSize == 999_999)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let entries = [
            TrackRunEntry(sampleDuration: 1024, sampleSize: 100)
        ]
        let perSampleFlags = TrackRunTable.flagSampleDuration | TrackRunTable.flagSampleSize
        let table = TrackRunTable(entries: entries, perSampleFlags: perSampleFlags, version: 1)
        let original = TrackRunBox(table: table)
        var w1 = BinaryWriter()
        original.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func throwsOnTruncation() async throws {
        // sample_count = 5, but no per-sample data provided. Body declares
        // perSampleFlags = flagSampleSize but no bytes follow.
        let bytes = Data(
            hex: """
                00 00 00 14 74 72 75 6E
                01 00 02 00
                00 00 00 05
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}
