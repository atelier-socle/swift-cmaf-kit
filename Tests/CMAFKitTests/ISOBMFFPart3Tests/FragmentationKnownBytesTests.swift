// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Known-bytes encode/parse fixtures for the fragmentation, indexing,
// random-access, sample-group, sample-auxiliary, and edit-list boxes —
// guards against wire-format regressions.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Fragmentation known-bytes fixtures")
struct FragmentationKnownBytesTests {

    // MARK: - mehd

    @Test
    func mehdEncodesV1KnownBytes() {
        let box = MovieExtendsHeaderBox(fragmentDuration: 0x0102_0304_0506_0708)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 14 6D 65 68 64
                01 00 00 00
                01 02 03 04 05 06 07 08
                """)
        #expect(writer.data == expected)
    }

    @Test
    func mehdEncodesV0KnownBytes() {
        let box = MovieExtendsHeaderBox(version: 0, fragmentDuration: 0x1234_5678)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 10 6D 65 68 64
                00 00 00 00
                12 34 56 78
                """)
        #expect(writer.data == expected)
    }

    @Test
    func mehdParseKnownBytesV1() async throws {
        let bytes = Data(
            hex: """
                00 00 00 14 6D 65 68 64
                01 00 00 00
                01 02 03 04 05 06 07 08
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? MovieExtendsHeaderBox)
        #expect(parsed.fragmentDuration == 0x0102_0304_0506_0708)
        #expect(parsed.version == 1)
    }

    // MARK: - sidx

    @Test
    func sidxEncodesKnownBytesV1Minimal() {
        let entry = SegmentIndexEntry(
            referenceType: false,
            referencedSize: 0x100,
            subsegmentDuration: 0x400,
            startsWithSAP: true,
            sapType: 1,
            sapDeltaTime: 0
        )
        let box = SegmentIndexBox(
            referenceID: 1,
            timescale: 90_000,
            earliestPresentationTime: 0,
            firstOffset: 0,
            table: SegmentIndexTable(entries: [entry])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 34 73 69 64 78
                01 00 00 00
                00 00 00 01
                00 01 5F 90
                00 00 00 00 00 00 00 00
                00 00 00 00 00 00 00 00
                00 00 00 01
                00 00 01 00
                00 00 04 00
                90 00 00 00
                """)
        #expect(writer.data == expected)
    }

    @Test
    func sidxParseKnownBytesV0() async throws {
        let bytes = Data(
            hex: """
                00 00 00 2C 73 69 64 78
                00 00 00 00
                00 00 00 03
                00 01 5F 90
                00 00 00 00
                00 00 00 10
                00 00 00 01
                80 00 01 00
                00 00 04 00
                10 00 00 00
                """)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: bytes, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed.version == 0)
        #expect(parsed.referenceID == 3)
        #expect(parsed.firstOffset == 0x10)
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0].referenceType == true)
        #expect(parsed.table[0].referencedSize == 0x100)
    }

    // MARK: - sbgp / sgpd

    @Test
    func sbgpEncodesKnownBytesV0() {
        let box = SampleToGroupBox(
            groupingType: "roll",
            table: SampleToGroupTable(entries: [
                SampleToGroupEntry(sampleCount: 100, groupDescriptionIndex: 1)
            ])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 1C 73 62 67 70
                00 00 00 00
                72 6F 6C 6C
                00 00 00 01
                00 00 00 64 00 00 00 01
                """)
        #expect(writer.data == expected)
    }

    @Test
    func sgpdEncodesKnownBytesV2RollEntry() {
        let box = SampleGroupDescriptionBox(
            groupingType: "roll",
            defaultSampleDescriptionIndex: 0,
            entries: [RollSampleGroupDescription(rollDistance: -64)]
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 1A 73 67 70 64
                02 00 00 00
                72 6F 6C 6C
                00 00 00 00
                00 00 00 01
                FF C0
                """)
        #expect(writer.data == expected)
    }

    // MARK: - elst

    @Test
    func elstEncodesKnownBytesV1Default() {
        let box = EditListBox(
            table: EditListTable(entries: [
                EditListEntry(segmentDuration: 1024, mediaTime: 0)
            ]))
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 24 65 6C 73 74
                01 00 00 00
                00 00 00 01
                00 00 00 00 00 00 04 00
                00 00 00 00 00 00 00 00
                00 01 00 00
                """)
        #expect(writer.data == expected)
    }

    @Test
    func elstEncodesKnownBytesV0Empty() {
        let box = EditListBox(
            version: 0,
            table: EditListTable(
                entries: [EditListEntry(segmentDuration: 1024, mediaTime: -1)],
                version: 0
            )
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 1C 65 6C 73 74
                00 00 00 00
                00 00 00 01
                00 00 04 00
                FF FF FF FF
                00 01 00 00
                """)
        #expect(writer.data == expected)
    }

    // MARK: - saiz

    @Test
    func saizEncodesKnownBytesConstantSize() {
        let box = SampleAuxiliaryInformationSizesBox(
            constantSize: 16,
            sampleCount: 100,
            perSampleSizes: SampleInfoSizeTable(sizes: [])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 11 73 61 69 7A
                00 00 00 00
                10
                00 00 00 64
                """)
        #expect(writer.data == expected)
    }

    @Test
    func saizEncodesKnownBytesVariable() {
        let box = SampleAuxiliaryInformationSizesBox(
            constantSize: nil,
            sampleCount: 3,
            perSampleSizes: SampleInfoSizeTable(sizes: [8, 12, 16])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 14 73 61 69 7A
                00 00 00 00
                00
                00 00 00 03
                08 0C 10
                """)
        #expect(writer.data == expected)
    }

    // MARK: - saio

    @Test
    func saioEncodesKnownBytesV1() {
        let box = SampleAuxiliaryInformationOffsetsBox(
            table: AuxInfoOffsetsTable(offsets: [0x1000])
        )
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 73 61 69 6F
                01 00 00 00
                00 00 00 01
                00 00 00 00 00 00 10 00
                """)
        #expect(writer.data == expected)
    }

    // MARK: - trun

    @Test
    func trunEncodesKnownBytesDurationAndSize() {
        let perSampleFlags = TrackRunTable.flagSampleDuration | TrackRunTable.flagSampleSize
        let table = TrackRunTable(
            entries: [TrackRunEntry(sampleDuration: 0x400, sampleSize: 0x100)],
            perSampleFlags: perSampleFlags,
            version: 1
        )
        let box = TrackRunBox(table: table)
        var writer = BinaryWriter()
        box.encode(to: &writer)
        let expected = Data(
            hex: """
                00 00 00 18 74 72 75 6E
                01 00 03 00
                00 00 00 01
                00 00 04 00
                00 00 01 00
                """)
        #expect(writer.data == expected)
    }
}
