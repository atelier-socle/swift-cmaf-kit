// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ChunkLargeOffsetBox (co64) — ISO/IEC 14496-12 §8.7.5 (64-bit).

import Foundation
import Testing

@testable import CMAFKit

@Suite("ChunkLargeOffsetBox")
struct ChunkLargeOffsetBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = ChunkLargeOffsetBox(
            table: ChunkLargeOffsetTable(offsets: [UInt64(UInt32.max) + 100, UInt64(UInt32.max) + 200])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChunkLargeOffsetBox)
        #expect(parsed == original)
    }

    @Test
    func sixtyFourBitOffsetsPreserved() async throws {
        let bigOffset: UInt64 = 0x1234_5678_9ABC_DEF0
        let original = ChunkLargeOffsetBox(table: ChunkLargeOffsetTable(offsets: [bigOffset]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChunkLargeOffsetBox)
        #expect(parsed.table[0] == bigOffset)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = ChunkLargeOffsetBox(table: ChunkLargeOffsetTable(offsets: [0x1234_5678_9ABC_DEF0]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 63 6F 36 34
                00 00 00 00
                00 00 00 01
                12 34 56 78 9A BC DE F0
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 63 6F 36 34
                00 00 00 00
                00 00 00 01
                12 34 56 78 9A BC DE F0
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? ChunkLargeOffsetBox)
        #expect(parsed.table[0] == 0x1234_5678_9ABC_DEF0)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 18 63 6F 36 34 00 00 00 00")
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
                00 00 00 18 63 6F 36 34
                00 00 00 00
                00 0F 42 40
                12 34 56 78 9A BC DE F0
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = ChunkLargeOffsetTable(offsets: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let offsets = (0..<1_000_000).map(UInt64.init)
        let table = ChunkLargeOffsetTable(offsets: offsets)
        #expect(table.count == 1_000_000)
        #expect(table[500_000] == 500_000)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 18 63 6F 36 34
                00 00 00 00
                00 00 00 01
                12 34 56 78 9A BC DE F0
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? ChunkLargeOffsetBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
