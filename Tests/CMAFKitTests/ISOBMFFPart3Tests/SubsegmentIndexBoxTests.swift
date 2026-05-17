// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SubsegmentIndexBox (ssix) — ISO/IEC 14496-12 §8.16.4.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SubsegmentIndexBox")
struct SubsegmentIndexBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let table = SubsegmentIndexTable(entries: [
            SubsegmentIndexEntry(level: 1, rangeSize: 0x100)
        ])
        let original = SubsegmentIndexBox(subsegmentCount: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SubsegmentIndexBox)
        #expect(parsed == original)
    }

    @Test
    func packedLevelAndRangeSize() async throws {
        let entries = [
            SubsegmentIndexEntry(level: 0, rangeSize: 0x0000_00FF),
            SubsegmentIndexEntry(level: 255, rangeSize: 0x00FF_FFFF)
        ]
        let original = SubsegmentIndexBox(
            subsegmentCount: 2,
            table: SubsegmentIndexTable(entries: entries)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SubsegmentIndexBox)
        #expect(parsed.table[0].level == 0)
        #expect(parsed.table[0].rangeSize == 0x0000_00FF)
        #expect(parsed.table[1].level == 255)
        #expect(parsed.table[1].rangeSize == 0x00FF_FFFF)
    }

    @Test
    func entryCountInferredFromBodyLength() async throws {
        // Body carries 3 entries (12 bytes); parser computes count from
        // remaining body bytes.
        let entries = [
            SubsegmentIndexEntry(level: 1, rangeSize: 100),
            SubsegmentIndexEntry(level: 2, rangeSize: 200),
            SubsegmentIndexEntry(level: 3, rangeSize: 300)
        ]
        let original = SubsegmentIndexBox(
            subsegmentCount: 1,
            table: SubsegmentIndexTable(entries: entries)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SubsegmentIndexBox)
        #expect(parsed.table.count == 3)
    }

    @Test
    func emptyTableRangeContract() {
        let table = SubsegmentIndexTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { i in
            SubsegmentIndexEntry(level: UInt8(i % 256), rangeSize: UInt32(i & 0x00FF_FFFF))
        }
        let table = SubsegmentIndexTable(entries: entries)
        // 10_000 × 4 bytes = 40_000.
        #expect(table.rawEntries.count == 40_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map { i in
            SubsegmentIndexEntry(level: UInt8(i % 256), rangeSize: UInt32(i & 0x00FF_FFFF))
        }
        let table = SubsegmentIndexTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].level == 0)
        #expect(table[999_999].rangeSize == UInt32(999_999 & 0x00FF_FFFF))
    }
}
