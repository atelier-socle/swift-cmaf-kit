// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ChunkOffsetBox (stco) — ISO/IEC 14496-12 §8.7.5 (32-bit).

import Foundation
import Testing

@testable import CMAFKit

@Suite("ChunkOffsetBox")
struct ChunkOffsetBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = ChunkOffsetBox(table: ChunkOffsetTable(offsets: [0x1000, 0x2000, 0x3000]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ChunkOffsetBox)
        #expect(parsed == original)
    }

    @Test
    func indexedAccess() {
        let table = ChunkOffsetTable(offsets: [100, 200, 300])
        #expect(table[0] == 100)
        #expect(table[2] == 300)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = ChunkOffsetBox(table: ChunkOffsetTable(offsets: [0x1000]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 14 73 74 63 6F
                00 00 00 00
                00 00 00 01
                00 00 10 00
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 14 73 74 63 6F
                00 00 00 00
                00 00 00 01
                12 34 56 78
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? ChunkOffsetBox)
        #expect(parsed.table[0] == 0x1234_5678)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 14 73 74 63 6F 00 00 00 00")
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
                00 00 00 14 73 74 63 6F
                00 00 00 00
                00 0F 42 40
                12 34 56 78
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = ChunkOffsetTable(offsets: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let offsets = (0..<1_000_000).map(UInt32.init)
        let table = ChunkOffsetTable(offsets: offsets)
        #expect(table.count == 1_000_000)
        #expect(table[500_000] == 500_000)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 14 73 74 63 6F
                00 00 00 00
                00 00 00 01
                12 34 56 78
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? ChunkOffsetBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
