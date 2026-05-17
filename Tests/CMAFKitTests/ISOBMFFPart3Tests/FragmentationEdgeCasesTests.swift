// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// Edge-case coverage: empty tables, flag-combination matrices, boundary
// conditions, and behaviour at the limits of each box's wire format.

import Foundation
import Testing

@testable import CMAFKit

@Suite("Fragmentation edge cases")
struct FragmentationEdgeCasesTests {

    // MARK: - tfhd flag matrix

    @Test
    func tfhdWithOnlyDefaultSampleDuration() async throws {
        let original = TrackFragmentHeaderBox(
            trackID: 1,
            defaultSampleDuration: 2048
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        #expect(parsed.defaultSampleDuration == 2048)
        #expect(parsed.defaultSampleSize == nil)
        #expect(parsed.defaultSampleFlags == nil)
        #expect(parsed.baseDataOffset == nil)
    }

    @Test
    func tfhdWithOnlyBaseDataOffset() async throws {
        let original = TrackFragmentHeaderBox(
            trackID: 1,
            baseDataOffset: 0x1234_5678
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        #expect(parsed.baseDataOffset == 0x1234_5678)
        #expect(parsed.defaultSampleDuration == nil)
    }

    @Test
    func tfhdWithDurationIsEmptyFlag() async throws {
        let original = TrackFragmentHeaderBox(
            flags: TrackFragmentHeaderBox.flagDefaultBaseIsMoof
                | TrackFragmentHeaderBox.flagDurationIsEmpty,
            trackID: 1
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentHeaderBox)
        #expect(parsed.durationIsEmpty == true)
        #expect(parsed.defaultBaseIsMoof == true)
    }

    // MARK: - trun flag matrix

    @Test
    func trunWithDataOffsetNoFirstSampleFlags() async throws {
        let table = TrackRunTable(
            entries: [TrackRunEntry(sampleDuration: 100)],
            perSampleFlags: TrackRunTable.flagSampleDuration,
            version: 1
        )
        let original = TrackRunBox(dataOffset: 100, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.dataOffset == 100)
        #expect(parsed.firstSampleFlags == nil)
    }

    @Test
    func trunWithFirstSampleFlagsNoDataOffset() async throws {
        let table = TrackRunTable(
            entries: [TrackRunEntry(sampleDuration: 100)],
            perSampleFlags: TrackRunTable.flagSampleDuration,
            version: 1
        )
        let original = TrackRunBox(firstSampleFlags: 0x0200_0000, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.dataOffset == nil)
        #expect(parsed.firstSampleFlags == 0x0200_0000)
    }

    @Test
    func trunWithBothHeaderOptionalsAndAllPerSampleFlags() async throws {
        let perSampleFlags =
            TrackRunTable.flagSampleDuration
            | TrackRunTable.flagSampleSize
            | TrackRunTable.flagSampleFlags
            | TrackRunTable.flagSampleCompositionTimeOffsets
        let table = TrackRunTable(
            entries: [
                TrackRunEntry(
                    sampleDuration: 1024,
                    sampleSize: 512,
                    sampleFlags: 0x0100_0000,
                    sampleCompositionTimeOffset: 0
                )
            ],
            perSampleFlags: perSampleFlags,
            version: 1
        )
        let original = TrackRunBox(
            dataOffset: -8,
            firstSampleFlags: 0x0200_0000,
            table: table
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackRunBox)
        #expect(parsed.dataOffset == -8)
        #expect(parsed.firstSampleFlags == 0x0200_0000)
        #expect(parsed.table.count == 1)
        #expect(parsed.table[0].sampleSize == 512)
    }

    // MARK: - sidx empty / multi-entry

    @Test
    func sidxEmptyTableRoundTrips() async throws {
        let original = SegmentIndexBox(
            referenceID: 1,
            timescale: 48_000,
            earliestPresentationTime: 0,
            firstOffset: 0,
            table: SegmentIndexTable(entries: [])
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SegmentIndexBox)
        #expect(parsed.table.count == 0)
    }

    // MARK: - mfra wraps empty children

    @Test
    func mfraEmptyContainerRoundTrips() async throws {
        let mfraHeader = ISOBoxHeader(type: "mfra", size: 0, headerSize: 8)
        let mfra = MovieFragmentRandomAccessBox(header: mfraHeader, children: [])
        var writer = BinaryWriter()
        mfra.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? MovieFragmentRandomAccessBox)
        #expect(parsed.trackFragmentRandomAccess.isEmpty)
        #expect(parsed.movieFragmentRandomAccessOffset == nil)
    }

    // MARK: - sgpd version-1 default_length non-zero

    @Test
    func sgpdV1NonZeroDefaultLengthFixedEntrySize() async throws {
        // v1 with default_length=2 (Roll entry is exactly 2 bytes on the wire).
        let original = SampleGroupDescriptionBox(
            version: 1,
            groupingType: "roll",
            defaultLength: 2,
            entries: [
                RollSampleGroupDescription(rollDistance: -32),
                RollSampleGroupDescription(rollDistance: 16)
            ]
        )
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? SampleGroupDescriptionBox)
        #expect(parsed.defaultLength == 2)
        #expect(parsed.entries.count == 2)
        let first = try #require(parsed.entries[0] as? RollSampleGroupDescription)
        #expect(first.rollDistance == -32)
    }

