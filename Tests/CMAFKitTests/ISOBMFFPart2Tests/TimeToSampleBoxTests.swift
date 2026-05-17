// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TimeToSampleBox (stts) — ISO/IEC 14496-12 §8.6.1.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TimeToSampleBox")
struct TimeToSampleBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let table = TimeToSampleTable(entries: [
            TimeToSampleEntry(sampleCount: 100, sampleDelta: 3600)
        ])
        let original = TimeToSampleBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TimeToSampleBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripRealistic() async throws {
        let entries: [TimeToSampleEntry] = [
            TimeToSampleEntry(sampleCount: 1000, sampleDelta: 1024),
            TimeToSampleEntry(sampleCount: 500, sampleDelta: 1023),
            TimeToSampleEntry(sampleCount: 1, sampleDelta: 2000)
        ]
        let original = TimeToSampleBox(table: TimeToSampleTable(entries: entries))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TimeToSampleBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0].sampleCount == 1000)
        #expect(parsed.table[2].sampleDelta == 2000)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let table = TimeToSampleTable(entries: [
            TimeToSampleEntry(sampleCount: 1, sampleDelta: 0x64)
        ])
        let box = TimeToSampleBox(table: table)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 73 74 74 73
                00 00 00 00
                00 00 00 01
                00 00 00 01 00 00 00 64
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 73 74 74 73
                00 00 00 00
                00 00 00 01
                00 00 00 64 00 00 03 e8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TimeToSampleBox)
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0].sampleCount == 0x64)
        #expect(parsed.table[0].sampleDelta == 0x3E8)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 18 73 74 74 73 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func declaredCountExceedingPayloadThrows() async throws {
        // entry_count = 1_000_000 but only 2 entries (16 bytes) follow.
        // Box size declared at 36 (8 header + 4 ver+flags + 4 count + 16 entries).
        let bytes = Data(
            hex: """
                00 00 00 24 73 74 74 73
                00 00 00 00
                00 0F 42 40
                00 00 00 01 00 00 00 64
                00 00 00 01 00 00 00 C8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = TimeToSampleTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { _ in
            TimeToSampleEntry(sampleCount: 1, sampleDelta: 100)
        }
        let table = TimeToSampleTable(entries: entries)
        // 10 000 × 8 bytes = 80 000.
        #expect(table.rawEntries.count == 80_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        // 1M entries × 8 bytes = 8 MB raw. Verify O(1) random access and
        // that the lazy contract does not materialise an entry array.
        let entries = (0..<1_000_000).map { index in
            TimeToSampleEntry(sampleCount: 1, sampleDelta: UInt32(index))
        }
        let table = TimeToSampleTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].sampleDelta == 0)
        #expect(table[500_000].sampleDelta == 500_000)
        #expect(table[999_999].sampleDelta == 999_999)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 18 73 74 74 73
                00 00 00 00
                00 00 00 01
                00 00 00 64 00 00 03 E8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? TimeToSampleBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
