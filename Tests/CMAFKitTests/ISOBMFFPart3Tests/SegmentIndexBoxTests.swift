// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SegmentIndexBox (sidx) — ISO/IEC 14496-12 §8.16.3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SegmentIndexBox")
struct SegmentIndexBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let entry = SegmentIndexEntry(
            referenceType: false,
            referencedSize: 100,
            subsegmentDuration: 1024,
            startsWithSAP: true,
            sapType: 1,
            sapDeltaTime: 0
        )
        let table = SegmentIndexTable(entries: [entry])
        let original = SegmentIndexBox(
            referenceID: 1,
            timescale: 48_000,
            earliestPresentationTime: 0,
            firstOffset: 0,
            table: table
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed == original)
    }

    @Test
    func referenceTypeBitDistinguishesSidxFromMediaReference() async throws {
        let entries = [
            SegmentIndexEntry(
                referenceType: false, referencedSize: 200,
                subsegmentDuration: 100, startsWithSAP: false, sapType: 0, sapDeltaTime: 0
            ),
            SegmentIndexEntry(
                referenceType: true, referencedSize: 300,
                subsegmentDuration: 100, startsWithSAP: false, sapType: 0, sapDeltaTime: 0
            )
        ]
        let original = SegmentIndexBox(
            referenceID: 1,
            timescale: 90_000,
            earliestPresentationTime: 0,
            firstOffset: 0,
            table: SegmentIndexTable(entries: entries)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed.table[0].referenceType == false)
        #expect(parsed.table[1].referenceType == true)
    }

    @Test
    func referencedSizeMustFitIn31Bits() {
        // referencedSize uses 31 bits; the high bit is the reference type.
        // The init precondition rejects values that would overflow.
        // We cannot easily test precondition failures in Swift Testing,
        // so we instead exercise the valid upper bound.
        let entry = SegmentIndexEntry(
            referenceType: false,
            referencedSize: 0x7FFF_FFFF,
            subsegmentDuration: 1,
            startsWithSAP: false,
            sapType: 0,
            sapDeltaTime: 0
        )
        #expect(entry.referencedSize == 0x7FFF_FFFF)
    }

    @Test
    func sapTypeFitsIn3Bits() {
        let entry = SegmentIndexEntry(
            referenceType: false,
            referencedSize: 1,
            subsegmentDuration: 1,
            startsWithSAP: true,
            sapType: 7,
            sapDeltaTime: 0
        )
        #expect(entry.sapType == 7)
    }

    @Test
    func sapDeltaTimeFitsIn28Bits() {
        let entry = SegmentIndexEntry(
            referenceType: false,
            referencedSize: 1,
            subsegmentDuration: 1,
            startsWithSAP: true,
            sapType: 1,
            sapDeltaTime: 0x0FFF_FFFF
        )
        #expect(entry.sapDeltaTime == 0x0FFF_FFFF)
    }

    @Test
    func v0Compact32BitPresentationTime() async throws {
        let table = SegmentIndexTable(entries: [
            SegmentIndexEntry(
                referenceType: false, referencedSize: 100,
                subsegmentDuration: 50, startsWithSAP: true,
                sapType: 1, sapDeltaTime: 0
            )
        ])
        let original = SegmentIndexBox(
            version: 0,
            referenceID: 1,
            timescale: 90_000,
            earliestPresentationTime: 0xABCD_1234,
            firstOffset: 0x1000,
            table: table
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed.version == 0)
        #expect(parsed.earliestPresentationTime == 0xABCD_1234)
    }

    @Test
    func v1Default64BitPresentationTime() async throws {
        let beyond32: UInt64 = UInt64(UInt32.max) + 12345
        let table = SegmentIndexTable(entries: [])
        let original = SegmentIndexBox(
            referenceID: 1,
            timescale: 90_000,
            earliestPresentationTime: beyond32,
            firstOffset: 0,
            table: table
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed.version == 1)
        #expect(parsed.earliestPresentationTime == beyond32)
    }

    @Test
    func emptyTableRangeContract() {
        let table = SegmentIndexTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { _ in
            SegmentIndexEntry(
                referenceType: false, referencedSize: 1,
                subsegmentDuration: 1, startsWithSAP: false,
                sapType: 0, sapDeltaTime: 0
            )
        }
        let table = SegmentIndexTable(entries: entries)
        #expect(table.rawEntries.count == 120_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        var entries: [SegmentIndexEntry] = []
        entries.reserveCapacity(1_000_000)
        for i in 0..<1_000_000 {
            let size = UInt32(i)
            let entry = SegmentIndexEntry(
                referenceType: false,
                referencedSize: size,
                subsegmentDuration: size,
                startsWithSAP: true,
                sapType: 1,
                sapDeltaTime: 0
            )
            entries.append(entry)
        }
        let table = SegmentIndexTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].referencedSize == 0)
        #expect(table[500_000].referencedSize == 500_000)
        #expect(table[999_999].referencedSize == 999_999)
    }

    @Test
    func throwsOnTruncation() async throws {
        // Declare reference_count = 1 but provide 0 bytes of entry data.
        let bytes = Data(
            hex: """
                00 00 00 20 73 69 64 78
                00 00 00 00
                00 00 00 01
                00 01 5F 90
                00 00 00 00
                00 00 00 00
                00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }
}
