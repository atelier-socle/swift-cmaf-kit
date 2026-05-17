// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for TrackFragmentRandomAccessBox (tfra) — ISO/IEC 14496-12 §8.8.10.

import Foundation
import Testing

@testable import CMAFKit

@Suite("TrackFragmentRandomAccessBox")
struct TrackFragmentRandomAccessBoxTests {

    @Test
    func roundTripMinimalV1() async throws {
        let entry = TrackFragmentRandomAccessEntry(
            time: 0, moofOffset: 0x1000,
            trafNumber: 1, trunNumber: 1, sampleNumber: 1
        )
        let table = TrackFragmentRandomAccessTable(entries: [entry])
        let original = TrackFragmentRandomAccessBox(trackID: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentRandomAccessBox)
        #expect(parsed == original)
    }

    @Test
    func roundTripV0Compact32Bit() async throws {
        let table = TrackFragmentRandomAccessTable(
            entries: [
                TrackFragmentRandomAccessEntry(
                    time: 0xABCD_1234, moofOffset: 0x5678,
                    trafNumber: 1, trunNumber: 2, sampleNumber: 3
                )
            ],
            version: 0
        )
        let original = TrackFragmentRandomAccessBox(version: 0, trackID: 42, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentRandomAccessBox)
        #expect(parsed.version == 0)
        #expect(parsed.trackID == 42)
        #expect(parsed.table[0].time == 0xABCD_1234)
        #expect(parsed.table[0].moofOffset == 0x5678)
    }

    @Test
    func variableWidthFields1Byte() async throws {
        let entries = [
            TrackFragmentRandomAccessEntry(
                time: 100, moofOffset: 0x1000,
                trafNumber: 0xAB, trunNumber: 0xCD, sampleNumber: 0xEF
            )
        ]
        let table = TrackFragmentRandomAccessTable(
            entries: entries,
            trafNumberWidth: 1,
            trunNumberWidth: 1,
            sampleNumberWidth: 1
        )
        let original = TrackFragmentRandomAccessBox(trackID: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentRandomAccessBox)
        #expect(parsed.table[0].trafNumber == 0xAB)
        #expect(parsed.table[0].trunNumber == 0xCD)
        #expect(parsed.table[0].sampleNumber == 0xEF)
        #expect(parsed.table.entryStride == 8 + 8 + 1 + 1 + 1)
    }

    @Test
    func variableWidthFields3Byte() async throws {
        let entries = [
            TrackFragmentRandomAccessEntry(
                time: 100, moofOffset: 0x1000,
                trafNumber: 0x00AB_CDEF, trunNumber: 0x0012_3456, sampleNumber: 0x0000_FFFF
            )
        ]
        let table = TrackFragmentRandomAccessTable(
            entries: entries,
            trafNumberWidth: 3,
            trunNumberWidth: 3,
            sampleNumberWidth: 3
        )
        let original = TrackFragmentRandomAccessBox(trackID: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentRandomAccessBox)
        #expect(parsed.table[0].trafNumber == 0x00AB_CDEF)
        #expect(parsed.table[0].sampleNumber == 0x0000_FFFF)
    }

    @Test
    func defaultWidthsAre4Bytes() {
        let table = TrackFragmentRandomAccessTable(entries: [])
        #expect(table.trafNumberWidth == 4)
        #expect(table.trunNumberWidth == 4)
        #expect(table.sampleNumberWidth == 4)
    }

    @Test
    func emptyTableRangeContract() {
        let table = TrackFragmentRandomAccessTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { i in
            TrackFragmentRandomAccessEntry(
                time: UInt64(i), moofOffset: UInt64(i * 100),
                trafNumber: 1, trunNumber: 1, sampleNumber: UInt32(i)
            )
        }
        let table = TrackFragmentRandomAccessTable(entries: entries)
        // 10_000 × 28 bytes (v1: 8+8+4+4+4) = 280_000.
        #expect(table.rawEntries.count == 280_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map { i in
            TrackFragmentRandomAccessEntry(
                time: UInt64(i), moofOffset: UInt64(i),
                trafNumber: 1, trunNumber: 1, sampleNumber: UInt32(i)
            )
        }
        let table = TrackFragmentRandomAccessTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].time == 0)
        #expect(table[500_000].sampleNumber == 500_000)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let table = TrackFragmentRandomAccessTable(
            entries: [
                TrackFragmentRandomAccessEntry(
                    time: 1024, moofOffset: 0x1000,
                    trafNumber: 0x12_34, trunNumber: 0x56_78, sampleNumber: 0x9A_BC
                )
            ],
            trafNumberWidth: 2,
            trunNumberWidth: 2,
            sampleNumberWidth: 2
        )
        let original = TrackFragmentRandomAccessBox(trackID: 1, table: table)
        var w1 = BinaryWriter()
        original.encode(to: &w1)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: w1.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentRandomAccessBox)
        var w2 = BinaryWriter()
        parsed.encode(to: &w2)
        #expect(w1.data == w2.data)
    }
}

@Suite("MovieFragmentRandomAccessOffsetBox")
struct MovieFragmentRandomAccessOffsetBoxTests {

    @Test
    func roundTripMfraSize() async throws {
        let original = MovieFragmentRandomAccessOffsetBox(mfraSize: 0x1234_5678)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentRandomAccessOffsetBox)
        #expect(parsed == original)
        #expect(parsed.mfraSize == 0x1234_5678)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = MovieFragmentRandomAccessOffsetBox(mfraSize: 0x100)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 10 6D 66 72 6F
                00 00 00 00
                00 00 01 00
                """)
        #expect(writer.data == expected)
    }
}
