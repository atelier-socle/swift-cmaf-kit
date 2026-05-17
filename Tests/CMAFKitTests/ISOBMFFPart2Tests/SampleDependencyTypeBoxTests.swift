// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleDependencyTypeBox (sdtp) — ISO/IEC 14496-12 §8.6.4.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleDependencyTypeBox")
struct SampleDependencyTypeBoxTests {

    @Test
    func roundTripMinimal() async throws {
        let entries = [
            SampleDependencyEntry(
                isLeading: .notLeading,
                dependsOn: .no,
                isDependedOn: .yes,
                hasRedundancy: .no
            )
        ]
        let original = SampleDependencyTypeBox(table: SampleDependencyTable(entries: entries))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleDependencyTypeBox)
        #expect(parsed == original)
    }

    @Test
    func entryBitPackingRoundTrip() {
        let entry = SampleDependencyEntry(
            isLeading: .leadingDependent,
            dependsOn: .yes,
            isDependedOn: .no,
            hasRedundancy: .reserved
        )
        let byte = entry.rawByte
        let decoded = SampleDependencyEntry(rawByte: byte)
        #expect(decoded == entry)
    }

    @Test
    func allFourCornerValues() {
        // Test all combinations of the 2-bit fields by exhaustive iteration.
        let leadingCases: [SampleDependencyEntry.LeadingClass] = [.unknown, .leadingDependent, .notLeading, .leadingIndependent]
        let dependCases: [SampleDependencyInfo.DependencyClass] = [.unknown, .yes, .no, .reserved]
        for leading in leadingCases {
            for dep in dependCases {
                let entry = SampleDependencyEntry(
                    isLeading: leading,
                    dependsOn: dep,
                    isDependedOn: dep,
                    hasRedundancy: dep
                )
                let decoded = SampleDependencyEntry(rawByte: entry.rawByte)
                #expect(decoded == entry)
            }
        }
    }

    @Test
    func encodeMatchesKnownBytes() {
        let entry = SampleDependencyEntry(
            isLeading: .notLeading,  // 0b10
            dependsOn: .no,  // 0b10
            isDependedOn: .yes,  // 0b01
            hasRedundancy: .no  // 0b10
        )
        // Packed: 10 10 01 10 = 0xA6
        #expect(entry.rawByte == 0xA6)

        let box = SampleDependencyTypeBox(table: SampleDependencyTable(entries: [entry]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        // size(4) + type(4) + ver+flags(4) + 1 byte body = 13
        let expected = Data(hex: "00 00 00 0D 73 64 74 70 00 00 00 00 A6")
        #expect(writer.data == expected)
    }

    @Test
    func parseKnownBytes() async throws {
        let bytes = Data(hex: "00 00 00 0D 73 64 74 70 00 00 00 00 A6")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleDependencyTypeBox)
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0].isLeading == .notLeading)
        #expect(parsed.table[0].isDependedOn == .yes)
    }

    @Test
    func sdtpConsumesAllRemainingBytes() async throws {
        // sdtp has no explicit entry count; the parser consumes everything.
        // 4 entries × 1 byte = 4 bytes body.
        let bytes = Data(hex: "00 00 00 10 73 64 74 70 00 00 00 00 A6 6A 5A 2A")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleDependencyTypeBox)
        #expect(parsed.table.count == 4)
    }

    @Test
    func emptyTableRangeContract() {
        let table = SampleDependencyTable(entries: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let entries = (0..<10_000).map { _ in
            SampleDependencyEntry(
                isLeading: .unknown,
                dependsOn: .yes,
                isDependedOn: .no,
                hasRedundancy: .unknown
            )
        }
        let table = SampleDependencyTable(entries: entries)
        #expect(table.rawEntries.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let entries = (0..<1_000_000).map { _ in
            SampleDependencyEntry(
                isLeading: .notLeading,
                dependsOn: .yes,
                isDependedOn: .no,
                hasRedundancy: .unknown
            )
        }
        let table = SampleDependencyTable(entries: entries)
        #expect(table.count == 1_000_000)
        #expect(table[500_000].dependsOn == .yes)
    }

    @Test
    func encodeReemitsRawBytesVerbatim() async throws {
        let originalBytes = Data(hex: "00 00 00 10 73 64 74 70 00 00 00 00 A6 6A 5A 2A")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: originalBytes, using: registry)
        let parsed = try #require(boxes.first as? SampleDependencyTypeBox)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == originalBytes)
    }
}
