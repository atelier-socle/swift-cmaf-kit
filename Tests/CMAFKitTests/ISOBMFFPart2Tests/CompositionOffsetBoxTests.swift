// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for CompositionOffsetBox (ctts) — ISO/IEC 14496-12 §8.6.1.3.
// Covers v0 unsigned and v1 signed (with negative MV-HEVC scenario).

import Foundation
import Testing

@testable import CMAFKit

@Suite("CompositionOffsetBox")
struct CompositionOffsetBoxTests {

    @Test
    func roundTripV0Unsigned() async throws {
        let table = CompositionOffsetTable(
            entries: [
                CompositionOffsetEntry(sampleCount: 5, sampleOffset: 1024),
                CompositionOffsetEntry(sampleCount: 10, sampleOffset: 2048)
            ],
            version: 0
        )
        let original = CompositionOffsetBox(version: 0, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompositionOffsetBox)
        #expect(parsed.version == 0)
        #expect(parsed.table[0].sampleOffset == 1024)
        #expect(parsed.table[1].sampleOffset == 2048)
    }

    @Test
    func roundTripV1Signed() async throws {
        let table = CompositionOffsetTable(
            entries: [
                CompositionOffsetEntry(sampleCount: 5, sampleOffset: 512),
                CompositionOffsetEntry(sampleCount: 3, sampleOffset: -256)
            ],
            version: 1
        )
        let original = CompositionOffsetBox(version: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompositionOffsetBox)
        #expect(parsed.version == 1)
        #expect(parsed.table[0].sampleOffset == 512)
        #expect(parsed.table[1].sampleOffset == -256)
    }

    @Test
    func mvhevcNegativeOffsetSurvivesRoundTrip() async throws {
        // MV-HEVC stereoscopic case: secondary layer may decode ahead of
        // presentation, producing negative composition offsets.
        let table = CompositionOffsetTable(
            entries: [CompositionOffsetEntry(sampleCount: 1, sampleOffset: -512)],
            version: 1
        )
        let original = CompositionOffsetBox(version: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompositionOffsetBox)
        #expect(parsed.table[0].sampleOffset == -512)
    }

    @Test
    func v1ExtremeSignedValues() async throws {
        let table = CompositionOffsetTable(
            entries: [
                CompositionOffsetEntry(sampleCount: 1, sampleOffset: Int64(Int32.min)),
                CompositionOffsetEntry(sampleCount: 1, sampleOffset: Int64(Int32.max)),
                CompositionOffsetEntry(sampleCount: 1, sampleOffset: -1)
            ],
            version: 1
        )
        let original = CompositionOffsetBox(version: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompositionOffsetBox)
        #expect(parsed.table[0].sampleOffset == Int64(Int32.min))
        #expect(parsed.table[1].sampleOffset == Int64(Int32.max))
        #expect(parsed.table[2].sampleOffset == -1)
    }

    @Test
    func parseKnownBytesV0() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 63 74 74 73
                00 00 00 00
                00 00 00 01
                00 00 00 05 00 00 04 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? CompositionOffsetBox)
        #expect(parsed.version == 0)
        #expect(parsed.table[0].sampleCount == 5)
        #expect(parsed.table[0].sampleOffset == 1024)
    }

    @Test
    func unsupportedVersionThrows() async throws {
        var writer = BinaryWriter()
        writer.writeFullBox(type: "ctts", version: 2, flags: 0) { body in
            body.writeUInt32(0)
        }
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: writer.data, using: registry)
        }
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 18 63 74 74 73 00 00 00 00")
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
                00 00 00 18 63 74 74 73
                01 00 00 00
                00 0F 42 40
                00 00 00 05 FF FF FE 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = CompositionOffsetTable(entries: [], version: 1)
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map {
            CompositionOffsetEntry(sampleCount: 1, sampleOffset: Int64($0))
        }
        let table = CompositionOffsetTable(entries: entries, version: 1)
        #expect(table.count == 1_000_000)
        #expect(table[500_000].sampleOffset == 500_000)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 18 63 74 74 73
                01 00 00 00
                00 00 00 01
                00 00 00 01 FF FF FE 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? CompositionOffsetBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }

    @Test
    func boxVersionMustMatchTableVersion() {
        // Constructing with mismatched versions traps via precondition.
        // The trap path is intentionally not directly tested; we assert
        // that matched versions construct cleanly.
        let tableV0 = CompositionOffsetTable(entries: [], version: 0)
        let tableV1 = CompositionOffsetTable(entries: [], version: 1)
        let boxV0 = CompositionOffsetBox(version: 0, table: tableV0)
        let boxV1 = CompositionOffsetBox(version: 1, table: tableV1)
        #expect(boxV0.version == 0)
        #expect(boxV1.version == 1)
    }
}
