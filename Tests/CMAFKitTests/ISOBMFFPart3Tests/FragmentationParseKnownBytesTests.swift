// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Parse-side known-bytes tests: round-trip parses from hand-written wire
// fixtures to verify the on-wire field order matches ISO/IEC 14496-12.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Fragmentation parse-known-bytes fixtures")
struct FragmentationParseKnownBytesTests {

    @Test
    func mfhdParseAndReencodeMatches() async throws {
        let bytes = Data(
            hex: """
                00 00 00 10 6D 66 68 64
                00 00 00 00
                12 34 56 78
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentHeaderBox)
        #expect(parsed.sequenceNumber == 0x1234_5678)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == bytes)
    }

    @Test
    func tfdtParseAndReencodeMatchesV1() async throws {
        let bytes = Data(
            hex: """
                00 00 00 14 74 66 64 74
                01 00 00 00
                01 02 03 04 05 06 07 08
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentDecodeTimeBox)
        #expect(parsed.baseMediaDecodeTime == 0x0102_0304_0506_0708)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == bytes)
    }

    @Test
    func tfdtParseAndReencodeMatchesV0() async throws {
        let bytes = Data(
            hex: """
                00 00 00 10 74 66 64 74
                00 00 00 00
                12 34 56 78
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentDecodeTimeBox)
        #expect(parsed.version == 0)
        #expect(parsed.baseMediaDecodeTime == 0x1234_5678)
        var writer = BinaryWriter()
        parsed.encode(to: &writer)
        #expect(writer.data == bytes)
    }

    @Test
    func sbgpParseV0() async throws {
        let bytes = Data(
            hex: """
                00 00 00 1C 73 62 67 70
                00 00 00 00
                72 6F 6C 6C
                00 00 00 01
                00 00 00 64 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleToGroupBox)
        #expect(parsed.version == 0)
        #expect(parsed.groupingType == "roll")
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0].sampleCount == 100)
        #expect(parsed.table[0].groupDescriptionIndex == 1)
    }

    @Test
    func sbgpParseV1WithGroupingTypeParameter() async throws {
        let bytes = Data(
            hex: """
                00 00 00 20 73 62 67 70
                01 00 00 00
                73 65 69 67
                CA FE BA BE
                00 00 00 01
                00 00 00 0A 00 00 00 01
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleToGroupBox)
        #expect(parsed.version == 1)
        #expect(parsed.groupingTypeParameter == 0xCAFE_BABE)
    }

    @Test
    func sgpdParseV1RollEntries() async throws {
        let bytes = Data(
            hex: """
                00 00 00 1C 73 67 70 64
                01 00 00 00
                72 6F 6C 6C
                00 00 00 02
                00 00 00 02
                FF C0
                00 10
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        #expect(parsed.version == 1)
        #expect(parsed.defaultLength == 2)
        #expect(parsed.entries.count == 2)
        let first = try #require(parsed.entries[0] as? RollSampleGroupDescription)
        let second = try #require(parsed.entries[1] as? RollSampleGroupDescription)
        #expect(first.rollDistance == -64)
        #expect(second.rollDistance == 16)
    }

    @Test
    func saizParseConstantSize() async throws {
        let bytes = Data(
            hex: """
                00 00 00 11 73 61 69 7A
                00 00 00 00
                10
                00 00 00 64
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationSizesBox)
        #expect(parsed.constantSize == 16)
        #expect(parsed.sampleCount == 100)
        #expect(parsed.perSampleSizes.count == 0)
    }

    @Test
    func saioParseV1() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 73 61 69 6F
                01 00 00 00
                00 00 00 01
                00 00 00 00 00 00 10 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SampleAuxiliaryInformationOffsetsBox)
        #expect(parsed.version == 1)
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0] == 0x1000)
    }

    @Test
    func trunParseSampleSizeOnly() async throws {
        let bytes = Data(
            hex: """
                00 00 00 1C 74 72 75 6E
                01 00 02 00
                00 00 00 03
                00 00 01 00
                00 00 02 00
                00 00 03 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0].sampleSize == 0x100)
        #expect(parsed.table[1].sampleSize == 0x200)
        #expect(parsed.table[2].sampleSize == 0x300)
        #expect(parsed.dataOffset == nil)
    }

    @Test
    func trunParseWithDataOffset() async throws {
        let bytes = Data(
            hex: """
                00 00 00 18 74 72 75 6E
                01 00 02 01
                00 00 00 01
                FF FF FF F8
                00 00 01 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.dataOffset == -8)
        #expect(parsed.table[0].sampleSize == 0x100)
    }

    @Test
    func elstParseV1Multiple() async throws {
        let bytes = Data(
            hex: """
                00 00 00 38 65 6C 73 74
                01 00 00 00
                00 00 00 02
                00 00 00 00 00 00 04 00
                FF FF FF FF FF FF FF FF
                00 01 00 00
                00 00 00 00 00 00 08 00
                00 00 00 00 00 00 00 00
                00 01 00 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed.table.count == 2)
        #expect(parsed.table[0].isEmptyEdit == true)
        #expect(parsed.table[0].segmentDuration == 0x400)
        #expect(parsed.table[1].segmentDuration == 0x800)
        #expect(parsed.table[1].mediaTime == 0)
    }

    @Test
    func mfroParseFixedSize() async throws {
        let bytes = Data(
            hex: """
                00 00 00 10 6D 66 72 6F
                00 00 00 00
                00 00 01 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentRandomAccessOffsetBox)
        #expect(parsed.mfraSize == 0x100)
    }

    @Test
    func mvexEmptyContainerRoundTrips() async throws {
        let bytes = Data(hex: "00 00 00 08 6D 76 65 78")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? MovieExtendsBox)
        #expect(parsed.children.isEmpty)
        #expect(parsed.movieExtendsHeader == nil)
        #expect(parsed.trackExtends.isEmpty)
    }

    @Test
    func moofEmptyContainerRoundTrips() async throws {
        let bytes = Data(hex: "00 00 00 08 6D 6F 6F 66")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentBox)
        #expect(parsed.children.isEmpty)
    }

    @Test
    func trafEmptyContainerRoundTrips() async throws {
        let bytes = Data(hex: "00 00 00 08 74 72 61 66")
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentBox)
        #expect(parsed.children.isEmpty)
        #expect(parsed.trackFragmentHeader == nil)
    }
}
