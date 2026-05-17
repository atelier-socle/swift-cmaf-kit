// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Tests for SampleAuxiliaryInformationSizesBox (saiz) and
// SampleAuxiliaryInformationOffsetsBox (saio) — ISO/IEC 14496-12 §8.7.8–§8.7.9.

import Foundation
import Testing

@testable import CMAFKit

@Suite("SampleAuxiliaryInformationSizesBox")
struct SampleAuxiliaryInformationSizesBoxTests {

    @Test
    func roundTripConstantSize() async throws {
        let original = SampleAuxiliaryInformationSizesBox(
            constantSize: 16,
            sampleCount: 100,
            perSampleSizes: SampleInfoSizeTable(sizes: [])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationSizesBox)
        #expect(parsed == original)
        #expect(parsed.constantSize == 16)
        #expect(parsed.sampleCount == 100)
        #expect(parsed.perSampleSizes.count == 0)
    }

    @Test
    func roundTripVariableSizes() async throws {
        let sizes: [UInt8] = [10, 20, 30, 40, 50]
        let original = SampleAuxiliaryInformationSizesBox(
            constantSize: nil,
            sampleCount: 5,
            perSampleSizes: SampleInfoSizeTable(sizes: sizes)
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationSizesBox)
        #expect(parsed.constantSize == nil)
        #expect(parsed.perSampleSizes.count == 5)
        #expect(parsed.perSampleSizes[0] == 10)
        #expect(parsed.perSampleSizes[4] == 50)
    }

    @Test
    func roundTripWithInfoTypeFlag() async throws {
        let original = SampleAuxiliaryInformationSizesBox(
            flags: SampleAuxiliaryInformationSizesBox.flagInfoTypePresent,
            auxInfoType: "cenc",
            auxInfoTypeParameter: 0,
            constantSize: 16,
            sampleCount: 50,
            perSampleSizes: SampleInfoSizeTable(sizes: [])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationSizesBox)
        #expect(parsed.auxInfoType == "cenc")
        #expect(parsed.auxInfoTypeParameter == 0)
    }

    @Test
    func emptyTableRangeContract() {
        let table = SampleInfoSizeTable(sizes: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let sizes = (0..<10_000).map { _ in UInt8(0x10) }
        let table = SampleInfoSizeTable(sizes: sizes)
        // 10_000 × 1 = 10_000.
        #expect(table.rawEntries.count == 10_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let sizes = (0..<1_000_000).map { UInt8($0 & 0xFF) }
        let table = SampleInfoSizeTable(sizes: sizes)
        #expect(table.count == 1_000_000)
        #expect(table[0] == 0)
        #expect(table[500_000] == UInt8(500_000 & 0xFF))
    }
}

@Suite("SampleAuxiliaryInformationOffsetsBox")
struct SampleAuxiliaryInformationOffsetsBoxTests {

    @Test
    func roundTripV1Default() async throws {
        let table = AuxInfoOffsetsTable(offsets: [0x1000, 0x2000, 0x3000])
        let original = SampleAuxiliaryInformationOffsetsBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationOffsetsBox)
        #expect(parsed == original)
        #expect(parsed.table[0] == 0x1000)
        #expect(parsed.table[2] == 0x3000)
    }

    @Test
    func roundTripV0Compact() async throws {
        let table = AuxInfoOffsetsTable(offsets: [0xAB, 0xCD], version: 0)
        let original = SampleAuxiliaryInformationOffsetsBox(version: 0, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationOffsetsBox)
        #expect(parsed.version == 0)
        #expect(parsed.table[0] == 0xAB)
        #expect(parsed.table.stride == 4)
    }

    @Test
    func v1HandlesOffsetsBeyond32Bit() async throws {
        let beyond32: UInt64 = UInt64(UInt32.max) + 100
        let table = AuxInfoOffsetsTable(offsets: [beyond32])
        let original = SampleAuxiliaryInformationOffsetsBox(table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationOffsetsBox)
        #expect(parsed.table[0] == beyond32)
    }

    @Test
    func roundTripWithInfoTypeFlag() async throws {
        let original = SampleAuxiliaryInformationOffsetsBox(
            flags: SampleAuxiliaryInformationOffsetsBox.flagInfoTypePresent,
            auxInfoType: "cbcs",
            auxInfoTypeParameter: 0,
            table: AuxInfoOffsetsTable(offsets: [0x100])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationOffsetsBox)
        #expect(parsed.auxInfoType == "cbcs")
    }

    @Test
    func emptyTableRangeContract() {
        let table = AuxInfoOffsetsTable(offsets: [])
        #expect(table.count == 0)
        #expect(table.startIndex == table.endIndex)
        #expect(table.rawEntries.isEmpty)
    }

    @Test
    func lazyTableMemoryFootprintMatchesRawDataSize() {
        let offsets = (0..<10_000).map { UInt64($0) }
        let table = AuxInfoOffsetsTable(offsets: offsets)
        // 10_000 × 8 = 80_000.
        #expect(table.rawEntries.count == 80_000)
        #expect(table.count == 10_000)
    }

    @Test
    func lazyTableHandlesLargeEntryCount() {
        let offsets = (0..<1_000_000).map { UInt64($0) }
        let table = AuxInfoOffsetsTable(offsets: offsets)
        #expect(table.count == 1_000_000)
        #expect(table[0] == 0)
        #expect(table[999_999] == 999_999)
    }
}
