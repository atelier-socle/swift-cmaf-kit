// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for CompactSampleSizeBox (stz2) — ISO/IEC 14496-12 §8.7.3.3.
// Covers all three field sizes (4, 8, 16) including odd-count 4-bit case.

import Foundation
import Testing

@testable import CMAFKit

@Suite("CompactSampleSizeBox")
struct CompactSampleSizeBoxTests {

    @Test
    func roundTripFourBitsEvenCount() async throws {
        let original = CompactSampleSizeBox(
            table: CompactSampleSizeTable(sizes: [1, 5, 10, 15], fieldSize: .fourBits)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompactSampleSizeBox)
        #expect(parsed.table.count == 4)
        #expect(parsed.table[0] == 1)
        #expect(parsed.table[3] == 15)
    }

    @Test
    func roundTripFourBitsOddCount() async throws {
        // Odd count: last low nibble is zero padding.
        let original = CompactSampleSizeBox(
            table: CompactSampleSizeTable(sizes: [3, 7, 12], fieldSize: .fourBits)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompactSampleSizeBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0] == 3)
        #expect(parsed.table[1] == 7)
        #expect(parsed.table[2] == 12)
        // 2 bytes carry 3 entries + 1 padding nibble.
        #expect(parsed.table.rawEntries.count == 2)
    }

    @Test
    func roundTripEightBits() async throws {
        let original = CompactSampleSizeBox(
            table: CompactSampleSizeTable(sizes: [50, 100, 200, 255], fieldSize: .eightBits)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompactSampleSizeBox)
        #expect(parsed.table[0] == 50)
        #expect(parsed.table[3] == 255)
    }

    @Test
    func roundTripSixteenBits() async throws {
        let original = CompactSampleSizeBox(
            table: CompactSampleSizeTable(sizes: [0xAA, 0xBB, 0xFFFF], fieldSize: .sixteenBits)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? CompactSampleSizeBox)
        #expect(parsed.table[0] == 0xAA)
        #expect(parsed.table[2] == 0xFFFF)
    }

    @Test
    func fieldSizeEnumRawValues() {
        #expect(CompactSampleSizeFieldSize.fourBits.rawValue == 4)
        #expect(CompactSampleSizeFieldSize.eightBits.rawValue == 8)
        #expect(CompactSampleSizeFieldSize.sixteenBits.rawValue == 16)
    }

    @Test
    func encodeMatchesKnownBytesEightBits() {
        let box = CompactSampleSizeBox(
            table: CompactSampleSizeTable(sizes: [100, 200], fieldSize: .eightBits)
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4)+type(4)+ver+flags(4)+reserved(3)+fieldSize(1)+count(4)+body(2) = 22
        let expected = Data(
            hex: """
                00 00 00 16 73 74 7A 32
                00 00 00 00
                00 00 00 08
                00 00 00 02
                64 C8
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytesSixteenBits() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 73 74 7A 32
                00 00 00 00
                00 00 00 10
                00 00 00 02
                01 23 04 56
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? CompactSampleSizeBox)
        #expect(parsed.table.fieldSize == .sixteenBits)
        #expect(parsed.table[0] == 0x0123)
        #expect(parsed.table[1] == 0x0456)
    }

    @Test
    func unsupportedFieldSizeThrows() async throws {
        // field_size = 7 (not 4, 8, or 16).
        let bytes = Data(
            hex: """
                00 00 00 16 73 74 7A 32
                00 00 00 00
                00 00 00 07
                00 00 00 02
                64 C8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: ISOBoxError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 16 73 74 7A 32 00 00 00 00")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: (any Error).self) {
            _ = try await reader.readBoxes(from: truncated, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = CompactSampleSizeTable(sizes: [], fieldSize: .eightBits)
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let sizes = Array(repeating: UInt32(7), count: 1_000_000)
        let table = CompactSampleSizeTable(sizes: sizes, fieldSize: .fourBits)
        #expect(table.count == 1_000_000)
        #expect(table.rawEntries.count == 500_000)
        #expect(table[999_999] == 7)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 16 73 74 7A 32
                00 00 00 00
                00 00 00 08
                00 00 00 02
                64 C8
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? CompactSampleSizeBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
