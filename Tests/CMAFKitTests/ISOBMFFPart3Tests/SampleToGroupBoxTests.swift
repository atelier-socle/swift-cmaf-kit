// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleToGroupBox (sbgp) — ISO/IEC 14496-12 §8.9.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleToGroupBox")
struct SampleToGroupBoxTests {

    @Test
    func roundTripV0() async throws {
        let table = SampleToGroupTable(entries: [
            SampleToGroupEntry(sampleCount: 100, groupDescriptionIndex: 1),
            SampleToGroupEntry(sampleCount: 50, groupDescriptionIndex: 2),
            SampleToGroupEntry(sampleCount: 25, groupDescriptionIndex: 0)
        ])
        let original = SampleToGroupBox(
            version: 0,
            groupingType: "roll",
            table: table
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleToGroupBox)
        #expect(parsed == original)
        #expect(parsed.groupingTypeParameter == nil)
    }

    @Test
    func roundTripV1WithGroupingTypeParameter() async throws {
        let table = SampleToGroupTable(entries: [
            SampleToGroupEntry(sampleCount: 10, groupDescriptionIndex: 1)
        ])
        let original = SampleToGroupBox(
            version: 1,
            groupingType: "seig",
            groupingTypeParameter: 0xCAFE_BABE,
            table: table
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleToGroupBox)
        #expect(parsed.groupingType == "seig")
        #expect(parsed.groupingTypeParameter == 0xCAFE_BABE)
    }

    @Test
    func groupDescriptionIndex0MeansNoGroup() async throws {
        let table = SampleToGroupTable(entries: [
            SampleToGroupEntry(sampleCount: 5, groupDescriptionIndex: 0)
        ])
        let original = SampleToGroupBox(groupingType: "rap ", table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleToGroupBox)
        #expect(parsed.table[0].groupDescriptionIndex == 0)
    }

    @Test
    func emptyTableRangeContract() {
        let table = SampleToGroupTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { i in
            SampleToGroupEntry(sampleCount: 1, groupDescriptionIndex: UInt32(i))
        }
        let table = SampleToGroupTable(entries: entries)
        // 10_000 × 8 = 80_000.
        #expect(table.rawEntries.count == 80_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map { i in
            SampleToGroupEntry(sampleCount: UInt32(i), groupDescriptionIndex: 1)
        }
        let table = SampleToGroupTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].sampleCount == 0)
        #expect(table[999_999].sampleCount == 999_999)
    }

    @Test
    func throwsOnTruncation() async throws {
        // entry_count = 5, but only 1 entry (8 bytes) follows.
        let bytes = Data(
            hex: """
                00 00 00 18 73 62 67 70
                00 00 00 00
                72 6F 6C 6C
                00 00 00 05
                00 00 00 01 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}
