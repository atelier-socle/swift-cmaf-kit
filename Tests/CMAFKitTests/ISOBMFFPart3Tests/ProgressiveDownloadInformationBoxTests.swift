// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for ProgressiveDownloadInformationBox (pdin) — ISO/IEC 14496-12 §8.1.3.

import Foundation
import Testing

@testable import CMAFKit

@Suite("ProgressiveDownloadInformationBox")
struct ProgressiveDownloadInformationBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let table = ProgressiveDownloadTable(entries: [
            ProgressiveDownloadEntry(rate: 1_000_000, initialDelay: 1000)
        ])
        let original = ProgressiveDownloadInformationBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProgressiveDownloadInformationBox)
        #expect(parsed == original)
    }

    @Test
    func multipleRateDelayPairs() async throws {
        let entries = [
            ProgressiveDownloadEntry(rate: 500_000, initialDelay: 2000),
            ProgressiveDownloadEntry(rate: 1_000_000, initialDelay: 1000),
            ProgressiveDownloadEntry(rate: 2_000_000, initialDelay: 500)
        ]
        let original = ProgressiveDownloadInformationBox(
            table: ProgressiveDownloadTable(entries: entries)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProgressiveDownloadInformationBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0].rate == 500_000)
        #expect(parsed.table[2].initialDelay == 500)
    }

    @Test
    func entryCountInferredFromBodyLength() async throws {
        // pdin has no entry_count; the parser divides remaining bytes by 8.
        let entries = (0..<5).map { ProgressiveDownloadEntry(rate: UInt32($0), initialDelay: 0) }
        let original = ProgressiveDownloadInformationBox(
            table: ProgressiveDownloadTable(entries: entries)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? ProgressiveDownloadInformationBox)
        #expect(parsed.table.count == 5)
    }

    @Test
    func emptyTableRangeContract() {
        let table = ProgressiveDownloadTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { _ in
            ProgressiveDownloadEntry(rate: 1, initialDelay: 1)
        }
        let table = ProgressiveDownloadTable(entries: entries)
        #expect(table.rawEntries.count == 80_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map { i in
            ProgressiveDownloadEntry(rate: UInt32(i), initialDelay: UInt32(i * 2))
        }
        let table = ProgressiveDownloadTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[0].rate == 0)
        #expect(table[999_999].initialDelay == UInt32(999_999 * 2))
    }
}
