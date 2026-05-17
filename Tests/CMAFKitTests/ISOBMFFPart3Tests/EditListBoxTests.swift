// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for EditListBox (elst) — ISO/IEC 14496-12 §8.6.6.

import Foundation
import Testing

@testable import CMAFKit

@Suite("EditListBox")
struct EditListBoxTests {

    @Test
    func roundTripV1Default() async throws {
        let table = EditListTable(entries: [
            EditListEntry(segmentDuration: 1024, mediaTime: 0)
        ])
        let original = EditListBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed == original)
        #expect(parsed.version == 1)
    }

    @Test
    func roundTripV0Compact() async throws {
        let table = EditListTable(
            entries: [
                EditListEntry(segmentDuration: 1024, mediaTime: -1),
                EditListEntry(segmentDuration: 1024, mediaTime: 0)
            ],
            version: 0
        )
        let original = EditListBox(version: 0, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed.version == 0)
        #expect(parsed.table.entryStride == 12)
        #expect(parsed.table[0].isEmptyEdit == true)
        #expect(parsed.table[1].isEmptyEdit == false)
    }

    @Test
    func emptyEditMarkerDetected() {
        let entry = EditListEntry(segmentDuration: 100, mediaTime: -1)
        #expect(entry.isEmptyEdit == true)
        let entry2 = EditListEntry(segmentDuration: 100, mediaTime: 0)
        #expect(entry2.isEmptyEdit == false)
    }

    @Test
    func defaultMediaRate() {
        let entry = EditListEntry(segmentDuration: 100, mediaTime: 0)
        #expect(entry.mediaRateInteger == 1)
        #expect(entry.mediaRateFraction == 0)
    }

    @Test
    func v1Survives32BitOverflow() async throws {
        let beyond32: UInt64 = UInt64(UInt32.max) + 1
        let table = EditListTable(entries: [
            EditListEntry(segmentDuration: beyond32, mediaTime: Int64(Int32.max) + 1)
        ])
        let original = EditListBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed.table[0].segmentDuration == beyond32)
        #expect(parsed.table[0].mediaTime == Int64(Int32.max) + 1)
    }

    @Test
    func emptyTableRangeContract() {
        let table = EditListTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { i in
            EditListEntry(segmentDuration: UInt64(i), mediaTime: Int64(i))
        }
        let table = EditListTable(entries: entries)
        // 10_000 × 20 bytes (v1 stride) = 200_000.
        #expect(table.rawEntries.count == 200_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map { i in
            EditListEntry(segmentDuration: UInt64(i), mediaTime: Int64(i))
        }
        let table = EditListTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].segmentDuration == 0)
        #expect(table[999_999].mediaTime == 999_999)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let table = EditListTable(entries: [
            EditListEntry(segmentDuration: 1024, mediaTime: -1),
            EditListEntry(segmentDuration: 2048, mediaTime: 512, mediaRateInteger: 2, mediaRateFraction: 0)
        ])
        let original = EditListBox(table: table)
        var w1 = BinaryWriter()
        original.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }

    @Test
    func throwsOnTruncation() async throws {
        // entry_count = 1 but no entry bytes follow.
        let bytes = Data(hex: "00 00 00 10 65 6C 73 74 01 00 00 00 00 00 00 01")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func unsupportedVersionThrows() async throws {
        let bytes = Data(hex: "00 00 00 10 65 6C 73 74 05 00 00 00 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}
