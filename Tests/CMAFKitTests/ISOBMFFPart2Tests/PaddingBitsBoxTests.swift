// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for PaddingBitsBox (padb) — ISO/IEC 14496-12 §8.7.6.

import Foundation
import Testing

@testable import CMAFKit

@Suite("PaddingBitsBox")
struct PaddingBitsBoxTests {

    @Test
    func roundTripEvenCount() async throws {
        let original = PaddingBitsBox(table: PaddingBitsTable(values: [3, 5, 1, 7]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? PaddingBitsBox)
        #expect(parsed.table.count == 4)
        #expect(parsed.table[0] == 3)
        #expect(parsed.table[1] == 5)
        #expect(parsed.table[2] == 1)
        #expect(parsed.table[3] == 7)
    }

    @Test
    func roundTripOddCount() async throws {
        // Odd count: last low nibble is zero padding.
        let original = PaddingBitsBox(table: PaddingBitsTable(values: [4, 2, 6]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? PaddingBitsBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0] == 4)
        #expect(parsed.table[1] == 2)
        #expect(parsed.table[2] == 6)
        // 2 bytes carry 3 entries + 1 padding nibble.
        #expect(parsed.table.rawEntries.count == 2)
    }

    @Test
    func nibblePackingExact() {
        let table = PaddingBitsTable(values: [7, 3])
        // High nibble = 0b0111, low nibble = 0b0011 → 0x73
        #expect(table.rawEntries == Data([0x73]))
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = PaddingBitsBox(table: PaddingBitsTable(values: [5, 2]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + count(4) + 1 byte body = 17
        let expected = Data(
            hex: """
                00 00 00 11 70 61 64 62
                00 00 00 00
                00 00 00 02
                52
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 11 70 61 64 62
                00 00 00 00
                00 00 00 02
                52
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? PaddingBitsBox)
        #expect(parsed.table.count == 2)
        #expect(parsed.table[0] == 5)
        #expect(parsed.table[1] == 2)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 11 70 61 64 62 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func declaredCountExceedingPayloadThrows() async throws {
        // sampleCount declares 1M but only 1 byte body.
        let bytes = Data(
            hex: """
                00 00 00 11 70 61 64 62
                00 00 00 00
                00 0F 42 40
                52
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = PaddingBitsTable(values: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let values = Array(repeating: UInt8(3), count: 1_000_000)
        let table = PaddingBitsTable(values: values)
        #expect(table.count == 1_000_000)
        // 1M values × 0.5 byte = 500 000 bytes packed.
        #expect(table.rawEntries.count == 500_000)
        #expect(table[500_000] == 3)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 12 70 61 64 62
                00 00 00 00
                00 00 00 03
                42 60
                """)
        // 3 values: 4, 2, 6 — bytes are 0x42 (4|2) and 0x60 (6|0 padding).
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? PaddingBitsBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