    // MARK: - elst variant

    @Test
    func elstMultipleEntriesV1() async throws {
        let entries = [
            EditListEntry(segmentDuration: 1024, mediaTime: -1),
            EditListEntry(segmentDuration: 2048, mediaTime: 0),
            EditListEntry(segmentDuration: 4096, mediaTime: 512, mediaRateInteger: 1, mediaRateFraction: 0)
        ]
        let original = EditListBox(table: EditListTable(entries: entries))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed.table.count == 3)
        #expect(parsed.table[0].isEmptyEdit == true)
        #expect(parsed.table[1].segmentDuration == 2048)
        #expect(parsed.table[2].mediaTime == 512)
    }

    @Test
    func elstNonDefaultMediaRate() async throws {
        let original = EditListBox(
            table: EditListTable(entries: [
                EditListEntry(
                    segmentDuration: 1024, mediaTime: 0,
                    mediaRateInteger: 2, mediaRateFraction: 0
                )
            ]))
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? EditListBox)
        #expect(parsed.table[0].mediaRateInteger == 2)
    }

    // MARK: - tfra widths boundary

    @Test
    func tfraWidthsAllOnes() async throws {
        // Smallest variable widths: 1 byte each. Largest values fit.
        let table = TrackFragmentRandomAccessTable(
            entries: [
                TrackFragmentRandomAccessEntry(
                    time: 1, moofOffset: 0x100,
                    trafNumber: 0xFF, trunNumber: 0xFF, sampleNumber: 0xFF
                )
            ],
            trafNumberWidth: 1,
            trunNumberWidth: 1,
            sampleNumberWidth: 1
        )
        let original = TrackFragmentRandomAccessBox(trackID: 1, table: table)
        var writer = BinaryWriter()
        original.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentRandomAccessBox)
        #expect(parsed.table.trafNumberWidth == 1)
        #expect(parsed.table[0].sampleNumber == 0xFF)
    }

    // MARK: - saiz info type pair preserved

    @Test
    func saizSaioInfoTypeRoundTrips() async throws {
        let saiz = SampleAuxiliaryInformationSizesBox(
            flags: SampleAuxiliaryInformationSizesBox.flagInfoTypePresent,
            auxInfoType: "cbcs",
            auxInfoTypeParameter: 1,
            constantSize: nil,
            sampleCount: 2,
            perSampleSizes: SampleInfoSizeTable(sizes: [8, 16])
        )
        let saio = SampleAuxiliaryInformationOffsetsBox(
            flags: SampleAuxiliaryInformationOffsetsBox.flagInfoTypePresent,
            auxInfoType: "cbcs",
            auxInfoTypeParameter: 1,
            table: AuxInfoOffsetsTable(offsets: [0x1000])
        )
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(
            header: trafHeader,
            children: [
                TrackFragmentHeaderBox(trackID: 1), saiz, saio
            ])
        var writer = BinaryWriter()
        traf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentBox)
        #expect(parsed.sampleAuxiliaryInformationSizes.count == 1)
        #expect(parsed.sampleAuxiliaryInformationSizes[0].auxInfoType == "cbcs")
        #expect(parsed.sampleAuxiliaryInformationOffsets[0].auxInfoTypeParameter == 1)
    }

    // MARK: - multiple sbgp/sgpd of different grouping types in one traf

    @Test
    func mixedGroupingTypesInOneTraf() async throws {
        let rollSbgp = SampleToGroupBox(
            groupingType: "roll",
            table: SampleToGroupTable(entries: [SampleToGroupEntry(sampleCount: 100, groupDescriptionIndex: 1)])
        )
        let rollSgpd = SampleGroupDescriptionBox(
            groupingType: "roll",
            defaultSampleDescriptionIndex: 0,
            entries: [RollSampleGroupDescription(rollDistance: -10)]
        )
        let rapSbgp = SampleToGroupBox(
            groupingType: "rap ",
            table: SampleToGroupTable(entries: [SampleToGroupEntry(sampleCount: 50, groupDescriptionIndex: 1)])
        )
        let rapSgpd = SampleGroupDescriptionBox(
            groupingType: "rap ",
            defaultSampleDescriptionIndex: 0,
            entries: [RandomAccessPointSampleGroupDescription(numLeadingSamplesKnown: true, numLeadingSamples: 2)]
        )
        let tfhd = TrackFragmentHeaderBox(trackID: 1)
        let trafHeader = ISOBoxHeader(type: "traf", size: 0, headerSize: 8)
        let traf = TrackFragmentBox(
            header: trafHeader,
            children: [
                tfhd, rollSbgp, rapSbgp, rollSgpd, rapSgpd
            ])

        var writer = BinaryWriter()
        traf.encode(to: &writer)
        let registry = await BoxRegistry.defaultRegistry()
        let reader = ISOBoxReader()
        let boxes = try await reader.readBoxes(from: writer.data, using: registry)
        let parsed = try #require(boxes.first as? TrackFragmentBox)
        #expect(parsed.sampleToGroups.count == 2)
        #expect(parsed.sampleGroupDescriptions.count == 2)
        let groupingTypes = parsed.sampleToGroups.map { $0.groupingType }
        #expect(groupingTypes.contains("roll"))
        #expect(groupingTypes.contains("rap "))
    }
}
