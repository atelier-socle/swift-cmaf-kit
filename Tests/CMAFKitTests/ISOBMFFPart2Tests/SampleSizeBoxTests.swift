// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleSizeBox (stsz) — ISO/IEC 14496-12 §8.7.3.2.
// Covers per-sample table and constant-size special case.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleSizeBox")
struct SampleSizeBoxTests {

    @Test
    func roundTripPerSample() async throws {
        let original = SampleSizeBox(table: SampleSizeTable(sizes: [100, 200, 300, 400]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleSizeBox)
        #expect(parsed.table.count == 4)
        #expect(parsed.table[0] == 100)
        #expect(parsed.table[3] == 400)
    }

    @Test
    func roundTripConstantSize() async throws {
        let original = SampleSizeBox(
            table: SampleSizeTable(count: 1000, constantSize: 188)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleSizeBox)
        #expect(parsed.table.constantSize == 188)
        #expect(parsed.table.count == 1000)
        #expect(parsed.table[0] == 188)
        #expect(parsed.table[999] == 188)
        // Constant-size table has empty rawEntries.
        #expect(parsed.table.rawEntries.isEmpty)
    }

    @Test
    func constantSizeEncodingIsCompact() {
        let box = SampleSizeBox(table: SampleSizeTable(count: 1000, constantSize: 188))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + sample_size(4) + sample_count(4) = 20
        // No table bytes follow.
        #expect(writer.data.count == 20)
    }

    @Test
    func encodeMatchesKnownBytesPerSample() {
        let box = SampleSizeBox(table: SampleSizeTable(sizes: [0x64]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 73 74 73 7A
                00 00 00 00
                00 00 00 00
                00 00 00 01
                00 00 00 64
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytesConstantSize() async throws {
        let bytes = Data(
            hex: """
                00 00 00 14 73 74 73 7A
                00 00 00 00
                00 00 00 BC
                00 00 03 E8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleSizeBox)
        #expect(parsed.table.constantSize == 0xBC)
        #expect(parsed.table.count == 1000)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 18 73 74 73 7A 00 00 00 00")
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
                00 00 00 20 73 74 73 7A
                00 00 00 00
                00 00 00 00
                00 0F 42 40
                00 00 00 64 00 00 00 C8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = SampleSizeTable(sizes: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
        #expect(table.constantSize == nil)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let sizes = Array(repeating: UInt32(100), count: 10_000)
        let table = SampleSizeTable(sizes: sizes)
        #expect(table.rawEntries.count == 40_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let sizes = (0..<1_000_000).map(UInt32.init)
        let table = SampleSizeTable(sizes: sizes)
        #expect(table.count == 1_000_000)
        #expect(table[500_000] == 500_000)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 18 73 74 73 7A
                00 00 00 00
                00 00 00 00
                00 00 00 01
                00 00 00 64
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? SampleSizeBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
