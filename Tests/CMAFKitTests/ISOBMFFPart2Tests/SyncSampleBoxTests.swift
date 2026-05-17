// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SyncSampleBox (stss) — ISO/IEC 14496-12 §8.6.2.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SyncSampleBox")
struct SyncSampleBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let original = SyncSampleBox(table: SyncSampleTable(sampleNumbers: [1, 25, 49, 73]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SyncSampleBox)
        #expect(parsed == original)
    }

    @Test
    func indexedAccess() {
        let table = SyncSampleTable(sampleNumbers: [1, 100, 200])
        #expect(table[0] == 1)
        #expect(table[1] == 100)
        #expect(table[2] == 200)
    }

    @Test
    func encodeMatchesKnownBytes() {
        let box = SyncSampleBox(table: SyncSampleTable(sampleNumbers: [1, 25]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 73 74 73 73
                00 00 00 00
                00 00 00 02
                00 00 00 01 00 00 00 19
                """)
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(
            hex: """
                00 00 00 14 73 74 73 73
                00 00 00 00
                00 00 00 01
                00 00 00 64
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SyncSampleBox)
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0] == 100)
    }

    @Test
    func throwsOnTruncation() async throws {
        let truncated = Data(hex: "00 00 00 18 73 74 73 73 00 00 00 00")
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
                00 00 00 14 73 74 73 73
                00 00 00 00
                00 0F 42 40
                00 00 00 64
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        await #expect(throws: BinaryIOError.self) {
            _ = try await reader.readBoxes(from: bytes, using: registry)
        }
    }

    @Test
    func emptyTableRangeContract() {
        let table = SyncSampleTable(sampleNumbers: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let table = SyncSampleTable(sampleNumbers: (1...1_000_000).map(UInt32.init))
        #expect(table.count == 1_000_000)
        #expect(table[500_000] == 500_001)
        #expect(table[999_999] == 1_000_000)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(
            hex: """
                00 00 00 18 73 74 73 73
                00 00 00 00
                00 00 00 02
                00 00 00 01 00 00 00 19
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? SyncSampleBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
